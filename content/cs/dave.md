---
title: Dave
description: Anonymised distributed hash table.
date: 2024-05-01
---
My focus is shifting away from flying, to computer science. I've not yet dedicated all of my energy to computer science for a sustained period, and I'm exceedingly curious to see where it leads me.

So... what are we doing? When I started this project (first commit 2024-04-05), I didn't know exactly, beyond designing a peer-to-peer network application that disseminates information. Now my vision is finally becoming clear, and I'm able to describe it.

I'm writing a peer-to-peer application that allows anyone, or any device, to read and write information without a key, token, or value transaction of any kind. A writer pays in CPU cycles and electricity, while a reader pays in network participation.

Simplicity, anonymity, efficiency, performance, and high availability are key aspects that I'm aiming for.

Simplicity will come at the cost of pushing much application-specific complexity up the stack. We must be free to re-imagine a broken game, if it turns out to be broken... At this time, I feel that this approach ensures a modular and upgradeable stack of protocols, while maximising the probability of success of the dave protocol.

I'm aware that such projects have been attempted and failed. I'm also aware that such a challenging project may not be an ideal start for a budding p2p network researcher. With that in mind, I do need a worthy challenge and vision to hold my interest.

# Dave - anonymised distributed hash table

Dave is a protocol for continuously disseminating information in a decentralised, anonymous, and censorship-resistant manner, without the need of a native token or value transaction.

New values are available instantly with sub-second lookup time. Old values have a significantly faster lookup time, because more nodes will likely have the data. Real-world speed depends on the bandwidth provisioned by the nodes. Most likely, the response time is better than average network ping, even with a naive implementation.

Use-cases: Decentralised near-real-time social media applications, serverless forms, communication layer for any decentralised application.

## Design
The protocol is designed around a single message format with an enumerated operation code. There are 4 operation codes, as follows; GETPEER, PEER, DAT, GET.

Execution is of a cyclic mode, with the mininum period defined by constant EPOCH. There are several period multipliers, defined as constants. These values are tuned, but should be prime numbers such that no sub-cycle will coincide with another.

This allows the program to send a uniform stream of packets, reducing packet loss and maximising efficiency. This allows the protocol to be adjusted safely, and in a way that could preserve interoperability with a network running variations for different bandwidth ideals & constraints.

### GETPEER & PEER Messages
These are the first two op-codes that I defined, and initially the only operations that the network performed. These two messages allow nodes on the network to discover peers, and to verify their availability.

For every PING EPOCH, iterate over the peer table. If a peer is found that has not been seen in the last PING EPOCH, and has not been pinged within the last PING EPOCH, send to the peer a message with op-code GETPEER.

A protocol-following peer will reply with op-code PEER, a message containing NPEER addresses for other peers.

I often refer to these addresses as peer descriptors, as in future, they may not necessarily be IP addresses. I would like the possibility to cleanly implement interoperable transports. This would allow nodes to serve as bridges. As software-defined radio is a field of interest to me, I imagine that the dave protocol could used to create alternative low-energy networks that could bridge our existing infrastructure built on IP. Imagine a free and open internet that does not require an internet service provider, or any knowledge of it's users. Know that I have not yet adjusted the protobuf specification to support this, as I prefer to focus on a building working proof over UDP for now.

If a peer does not respond with any valid message, after DROP * EPOCH has elapsed, the peer is deleted from the peer table. Unresponsive peers are no-longer advertised after OPEN * EPOCH has elapsed without message, so as to ensure that unresponsive peers are not re-added from latent gossip.

### DAT Message
A message with op-code DAT is a packet of data containing a Value, Time, Salt, and Work. Salt and Work are outputs of the cost function, into which Value and Time are passed.

Every SEED EPOCH, each node sends one randomly selected dat to one randomly selected peer.

This ensures that information propagates and re-propagates through the network reliably, until it is eventually no-longer stored by any node. I describe the selection algorithm later.

This provides a good level of anonymity for original senders, because it is virtually impossible to discern the origin of a dat, even with a broad view of network traffic.

Anonymity is achieved by ensuring no correlation between the timing of a dat being recieved for the first time, and it's eventual propagation to other nodes. This happens at random, but at a constant interval.

### GET Message
A GET message is a packet with op-code GET, containing a Work hash. If the remote has the dat, the remote should reply with a message with op-code DAT, containing the data. A node may request the same dat from many peers simultaneously. This is up to the application to optimise, although the reference implementation should be pretty good.

Each PULL EPOCH, a node sends a random GET message to a random peer. This ensures that all dats are requested with GET messages, further improving anonymity.

### DAT Selection by Mass

#### Proof-of-work
A Salt is found, that when combined with the Value & Time fields using a hash function, the output begins with some desired number of leading zero bits. The number of leading zeros (or some other constraint) probablisticly accurately reflects the energetic cost equivalent of computing the proof. This is commonly known as proof-of-work, and is well known for it's use in Bitcoin mining.

