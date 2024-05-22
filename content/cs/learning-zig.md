---
title: It's time for me to learn a modern systems language
description: Go is a fantastic language, but every tool has it's limitations and ideal use-cases.
date: 2024-05-21
---
Below is an excerpt from godave. The function `lstn` starts a goroutine that reads from UDP socket `c`. It returns a channel, on which filtered and unmarshalled packets are sent, along with the remote address.
```go
type pkt struct {
	msg *dave.M
	ip  netip.AddrPort
}

func lstn(c *net.UDPConn, epoch time.Duration, fcap uint, log chan<- []byte) <-chan *pkt {
	pkts := make(chan *pkt, 100)
	go func() {
		bpool := sync.Pool{New: func() any { return make([]byte, MTU) }}
		mpool := sync.Pool{New: func() any { return &dave.M{} }}
		h := fnv.New64a()
		f := ckoo.NewFilter(fcap)
		rtick := time.NewTicker(epoch)
		defer c.Close()
		for {
			select {
			case <-rtick.C:
				f.Reset()
				lg(log, "/lstn/filter_reset\n")
			default:
				p := rdpkt(c, h, f, &bpool, &mpool, log)
				if p != nil {
					pkts <- p
				}
			}
		}
	}()
	return pkts
}

func rdpkt(c *net.UDPConn, h hash.Hash, f *ckoo.Filter, bpool, mpool *sync.Pool, log chan<- []byte) *pkt {
	buf := bpool.Get().([]byte)
	defer bpool.Put(buf) //lint:ignore SA6002 slice is already a reference
	n, raddr, err := c.ReadFromUDPAddrPort(buf)
	if err != nil {
		panic(err)
	}
	m := mpool.Get().(*dave.M)
	defer mpool.Put(m)
	err = proto.Unmarshal(buf[:n], m)
	if err != nil {
		lg(log, "/lstn/rdpkt/drop unmarshal err\n")
		return nil
	}
	h.Reset()
	op := make([]byte, 4)
	binary.LittleEndian.PutUint32(op, uint32(m.Op.Number()))
	h.Write(op)
	h.Write([]byte{hash4(raddr.Port())})
	addr := raddr.Addr().As16()
	h.Write(addr[:])
	sum := h.Sum(nil)
	if f.Lookup(sum) {
		lg(log, "/lstn/rdpkt/drop/filter %s %x\n", m.Op, sum)
		return nil
	}
	f.Insert(sum)
	if m.Op == dave.Op_PEER && len(m.Pds) > GETNPEER {
		lg(log, "/lstn/rdpkt/drop/npeer too many peers\n")
		return nil
	} else if m.Op == dave.Op_DAT && Check(m.V, m.T, m.S, m.W) < 1 {
		lg(log, "/lstn/rdpkt/drop/workcheck failed\n")
		return nil
	}
	cpy := &dave.M{Op: m.Op, Pds: make([]*dave.Pd, len(m.Pds)), V: m.V, T: m.T, S: m.S, W: m.W}
	for i, pd := range m.Pds {
		cpy.Pds[i] = &dave.Pd{Ip: pd.Ip, Port: pd.Port}
	}
	return &pkt{cpy, raddr}
}
```

I have only one issue with this code, but this is where cracks start to form when trying to write performant Go. The issue is that without the comment `//lint:ignore SA6002 some comment`, we get the following warning from go-staticcheck:
```
defer bpool.Put(buf)
                ^^^
argument should be pointer-like to avoid allocations (SA6002)go-staticcheck
```
The linter thinks that buf is a value because it's not explicitly given as a pointer, when in fact a slice is just a reference to a subset of an array. This hidden indirection is what makes Go's slices so easy & powerful, and yet so difficult to use efficiently.

One other gripe that I have with Go is gofmt. While Pikey [suggests](https://youtu.be/PAAkCSZUG1c?si=N4vBUS9vyy-RbgkE&t=522) that "Gofmt's style is no one's favourite, yet gofmt is everyone's favourite"; I find that to be only half correct.

For instance, take the following snippet from [zerobitperf](/cs/zerobitperf):
```go
func nzerobit(key []byte) int {
    var n int
    for _, b := range key {
        if (b>>0)&1 == 0 { n++ } else { return n }
        if (b>>1)&1 == 0 { n++ } else { return n }
        if (b>>2)&1 == 0 { n++ } else { return n }
        if (b>>3)&1 == 0 { n++ } else { return n }
        if (b>>4)&1 == 0 { n++ } else { return n }
        if (b>>5)&1 == 0 { n++ } else { return n }
        if (b>>6)&1 == 0 { n++ } else { return n }
        if (b>>7)&1 == 0 { n++ } else { return n }
    }
    return n
}
```

The above is an unrolled loop. Let's see what gofmt does with it...
```go
func nzerobit_3(key []byte) int {
	var n int
	for _, b := range key {
		if (b>>0)&1 == 0 {
			n++
		} else {
			return n
		}
		if (b>>1)&1 == 0 {
			n++
		} else {
			return n
		}
		if (b>>2)&1 == 0 {
			n++
		} else {
			return n
		}
		if (b>>3)&1 == 0 {
			n++
		} else {
			return n
		}
		if (b>>4)&1 == 0 {
			n++
		} else {
			return n
		}
		if (b>>5)&1 == 0 {
			n++
		} else {
			return n
		}
		if (b>>6)&1 == 0 {
			n++
		} else {
			return n
		}
		if (b>>7)&1 == 0 {
			n++
		} else {
			return n
		}
	}
	return n
}
```
Is the former not more readable? Now, you might argue that if you're bit twiddling and unrolling loops, then you've already left the bounds of Go's ideals. However, I could show you many such examples where the condensed form is more readable than gofmt's expanded form.

Nevertheless, I persevered with Go. Now godave is quite a performant library, and still only 660 (long) lines. Considering what it does, I find that pretty cool. I've truly enjoyed writing it. I must give credit where it's due; it was trivial to implement dave in Go. I feel that the language makes programming fun and light-hearted.

In my opinion, go routines and channels are by an imperial mile the best aspects of Go. They're well-designed, usable, and performant. Many other features, such as generics, taste like salt. However, due to it's simplicity, I feel that choosing Go as a first programming language would be a solid choice. I will continue to use Go where time to implement trumps performance and stability.

One of my main lessons from writing dave in Go, a language that depends on a garbage-collected runtime, is the importance of being kind to the garbage collector by reusing memory.

My personal interests are slowly shifting towards experimenting with software defined radio, and another project that I will not yet disclose. I feel that before I embark upon these journeys, I should level up my working knowledge of systems.

I've recently been captivated by Zig, and I'm sincerely enjoying learning a new language.

When I discovered Zig only a couple of months ago, I was blown away by it's safety and simplicity. Actually, Zig is what re-ignited my interest in systems programming, and opened my mind to the possibilities of interacting more closely with hardware in a more intuitive and powerful way than I had experienced with C.

Learning Zig is taking me back to my early teens, when I learned C. I relish this time as a total beginner, as for me this is possibly the most fun and fequently-rewarding stage of learning. It's effortless to be forgiving of ourselves in the early stages of learning. Frustration and need for discipline only begin to creep in once we have expectations and needs beyond our skills.