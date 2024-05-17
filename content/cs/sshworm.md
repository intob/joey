---
title: Distributed program execution via /etc/hosts traversal over SSH
date: 2024-03-15
---
I have been playing with distributing program execution across a large and changing trusted network using `/etc/hosts` traversal over SSH.

Commands propagate according to the relationships between machines, defined by /etc/hosts entries. The POC was written in a morning, although SSH is not ideal for this because it's so slow, silly TCP... I've since found much more efficient and performant means of distributing commands and binaries.