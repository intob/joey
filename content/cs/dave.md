---
title: dave
status: IN_DEVELOPMENT
date: 2024-05-01
description: "An anonymised distributed hash table, for use as a cache or KV store for dApps."
img: /img/art/rain/
---

My focus is shifting away from flying down mountains, although I will always spend much of my time outdoors, when possible.

In the last 6 months, I've become drawn to pursue another childhood dream of mine... writing software that helps us to ensure an open, self-sovereign, and free society. I want to live in a world where everyone has the ability to read and write information to our internet freely.

So... what are we doing? When I started this project (first commit 2024-04-05), I really had no idea, beyond designing a peer-to-peer network application. Now my vision is finally becoming clear, and I am able to describe it.

I want to build a peer-to-peer cache. A decentralised key-value store that any device may write and read to and from. Simplicity, provable security, anonymity, resistance to censorship, efficiency, performance, and high availability are key aspects that I am aiming for.

Simplicity will come at the cost of pushing much application-specific complexity up the stack. We must be free to re-imagine a broken game, if it turns out to be broken...

At this time, I feel that this approach ensures a modular and upgradeable stack of protocols, while maximising probability of success of the dave protocol.

How can we scope an unfinished idea? I don't a have good answer at time of writing.

# dave - a peer-to-peer anonymised distributed hash table.

I'm designing a protocol for efficiently distributing information in a decentralised, anonymous, and censorship-resistant way, without the need of a native token or value transaction.

I am aware that such projects have been attempted, and failed. I am also aware that such a challenging project may not be an ideal start for a budding p2p network researcher. With that in mind, I do need a worthy challenge and vision to hold my interest.

Why build this? Currently, we have multiple strong contenders for long-term decentralised storage. Projects such as IPFS, Sia, Arweave, Filecoin, Storj. To my knowledge, we do not yet have a single solution for a decentralised database, cache or KV store.

Use-cases? Decentralised social media applications, serverless forms, quickly-consistent communication layer for dApps.

## Design
The protocol is designed around a single message format with an enumerated operation code. There are 4 operation codes, as follows; GETPEER, PEER, DAT, GET.

Execution is of a cyclic mode, with the mininum period defined by constant EPOCH. With each cycle, a count is incremented. There are several constants defined for various sub-cycles. These values are tuned but must be prime numbers, such that no sub-cycle will coincide with an other.

This design allows the protocol to be adjusted safely, and in a way that could preseve interoperability with a network of nodes running variations for different bandwidth ideals & constraints.

### GETPEER & PEER Messages
These are the first two op-codes that I defined, and initially the only operations that the network performed. These two messages allow nodes on the network to discover peers, and to verify their availability.

For every OPEN EPOCH, iterate over the peer table. If a peer is found that has not been seen in the last OPEN EPOCH, and has not been pinged within the last PING EPOCH, send to the peer a message with op-code GETPEER.

A protocol-following peer will reply with op-code PEER, a message containting NPEER addresses for other peers.

I often refer to these addresses as peer descriptors, as in future, they may not necessarily be IP addresses. I would like the possibility to cleanly implement interoperable transports. Know that in my current implementation, I have not yet cleaned up the protobuf specification to support this.

If a peer does not respond with any valid message, after DROP * EPOCH has elapsed, the peer is deleted from the peer table.

Unresponsive peers are no-longer advertised after OPEN * EPOCH has elapsed without message, so as to ensure that unresponsive peers are not re-added from latent gossip.

### DAT Message
A DAT message is a packet of data containing a Value, Time, Salt, and Work. Salt and Work are outputs of the cost function, into which Value and Time are passed.

Every SEED EPOCH, each node sends one randomly selected dat to one randomly selected peer.

This ensures that information propagates and re-propagates through the network reliably, until it is eventually no-longer stored by any node. I describe the selection algorithm later.

This provides a good level of anonymity for original senders, because it is virtually impossible to discern the origin of a dat, even with a broad view of network traffic.