The number of leading zero bits is referred to as the "difficulty" throughout the remainder of this document.

We compute a salty hash from an initial hash of value and time because this performs better than a single hash for large values, incentivising efficient use of dats.

##### work = blake2b(salt, blake2b(value, time))

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
Each time a packet is received containing a dat **not already stored**, the remote peer's trust value is incremented by the mass of the dat.

If a peer is dropped, and then re-joins the network, they will begin with a trust score of zero.

Trust scores are not gossiped, as this implies additional attack surface and complexity.

#### Use of Trust
The trust score is weighed in to the random peer selection. A random threshold between the maximum trust score and zero is chosen. A peer with a trust score greater than the random threshold is selected at random.

Therefore, peers with a higher trust score are more likely to be selected for gossip messages. This in turn increases the chance for the peer to learn of new dats earlier, reinforcing the pattern.

In essence, the longer a peer (ip-port) remains in an other's peer table, the higher the trust score will likely be, and therefore the more bandwidth allocated to that peer.

### Packet Filter
Protocol-deviating packets may be sent from malicious or misconfigured nodes. A packet filter is cruicial for efficiently dropping garbage packets.

#### How do we efficiently assert whether or not we have seen a packet before?
Asserting with 100% certainty is very computationally expensive, but asserting with a very high degree of probability is significatly cheaper, and advances in this field have led to efficient filters.

We use a cuckoo filter. The cuckoo filter is ideal for this use-case, as it provides fast constant-time lookups with low false-positive rate for the memory footprint.

##### fnv64a(op, hash4(remote_port), remote_ip)

What do we insert into the filter? We take the remote IP, 4-bit hash of port, and message op-code. If this combination has been inserted into the filter before, we drop the packet. The filter is reset every EPOCH.

Internally, IP addresses are always mapped to IPv6 to avoid confusion.

Note: I'm going to switch to Murmur3, following a some benchmarks that I did: /cs/fasthashperf/.

## Scaling
Aside from EPOCH being used to control the frequency of operations and also bandwidth consumed, the number of known peers is also used to modify the intervals where appropriate. For example, the following snippet sends the newest dat to a random peer (excluding bootstrap nodes), but as more peers become known, the more often this is done. I suppose we need to consider bounds for this behaviour to prevent packet loss.
```go
if newest != nil && npeer > 0 && nepoch%(max(PUSH, PUSH/npeer)) == 0 {
    for _, rp := range rndpeers(prs, nil, 1, func(p *peer, l *peer) bool { return !p.edge && available(p, epoch) && dotrust(p, l)}) {
        pktout <- &pkt{&dave.M{Op: dave.Op_DAT, V: newest.V, T: Ttb(newest.Ti), S: newest.S, W: newest.W}, addrfrom(rp.pd)}
    }
}
```
Excuse my dense code. This is how I crammed the protocol into around 640 lines. After some time, you get used to it. I've found that keeping line count low helped my productivity, and ensured that the protocol remained a minimum viable representation of the idea. There is something satisfying about knowing that you could only remove a line by one-lining the error checks, which I tend not to do because I find that that really does hurt readability.

## Resilience to Attack

### Sybil Attack
A Sybil attack is one where an attacker creates many peers that join the network. Failing to consider this would result in the network losing energy to these numerous byzantine nodes that are inexpensive to spawn.

The protocol defends against Sybil attack in various simple ways.

#### 16 Port Limit Per IP Using 4-bit Hash
The first measure is in the packet filter; each IP address is limited to 16 ports because the port number is passed into a 4-bit multiply-then-shift hash function. In future, we could improve this by limiting each IP address to 1 port by omitting the port from the filter key. I would then add a flag for local testing, which would simply include the port number in the fitler key. This would also be more efficient because we don't need to do any computation on the remote port number. I suppose this needs additional consideration, because there are circumstances where running multiple daves on one IP could be nice, although simplicity and security clearly trump that.

#### Dat Delay 
A node must wait some time before receiving dats. They must participate in the gossip of peers without receiving any dats, until the defined period has elapsed. They will then start to receive dats very slowly, based on the PROBE constant.

#### Trust
A node normally selects only trusted peers to receive dats, but occasionally an untrusted peer is probed. Over time, a node is able to build trust with peers, therefore receiving dats more frequently. As a peer earns trust, they are more likely to be selected, thereby having more bandwidth allocated to them.

### Eclipse Attack
An Eclipse attack is one where an attacker attempts to poison the peer tables of peers that it discovers on the network. This poisoning may be either byzantine nodes controlled by the attacker, or simply bogus peer descriptors.

### NPEER Limit
We only accept PEER messages containing up to NPEER peer descriptors. I recommend that this value is either 2 or 3. I err on the side of caution with 2, because there is little benefit to speeding up the peer discovery in this way. It would be more secure to ask for peers more often.

