---
title: dave
status: IN_PROGRESS
date: 2024-05-01
description: "Building my first peer-to-peer network application. An anonymized distributed hash table for use as a cache or KV store for dApps."
img: /img/cs/dave/
---

My focus is shifting away from flying down mountains, although I will always spend much of my time outdoors, when possible.

In the last 6 months, I've become drawn to pursue another childhood dream of mine... writing software that helps us to ensure an open, self-sovereign, and free society. Anonymity, censorship resistance, performance, and high availability are key qualities that I am striving for.I will maintain my focus on simplicity, at the cost of pushing some complexity up through the application layers. At this time, I feel that this approach ensures a modular and upgradeable network stack. 

So... what are we doing? When I started this project around 5 weeks ago, I really had no idea, beyond designing a peer-to-peer network. Now my vision is finally becoming clear, and I am able to write about it.

# dave - A peer-to-peer anonymised distributed hash table.
I'm designing a protocol for efficiently distributing information in a decentralised and censorship-resistant way, without the need of a native token or value transaction.

I am aware that such projects have been attempted, and failed. I am also aware that such a challenging project may not be an ideal start for a budding p2p network researcher. With that in mind, I do need a worthy challenge and vision to hold my interest.

Why build this? Currently, we have multiple strong contenders for long-term decentralised storage. Projects such as IPFS, Sia, Arweave, Filecoin, Storj. To my knowledge, we do not yet have a single solution for a decentralised database, cache or KV store.

Use-cases? Decentralised social media applications, serverless forms, quickly-consistent storage and communication layer for dApps.

## Design
The protocol is designed around a single message format, with an enumerated operation code that defines the desired action. There are 4 operation codes, as follows; GETPEER, PEER, DAT, GET.

### GETPEER & PEER Messages
These are the first two op-codes that I defined, and initially the only operations that the network performed. These two messages allow nodes on network to discover peers, and to verify their availability.

Each epoch, a node iterates over it's peer table. If it finds a peer which it has not heard from in the last SHARE epochs, and the peer has not been pinged within the last PING epochs, the node sends the peer a message with the GETPEER op-code. A protocol-following peer will reply with the PEER op-code, a message containting NPEER addresses for other peers. I often refer to these addresses as peer descriptors, as in future they may not necessarily be IP addresses. I would like the possibility to cleanly implement ultiple transports. Know that in my current implementation, I have not yet cleaned up the protobuf specification to support this.

If a peer never responds with a PEER message, and the peer is not heard from in a protocol-following manner, the peer is dropped from node's the peer table. Peers are no-longer advertised much sooner than they are dropped from the peer table. This ensures that unresponsive peers are not added from latent gossip.

### DAT Message
A DAT message is a randomized "push" of data, including it's proof-of-work, the output of the cost function.

Every EPOCH, each node sends one randomly selected DAT to FANOUT randomly selected peers.

This ensures that information propagates and re-propagates through the network reliably, until it is eventually no-longer stored by any node. I will describe the selection algorithm later.

Originally a self-healing mechanism for the network, this is now the only way to add data to the network. This provides a good level of anonymity for original senders, because it is virtually impossible to discern the origin of a DAT, even with a broad view of the network traffic.

Anonymity is achieved by ensuring no correlation between the timing of a DAT being recieved for the first time, and it's eventual propagation to other nodes. This happens at random, but at a constant interval, referred to as EPOCH.

### GET Message
A node participating in the network probably receives all DATs relatively quickly, depending on chosen EPOCH and current network load. However, what if a user simply wants to retreive a specific DAT that they have not yet seen? Use-case; a peer wishes to read from the network, and then leave without participating further. In BitTorrent, this type of node was affectionately known as a leech, because they draw bandwidth from the network, and do not contribute bandwidth back by re-seeding chunks.

In the context of dave protocol, I see this slightly differently, as the goal of dave ultimately includes serving "leeches" efficiently, with each node incurring negligible cost over time. How can we manage this? Cryptographic proofs, and packet filtering efficient enough to make large-scale attacks infeasable.

### DAT Selection by Weight
Each dat contains 4 fields; Value, Time, Nonce, Work. The value and time are chosen.