Anonymity is achieved by ensuring no correlation between the timing of a dat being recieved for the first time, and it's eventual propagation to other nodes. This happens at random, but at a constant interval.

### GET Message
A GET message is a packet with op-code GET, containing a Work hash. If the remote has the dat, the remote should reply with a DAT message containing it. A node may request the same DAT from many peers simultaneously. This is up to the application to optimise.

Each PULL EPOCH, a node sends a random GET message to a random peer. This ensures that all DATs are requested with GET messages, further improving anonymity.

### DAT Selection by Mass

#### Proof-of-work
A Salt is found, that when combined with the Value & Time fields using a hash function, the output begins with some desired number of leading zero bytes. The number of leading zeros (or some other constraint) probablisticly accurately reflects the energetic cost equivalent of computing the proof. This is commonly known as proof-of-work, and is well known for it's use in Bitcoin mining. The number of leading zero bytes is referred to as the "difficulty" throughout the remainder of this document. I actually compute a salty hash from an initial hash of value and time, because this performs better than a single hash for large values. This incentivises efficient use of dats. 

#### Mass Calculation
As each machine has limited resources, we need a mechanism by which the software can select which dats should be stored, at the expense of others being dropped. In a peer-to-peer application without any central coordination or authority, each node must be able to decide which dats to keep on it's own.

So how can we give priority to some dats over others?

As the cryptographic proof contains the value, and time, neither may be modified without invalidating the proof. As such, we can use the time, and the difficulty in the calculaton of a score, referred to here as mass.

##### mass = difficulty * (1 / millisecondsSinceAdded)

