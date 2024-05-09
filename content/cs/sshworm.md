---
title: sshworm
description: "Distributed program execution by /etc/hosts traversal over SSH."
date: 2024-03-15
img: /img/cs/sshworm/
---
I have been playing with distributing program execution across a large and changing trusted network using `/etc/hosts` traversal over SSH.

It's easy to run commands on an unlimited number of machines with rapid propagation. Commands propagate according to the relationships between machines. The POC was written in a morning, although this is still an unfinished but promising idea. SSH is actually pretty crap for this, though, haha! Stupid TCP.