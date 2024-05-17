---
title: Dave
description: "Anonymised continually-distributed hash table."
date: 2024-05-01
---

My focus is shifting away from flying, to computer science. I've not yet dedicated all of my energy to computer science for a sustained period, and I'm exceedingly curious to see where it leads me.

So... what are we doing? When I started this project (first commit 2024-04-05), I didn't know exactly, beyond designing a peer-to-peer network application that disseminates information. Now my vision is finally becoming clear, and I'm able to describe it.

I'm writing a peer-to-peer application that allows anyone, or any device, to read and write information without a key or value transaction of any kind. The writer pays in CPU cycles and electricity, while the reader pays in network participation.

Simplicity, anonymity, efficiency, performance, and high availability are key aspects that I'm aiming for.

Simplicity will come at the cost of pushing much application-specific complexity up the stack. We must be free to re-imagine a broken game, if it turns out to be broken... At this time, I feel that this approach ensures a modular and upgradeable stack of protocols, while maximising probability of success of the dave protocol.

I'm aware that such projects have been attempted, and failed. I'm also aware that such a challenging project may not be an ideal start for a budding p2p network researcher. With that in mind, I do need a worthy challenge and vision to hold my interest.

# Dave - anonymised continuously distributed hash table.

Dave is a protocol for continuously disseminating information in a decentralised, anonymous, and censorship-resistant way, without the need of a native token or value transaction.

New values are available instantly, with sub-second lookup time, with current parameters. Old values have a significantly faster lookup time, because more nodes will likely have the data. Most likely, the response time is equal to or even much better than average network ping.

Use-cases: Decentralised near-real-time social media applications, serverless forms, communication layer for any decentralised application.

## Design
The protocol is designed around a single message format with an enumerated operation code. There are 4 operation codes, as follows; GETPEER, PEER, DAT, GET.

Execution is of a cyclic mode, with the mininum period defined by constant EPOCH. There are several period multipliers, defined as constants. These values are tuned, but should be prime numbers such that no sub-cycle will coincide with another.

This allows the program to send a uniform stream of packets, reducing packet loss and maximising efficiency. This allows the protocol to be adjusted safely, and in a way that could preserve interoperability with a network running variations for different bandwidth ideals & constraints.

### GETPEER & PEER Messages
These are the first two op-codes that I defined, and initially the only operations that the network performed. These two messages allow nodes on the network to discover peers, and to verify their availability.

For every PING EPOCH, iterate over the peer table. If a peer is found that has not been seen in the last PING EPOCH, and has not been pinged within the last PING EPOCH, send to the peer a message with op-code GETPEER.

A protocol-following peer will reply with op-code PEER, a message containting NPEER addresses for other peers.

I often refer to these addresses as peer descriptors, as in future, they may not necessarily be IP addresses. I would like the possibility to cleanly implement interoperable transports.

Know that I have not yet cleaned up the protobuf specification to support this, I prefer to focus on other aspects for now.

If a peer does not respond with any valid message, after DROP * EPOCH has elapsed, the peer is deleted from the peer table. Unresponsive peers are no-longer advertised after OPEN * EPOCH has elapsed without message, so as to ensure that unresponsive peers are not re-added from latent gossip.

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
A Salt is found, that when combined with the Value & Time fields using a hash function, the output begins with some desired number of leading zero bytes. The number of leading zeros (or some other constraint) probablisticly accurately reflects the energetic cost equivalent of computing the proof. This is commonly known as proof-of-work, and is well known for it's use in Bitcoin mining.

The number of leading zero bytes is referred to as the "difficulty" throughout the remainder of this document.

We compute a salty hash from an initial hash of value and time, because this performs better than a single hash for large values, incentivising efficient use of dats.

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

We use a cuckoo filter. The cuckoo filter is ideal for this use-case, as it provides fast constant-time lookups with low false-positive rate for the memory footprint.

##### fnv64a(op, hash4(remote_port), remote_ip)

What do we insert into the filter? We take the remote IP, 4-bit hash of port, and message op-code. If this combination has been inserted into the filter before, we drop the packet. The filter is reset every EPOCH.

Internally, IP addresses are always mapped to IPv6 to avoid confusion.

## Some Repositories 
Oh boy, is there a lot for us to build... I could never do even a small fraction of it alone. I would love for you to be part of this idea.

### godave is the protocol implementation in library form, written in Go.
Protocol https://github.com/intob/godave/

### daved is a program that executes the protocol, as any other application that may join the network.
A tiny cli https://github.com/intob/daved/

### garry is a HTTP gateway.
Anything can work with dave. https://github.com/intob/garry/

## State of Operations
I'm no-longer running public edge (bootstrap) nodes myself. I was using AWS, with a bunch of t4g.nano arm64 VMs running Debain 12. Thanks systemd. I used scripts & programs to control groups of additional machines as we needed. I view logs by grepping the linux system journal. Logs begin with a short path prefix /fn/proc/action, allowing us to efficiently grep logs without need for typing quotes around the query.

Thank you for reading. I value advice and ideas, if you have any, please do reach me. 🌱


### Run as Node
Executing with no command (just flags) puts the program in it's default mode of operation, participating in the network.

#### daved
By default, the program listens on all network interfaces, port 1618.

#### daved -v
Verbose logging. Use grep to filter logs.

#### daved -l :2024
Listen to all network interfaces, on port 2024. Same as daved -l [::]:2024

#### daved -e :1969
Bootstrap to peer at port on local machine.

#### daved -e 12.34.56.78:1234
Bootstrap to peer at given address and port.

### Commands
#### daved set hello_dave
Write "hello_dave" to the network with default difficulty of 2. This will probably take just a few seconds on a low-power consumer laptop or phone.

#### daved -d 3 set hello_world
Write hello_world to the network with difficulty of 3. This is 256 times harder than difficulty 2.

#### daved get <HASH>
Get a dat from the network, output as text, and exit immediately.

#### daved setf myfile.txt
Write a very small file (<= ~1400B) to the network. Abstractions that allow efficient large file storage will come. I guess someome much smarter than I will figure it out with Merkle trees and stuff. Come on you great minds!

## References
Thank you to Jean-Philippe Aumasson, for the Blake2 hash function. Thanks also to the other researchers who helped him, namely Samuel Neves, Zooko Wilcox-O'Hearn, and Christian Winnerlein.

Thank you to Adam Back for compiling this list of papers, some of which I read: http://www.hashcash.org/papers/, and of course for his hashcash cost-function, on which this protocol is designed.

Thank you also to https://github.com/panmari/cuckoofilter/ for the 16-bit variation of excellent cuckoo filter implementation from https://github.com/seiflotfy/cuckoofilter/.
