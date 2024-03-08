---
title: "Joey Innes - Resume"
description: "Highly-motivated, curious & honest senior software engineer."
date: 2024-03-08
img: "/img/art/crypto-swamp/"
---
## From writing my first C programs at age 12. Building military avionics for GE Aviation Systems at age 19. Off-grid shack living in Chamonix. Now senior software engineer in Switzerland at 31.

![image](/img/self/madeira/nuns/2400.avif)

My career in computing has been inconsistent and far from conventional.

## I'm now late. I must grow. Fast.
I focus on maximising my rate of learning, and I'm beyond happy with this strategy.

# Recent Projects
## logd
Real-time logging (tail & query) for virtually unlimited logs. A map of in-memory ring buffers. Built on UDP & homegrown (simple) stateless & ephemeral HMAC. Go std lib + Protobuf. Image is built from scratch (Linux kernel + app executable).

## Sshworm
I have been playing with distributing program execution across a large and changing trusted network using `/etc/hosts` traversal over SSH.

![image](/img/cs/sshworm/2400.avif)

I can run commands on an unlimited number of machines with rapid propagation. Commands propagate according to the relationships between machines. The POC was written in a morning, although this is still an unfinished but promising project.

## Toolbox
Swissinfo needed a web-qpp for a bunch of new APIs. Some of them more featured than others, such as a multi-lingual video hosting service.

![image](/img/cs/toolbox/status/2400.avif)

I built the front-end using **only** Google's Lit library (abstraction around native Web Components). I managed to avoid even a build process, thanks to importmap. The app only loads the necessary modules. The app is only 175KB, no minification. It includes a self-made router written for this app.

Both devs & users are very happy with it so far.

## Automated Secret Rotation
I was recently tasked with writing a Lambda function for staged secret rotation of any app.

The core interface I ended up with:
```go
// V represents a Secret Version
type V interface {
	GenerateNext(ctx context.Context) (V, error)
	UpdateApp(ctx context.Context, pending V) error
	Test(ctx context.Context) error
}
```

Types that implement this interface can be rotated automatically by the application. The staged rotation including rollback is abstracted into a separate package.

Developers are happy because they can easily rotate their app's secrets, whether DB password, elliptic curve key or shared secret.

## arpload
**Unfinished** safe large file uploader for Arweave network. Written in Go using `everFinance/goar`.