#### Proof-of-work
A nonce is found, that when combined with the Value & Time fields using a hash function, the output begins with some desired number of leading zeros. The number of leading zeros (or some other constraint) probablisticly accurately reflects the energetic cost equivalent of computing the proof. This is commonly known as proof-of-work, and is well known for it's use in Bitcoin mining. The number of leading zeros is referred to as the "difficulty" throughout the remainder of this document.

#### Weight Calculation
As each machine has limited resources, we need a mechanism by which the software can select which dats should be stored, at the expense of some being dropped. In a peer-to-peer application without any central coordination or authority, each node must be able to decide which DATs to keep on it's own.

So how can we give priority to some DATs over others?

As the cryptographic proof contains the value, and time, neither may be modified without invalidating the proof. As such, we can use the time, and the difficulty in the calculaton of a score, referred to here as weight.

The weight of a DAT is calculated as:
```
    weight = difficulty * (1 / millisecondsSinceAdded)
```

DATs with a stronger proof of work persist longer in the network, and on more nodes, than DATs with less work. Also, all DATs become lighter over time, and as such all DATs will eventually be dropped as heavier DATs are received.

## Roadmap
In keeping with this document being written in retrospect of research conducted, I prefer not to speculate too much on the future of this project. I will continue.

I will reveal one insight had this morning.

Last night, I removed the SET op-code, which originally behaved similarly to the GET op-code, fanning out by propagation from one peer to two other peers until the DISTANCE limit is reached for each branch. My reasoning is based on my wish to ensure anonymity for users writing to the network. This small change (taking just a few minutes), both simplified the protocol and also solves anonymity for writing, without onion routing or mixnets. The GET message still reveals a node's interest in a certain DAT. In privacy-focussed applications, this is already solved by waiting for the DAT by random propagation. We can do better...

Thank you for reading about my research project. I value advice and ideas, if you have any please reach me.

## Repo
https://github.com/intob/dave

## Run a Node
The repo is split up into modules. First, godave is the protocol implementation in library form, written in Go. Second, daved is a program that executes the protocol, just like any other application that may execute the protocol, such as a HTTP gateway. Finally, dapi is a library with helper functions used in daved, but also useful for other applications.

Currently, my implementation overall is intentionally brief. It may panic rather than handle an error, as this allows me to detect and analyse any crashes, and keep the line-count minimal (currently around 480), allowing me to iterate faster.

```bash
daved # No arguments automatically bootstraps to the embedded seed nodes.
daved -v # Verbose logging, you should use grep to filter logs:
daved -v | grep /d/ph/prune # Will output a log each PRUNE epochs
# (few seconds), with peer & dat count, and memory usage.
daved -b :1969 # Bootstraps to only 127.0.0.1:1969 (local)
daved -b 12.34.56.78:1234 # Bootstraps only to given IP address
# (avoid davenet).

```

As this project is still in pre-alpha (5 weeks), I am not yet distributing binaries. Currently I'm running 3 bootstrap nodes on tiny arm64 VMs, running Debain 12, thanks systemd. I use scripts to control groups of machines as I need. This simple setup gives me full control, and visibility of logs by grepping dave's logs using the linux journal. I use a simple path prefix /fn/procedure/action that allows me to efficiently grep logs without need for typing quotes around the query (I like to feel good).

## References
Thank you to those whose papers I've read, and those not yet.

I suppose I ought to thank Adam Back for compiling this list of papers, some of which I read: http://www.hashcash.org/papers/, and of course for his hashcash cost-function, on which this protocol is built.

Thank you also to https://github.com/seiflotfy/cuckoofilter/ for the excellent cuckoo filter implementation, also used in the reference implementation of dave.

In addition this protocol is built on Protocol Buffers, cheers G.

Sources:
[/doc/cs/BoundedGossip.pdf](/doc/cs/BoundedGossip.pdf)
[/doc/cs/FNV_Perf.pdf](/doc/cs/FNV_Perf.pdf)
[/doc/cs/Gossip_Design.pdf](/doc/cs/Gossip_Design.pdf)
[/doc/cs/Hoare78.pdf](/doc/cs/Hoare78.pdf)
[/doc/cs/PromiseAndLimitationsOfGossip_2007.pdf](/doc/cs/PromiseAndLimitationsOfGossip_2007.pdf)