The mass tends to zero over time. Dats with a harder proof of work persist longer in the network. In addition, difficulty scales exponentially (each added zero byte increases the difficulty by 256 times.

### Peer Trust Mechanism
A decentralised network depends on a trust system that incentivises fair play. It's much more challenging than operating in a private network, as most web applications do today. So why do it? It allows us to build more powerful software that cannot be controlled by any single entity.

The goal of the trust mechanism is to ensure that energy is not lost to malicious or protocol-deviating peers.

#### Earning Trust
Each time a packet is received containing a DAT **not already stored**, the remote peer's trust value is incremented by the mass of the DAT.

If a peer is dropped, and then re-joins the network, they will begin with a trust score of zero.

Trust scores are not gossiped, as this implies additional attack surface and complexity.

#### Use of Trust
The trust score is weighed in to the random peer selection. A random threshold between the maximum trust score and zero is chosen. A peer with a trust score greater than the random threshold is selected at random.

Therefore, peers with a higher trust score are more likely to be selected for gossip messages. This in turn increases the chance for the peer to learn of new DATs earlier, reinforcing the pattern.

In essence, the longer a peer (ip-port) remains in an other's peer table, the higher the trust score will likely be, and therefore the more bandwidth allocated to that peer.

### Packet Filter
Protocol-deviating packets may be sent from malicious or misconfigurred nodes. A packet filter is cruicial for efficiently dropping garbage packets.

#### How do we efficiently assert whether or not we have seen a packet before?
Asserting with 100% certainty is very computationally expensive, but asserting with a very high degree of probability is significatly cheaper, and advances in this field have led to efficient filters.

I use a cuckoo filter. The cuckoo filter is ideal for this use-case, as it provides fast constant-time lookups with low false-positive rate for the memory required. The size of the filter is configurable, with a capacity of 1M requiring around 1MB of memory.

What do we insert into the filter? We take the remote IP, port, and message op-code. If this combination has been inserted into the filter before, we drop the packet.

The filter is reset every EPOCH.

## 🌱
Thank you for reading. I value advice and ideas, if you have any please reach me.

## Try Garry
A web-browser unfortunately cannot yet communicate with the dave network directly, so we need HTTP gateways. There is one running at https://garry.inneslabs.uk/. You can also run your own gateway locally, which is more secure. To do that, just clone https://github.com/intob/garry/ and run with `go run . -b $BOOTSTRAP_IP`.

## Repositories
The project is split up into modules, each with their own repository. First, godave is the protocol implementation in library form, written in Go. Second, daved is a program that executes the protocol, as any other application that may join the network. Third, garry is a HTTP gateway. Finally, dapi is a library with helper functions used in daved and garry, but also useful for other applications.

Protocol implementation in Go: https://github.com/intob/godave

Basic CLI: https://github.com/intob/daved

HTTP gateway: https://github.com/intob/garry

Helper functions: https://github.com/intob/dapi


Currently, my implementation overall is intentionally brief. It may panic rather than handle an error, as this would allow me to detect and analyse a crash, and keep the line-count minimal (currently around 460 incl. license), allowing me to iterate faster.

I'm running 3 seed nodes on tiny arm64 VMs, running Debain 12, thanks systemd. I use scripts to control groups of machines as I need. This simple setup gives me full control, and visibility of logs by grepping dave's logs using the linux journal. I use a simple path prefix /fn/procedure/action that allows me to efficiently grep logs without need for typing quotes around the query (I like to feel good).

## Get daved
As this project is still in pre-alpha (5 weeks), I am not yet distributing binaries. You need to build from source.
1. Install Git https://git-scm.com/
2. Install Go https://go.dev/dl/

### Run go install
3. `go install github.com/intob/daved@latest`
4. `daved`
5. `daved -v | grep /d/pr`

### Clone Repository
Alternatively, you can clone the repository.
3. `git clone https://github.com/intob/daved && cd daved`
4. `go run .`
5. `go run . -v | grep /d/pr`

### Run as a Node
Executing the program without set, setfile or get commands puts the program in it's default mode of operation, participating in the network.

Running without arguments automatically bootstraps to the embedded seed nodes.
By default, the program listens on all network interfaces, and a random available listening port is allocated by the operating system.
```bash
daved
```

Verbose logging. Use grep to filter logs.
```bash
daved -v
```

Run with log output. Each PRUNE epochs (few seconds), with peer & dat count, and memory usage is logged.
```bash
daved -v | grep /d/pr
```

Listen on port 1618 across all network interfaces.
```bash
daved -l :1618
daved -l [::]:1618
```

Start as a seed, without any bootstrap node (ignore embedded seed addresses).
```bash
daved -s
```

Bootstrap only to port on local machine.
```bash
daved -b :1969
daved -b 127.0.0.1:1969
```

Bootstrap only to given IP address and port.
```bash
daved -b 12.34.56.78:1234
```

### Run with Commands
Write hello_world to davenet with default difficulty of 3. Will probably take around 10 seconds on an 8 core low-power consumer laptop.
```bash
daved set hello_world
```
Write hello_world to davenet with minimum difficulty of 2.
```bash
daved -d 2 set hello_world
```
Get a dat from the network, output as text, and exit immediately.
```bash
daved get 0000006f68ae2000290a1ba5cc4\
689b8bd48e6ac7d566c35954f82c235fb43bd
```
Set by reading a file.
```bash
daved setfile myfile.txt
```

## References
I suppose I ought to thank Adam Back for compiling this list of papers, some of which I read: http://www.hashcash.org/papers/, and of course for his hashcash cost-function, on which this protocol is built.

Thank you also to https://github.com/seiflotfy/cuckoofilter/ for the excellent cuckoo filter implementation, also used in godave.

Sources:
[/doc/cs/BoundedGossip.pdf](/doc/cs/BoundedGossip.pdf)
[/doc/cs/FNV_Perf.pdf](/doc/cs/FNV_Perf.pdf)
[/doc/cs/Gossip_Design.pdf](/doc/cs/Gossip_Design.pdf)
[/doc/cs/Hoare78.pdf](/doc/cs/Hoare78.pdf)
[/doc/cs/PromiseAndLimitationsOfGossip_2007.pdf](/doc/cs/PromiseAndLimitationsOfGossip_2007.pdf)

