---
title: dave
status: IN_PROGRESS
date: 2024-05-01
description: "Building my first peer-to-peer network application. An anonymized distributed hash table for use as a cache or KV store for dApps."
imgsz: /img/cs/dave/3840.avif
---

My focus is shifting away from flying down mountains, although I will always spend much of my time outdoors, when possible.

In the last 6 months, I've become drawn to pursue another childhood dream of mine... writing software that helps us to ensure an open, self-sovereign, and free society. I want to live in a world where everyone has the ability to read and write information to our internet freely.

So... what are we doing? When I started this project around 5 weeks ago, I really had no idea, beyond designing a peer-to-peer network application. Now my vision is finally becoming clear, and I am able to write about it.

I want to build a peer-to-peer cache. A decentralised key-value store that any device may write and read to and from. Simplicity, provable security, anonymity, resistance to censorship, efficiency, performance, and high availability are key aspects that I am aiming for.

Simplicity will come at the cost of pushing much application-specific complexity up the stack. We must be free to re-imagine a broken game, if it turns out to be broken...

At this time, I feel that this approach ensures a modular and upgradeable stack of protocols, while maximising probability of success of the dave protocol.

How can we scope an unfinished idea? I don't a have good answer at time of writing.

# dave - a peer-to-peer anonymised distributed hash table.

I'm designing a protocol for efficiently distributing information in a decentralised and censorship-resistant way, without the need of a native token or value transaction.

I am aware that such projects have been attempted, and failed. I am also aware that such a challenging project may not be an ideal start for a budding p2p network researcher. With that in mind, I do need a worthy challenge and vision to hold my interest.

Why build this? Currently, we have multiple strong contenders for long-term decentralised storage. Projects such as IPFS, Sia, Arweave, Filecoin, Storj. To my knowledge, we do not yet have a single solution for a decentralised database, cache or KV store.

Use-cases? Decentralised social media applications, serverless forms, quickly-consistent storage and communication layer for dApps.

## Design
The protocol is designed around a single message format, with an enumerated operation code that defines the desired action. There are 3 operation codes, as follows; GETPEER, PEER, DAT.

Each node operates in a cyclic mode, with the mininum period defined by constant EPOCH. Each other constant is a multiplier of the EPOCH constant. This design allows the protocol to be adjusted safely, and in a way that should preseve compatibility with a network running many different versions and variations.

### GETPEER & PEER Messages
These are the first two op-codes that I defined, and initially the only operations that the network performed. These two messages allow nodes on network to discover peers, and to verify their availability.

Each epoch, a node iterates over it's peer table. If it finds a peer which it has not heard from in the last SHARE epochs, and the peer has not been pinged within the last PING epochs, the node sends the peer a message with the GETPEER op-code. A protocol-following peer will reply with the PEER op-code, a message containting NPEER addresses for other peers. I often refer to these addresses as peer descriptors, as in future they may not necessarily be IP addresses. I would like the possibility to cleanly implement interoperable transports. Know that in my current implementation, I have not yet cleaned up the protobuf specification to support this.

If a peer never responds with a PEER message, and the peer is not heard from in a protocol-following manner, the peer is dropped from the peer table. Peers are no-longer advertised much sooner than they are dropped from the peer table. This ensures that unresponsive peers are not re-added from latent gossip.

### DAT Message
A DAT message is a randomized "push" of data, including it's proof-of-work, the output of the cost function.

Every EPOCH, each node sends one randomly selected dat to FANOUT randomly selected peers.

This ensures that information propagates and re-propagates through the network reliably, until it is eventually no-longer stored by any node. I will describe the selection algorithm later.

Originally a self-healing mechanism for the network, this is now the only way to add data to the network. This provides a good level of anonymity for original senders, because it is virtually impossible to discern the origin of a dat, even with a broad view of the network traffic.

Anonymity is achieved by ensuring no correlation between the timing of a dat being recieved for the first time, and it's eventual propagation to other nodes. This happens at random, but at a constant interval, referred to as EPOCH.

### DAT Selection by Weight
Each dat contains 4 fields; Value, Time, Nonce, Work. The value and time are chosen.

#### Proof-of-work
A nonce is found, that when combined with the Value & Time fields using a hash function, the output begins with some desired number of leading zeros. The number of leading zeros (or some other constraint) probablisticly accurately reflects the energetic cost equivalent of computing the proof. This is commonly known as proof-of-work, and is well known for it's use in Bitcoin mining. The number of leading zeros is referred to as the "difficulty" throughout the remainder of this document.

#### Weight Calculation
As each machine has limited resources, we need a mechanism by which the software can select which dats should be stored, at the expense of some being dropped. In a peer-to-peer application without any central coordination or authority, each node must be able to decide which dats to keep on it's own.

So how can we give priority to some dats over others?

As the cryptographic proof contains the value, and time, neither may be modified without invalidating the proof. As such, we can use the time, and the difficulty in the calculaton of a score, referred to here as weight.

##### weight = difficulty * (1 / millisecondsSinceAdded)

The weight tends to zero over time. Dats with a harder proof of work persist longer in the network.

## Roadmap
In keeping with this document being written in retrospect of research conducted, I prefer not to speculate too much on the future of this project. I will continue.

I will reveal one insight had this morning.

Last night, I removed the SET op-code, which originally behaved similarly to the GET op-code, fanning out by propagation from one peer to two other peers until the DISTANCE limit is reached for each branch. My reasoning is based on my wish to ensure anonymity for users writing to the network. This small change (taking just a few minutes), both simplified the protocol and also solves anonymity for writing, without onion routing or mixnets. The GET message still reveals a node's interest in a certain dat. In privacy-focussed applications, this is already solved by waiting for the dat by random propagation. We can do better...

Thank you for reading about my research project. I value advice and ideas, if you have any please reach me.

## Repositories
Protocol implementation in Go   https://github.com/intob/godave
Basic CLI                       https://github.com/intob/daved
HTTP Gateway                    https://github.com/intob/garry

## Usage
The repo is split up into modules. First, godave is the protocol implementation in library form, written in Go. Second, daved is a program that executes the protocol, just like any other application that may execute the protocol, such as a HTTP gateway. Finally, dapi is a library with helper functions used in daved, but also useful for other applications.

Currently, my implementation overall is intentionally brief. It may panic rather than handle an error, as this allows me to detect and analyse any crashes, and keep the line-count minimal (currently around 480), allowing me to iterate faster.

As this project is still in pre-alpha (5 weeks), I am not yet distributing binaries. You need to build from source. Currently I'm running 3 bootstrap nodes on tiny arm64 VMs, running Debain 12, thanks systemd. I use scripts to control groups of machines as I need. This simple setup gives me full control, and visibility of logs by grepping dave's logs using the linux journal. I use a simple path prefix /fn/procedure/action that allows me to efficiently grep logs without need for typing quotes around the query (I like to feel good).

### Build from Source
1. Install Git https://git-scm.com/
2. Install Go https://go.dev/dl/
3. `go install github.com/intob/daved@latest`
4. `daved`
5. `daved -v | grep /d/pr`

Read the readme for full documentation.

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
daved -v | grep /d/ph/prune
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