Funny! While writing this (2024-05-29), I just discovered a vulnerability to eclipse attack. A byzantine peer may send many PEER messages, limited only by the packet filter. This makes address poisoning trivial. I will resolve this using a boolean flag on the peer. The flag will be set when sending a GETPEER message, and unset when receiving a PEER message. This way, we only add peers when we are expecting them.


### Denial of Service
This attack is the simplest to orchestrate, and yet one of the hardest to deal with. A denial of service attack is one where an attacker sends packets that induce the maximum amount of computation on the remote. HTTP servers are commonly the recipients of such attacks, which is why we use CDNs where possible to shield our origin servers. This is obviously not possible for stateful APIs and databases. That's why we put databases in private networks, and employ efficient filtering of API requests, often using an IP-based rate limiter. Obviously we can't run our peer-to-peer application in a private network unless we only want to use it in a datacenter.

Unfortunately, if an attacker has more bandwidth than any given node, the node can simply be denied service by exhausting their bandwidth. If the attacker has more bandwidth than the entire network combined, the whole network is denied service. So if you advocate for a given peer-to-peer network, the best way that you can support the network is by giving your bandwidth. Run a node.

#### Cuckoo Filter
The best we can do is deal with garbage packets as efficiently as possible. This ensures that the bottleneck is a node's bandwidth, and not our crappy code. This also means that if any authentic packets are received during the attack, we're more likely to process them. As described earlier, a Cuckoo filter provides constant-time lookups with a small memory footprint for the given probability of false-positives. The filter allows us to assert with high probability if we have seen a packet before. The filter is reset at a constant interval. Any packet seen twice since the filter reset is dropped. This is the first line of defence, ensuring mimimum possible computation of garbage packets.

I chose a 16-bit fingerprint as opposed to an 8-bit fingerprint to reduce the rate of false-positives from ~3% to ~0.01%. As each dat is very valuable, we don't want to drop packets in error. Dropping packets in error would have knock-on effects, such as reducing our efficiency of earning trust with other peers.

## Storing Large Files
As mentioned earlier, all application-specific complexity is pushed up the stack. Dave is purely a packet-sharing protocol, with no built-in features for storing large files. That said, I have considered the need for storing large files in the network.

### Linked List
The simplest approach to storing large files, and the earliest proof that I implemented, is a linked-list. Simply prepend or append the hash of the previous dat in next dat. This simple approach has the disadvantage that reading is slow because GETs cannot be made in parallel.

### Merkle Tree
An optimised approach is to write the large file as a sequence of dats, and concurrently build a merkle tree, where additional pointer dats are used to reference dats containing the file's content. The hash of the root of the tree may then be used as the reference to the file. A reader may then traverse the tree, collecting all of the dats in parallel, and re-assemble the file. Reads of this nature are significantly faster than the linked-list approach.

## Some Repositories 
Oh boy, is there a lot for us to build... I could never do even a small fraction of it alone. I would love for you to be a part of this idea.

### godave is the protocol implementation in library form, written in Go.
Protocol https://github.com/intob/godave/

### daved is a program that executes the protocol, as any other application that may join the network.
A tiny cli https://github.com/intob/daved/

### garry is a HTTP gateway.
Anything can work with dave. https://github.com/intob/garry/

## State of Operations
I'm no-longer running public edge (bootstrap) nodes myself. I was using AWS, with a bunch of t4g.nano arm64 VMs running Debain 12. Thanks systemd. I used scripts & programs to control groups of additional machines as we needed. I view logs by grepping the linux system journal. Logs begin with a short path prefix /fn/proc/action, allowing us to efficiently grep logs without need for typing quotes around the query.

Thank you for reading. I value advice and ideas, if you have any, please do reach me.

### Run as Node
Executing with no command (just flags) puts the program in it's default mode of operation, participating in the network.
```bash
daved # listen on all network interfaces, port 1618
daved -v # verbose logging, use grep to filter logs
daved -v | grep /d/pr # verbose logging, with only the daemon's prune procedure logs output
daved -l :2024 # listen on all network interfaces, port 2024. Same as -l [::]:2024
daved -e :1969 # bootstrap to peer on local machine, port 1969
daved -e 12.34.56.78:1234 # bootstrap to peer at address
```

### Commands
```bash
daved set hello_dave # write hello_dave to the network with default difficulty of 16 bits
daved -d 32 set hello_world # write hello_world to the network with difficulty of 32 bits
daved get $HASH # get the dat with the given work hash from the network
daved setf myfile.txt # write a very small file to the network
```

## References
Thank you to Jean-Philippe Aumasson, for the Blake2 hash function. Thanks also to the other researchers who helped him, namely Samuel Neves, Zooko Wilcox-O'Hearn, and Christian Winnerlein.

Thank you to Adam Back for compiling this list of papers, some of which I read: http://www.hashcash.org/papers/, and of course for his hashcash cost-function, on which this protocol is designed.

Thank you also to https://github.com/panmari/cuckoofilter/ for the 16-bit variation of excellent cuckoo filter implementation from https://github.com/seiflotfy/cuckoofilter/.
