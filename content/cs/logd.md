---
title: logd
description: "Real-time logging (tail & query) over UDP, with ring buffers."
date: 2024-03-15
---
Started ~2023-12
Real-time logging (tail & query) for virtually unlimited logs. A map of in-memory ring buffers. Built on UDP & homegrown ephemeral HMAC. Go std lib + Protobuf. Image is built from scratch (Linux kernel + app executable).

2024-05:
Looking back, this was an enjoyable project to rediscover writing software. It's amazing to return to something after a change of mind. A new mind has more fun, and is more productive. The same thing happened when I re-imagined speedflying after my spinal-cord injury. Some years after my recovery, I rediscovered a lost joy with a new mind.
RE quality of this program: Looking back on past work is always funny, I leave this here as it still serves as a journal. Now, I would just run a process that reads the linux journal. Useless abstractions such as loggers pollute the code. This project is a useless abstraction, like most other software.

## Repo
https://github.com/intob/logd
