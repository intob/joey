---
title: First thoughts on Zig
description: I describe what I like about the Zig systems programming language, and what I don't like after a couple of weeks of tinkering.
date: 2024-12-23
---
I've done very litte systems programming. I wrote Conway's Game of Life in C as a teenager. I also did a bit of assembly at GE Aviation Systems. A few years ago, I completed the Rust programming book, but struggled with the language beyond that, and never grew to love it.

I'm currently diving quite deep into systems programming in Zig. While there are many things I love about the language, namely it's elegant approach to generics and meta-programming, I do feel that the language is lacking in some ways.


## Simplicity
What I like most about the language is it's simplicity. Similar to Go in this regard, it didn't take me long to become comfortable with the syntax.


## Error handling is not ideal
One of the most obvious flaws with the language is it's error type. It's impossible to add context or details to errors.

In contrast, an error in Go for example, is just a value. This allows you to add context as the error is passed up the call stack.

I'm not sure if the Zig team will offer a solution for this.


## Powerful build system
Zig exposes a very powerful yet usable build API. Linking C libraries is quite effortless, and I'm a noob to this.

While I'm not yet familiar with much of the build system, I have the feeling that it is probably the best build system that I've seen yet.


## Lack of interfaces
Zig's philosophy is to provide low-level building blocks, rather than high-level abstractions. As such, the Zig team felt that interfaces are an unnecessary abstraction.

While I understand this view, I feel that the lack of interfaces can make the language feel quite clunky. This became particularly apparent to me when I began using the standard library's filesystem types.

I am open to the possibility that I'm just not yet familiar with some of Zig's idioms. I know there are ways implement polymorhpic behaviour in Zig.


## Generics are beautiful
Thanks to Zig's expressive compile-time metaprogramming, generics are very easy to implement and perfectly type-safe.

The following is a generic thread-safe message queue:
```zig
const std = @import("std");

pub fn Queue(comptime T: type) type {
    return struct {
        const Node = struct { data: T, next: ?*Node };
        mutex: std.Thread.Mutex,
        head: ?*Node,
        tail: ?*Node,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) !*Queue(T) {
            const queue = try allocator.create(Queue(T));
            queue.* = .{
                .mutex = std.Thread.Mutex{},
                .head = null,
                .tail = null,
                .allocator = allocator,
            };
            return queue;
        }

        pub fn deinit(self: *Queue(T)) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            while (self.head) |node| {
                const next = node.next;
                self.allocator.destroy(node);
                self.head = next;
            }
            self.tail = null;
        }

        pub fn write(self: *Queue(T), data: T) !void {
            const new_node = try self.allocator.create(Node);
            new_node.* = .{
                .data = data,
                .next = null,
            };
            self.mutex.lock();
            defer self.mutex.unlock();
            if (self.tail) |tail| {
                tail.next = new_node;
                self.tail = new_node;
            } else {
                self.head = new_node;
                self.tail = new_node;
            }
        }

        pub fn read(self: *Queue(T)) ?T {
            self.mutex.lock();
            defer self.mutex.unlock();
            if (self.head) |node| {
                const data = node.data;
                self.head = node.next;
                if (self.head == null) {
                    self.tail = null;
                }
                self.allocator.destroy(node);
                return data;
            }
            return null;
        }
    };
}

test "basic usage" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const queue = try Queue(u8).init(allocator);
    try queue.write(1);
    try queue.write(2);
    try queue.write(3);
    try std.testing.expect(queue.read() == 1);
    try std.testing.expect(queue.read() == 2);
    try std.testing.expect(queue.read() == 3);
    try std.testing.expect(queue.read() == null);
}
```

In Go, I very rarely found myself using generics. Generics in Go feel like an after-thought, and that's probably because they are.

Conversely, in Zig, I've used this comptime struct pattern many times to write reusable components.


## Standard library is bare not entirely production-ready
Some packages in the standard library are not production-ready. For example, the Blake3 implementation uses the reference rather than the optimised implementation.

There are faster and more robust HTTP servers than the one in the standard library, namely [Zap](https://github.com/zigzap/zap) built on facil.io (written in C). I had considered writing a fast HTTP server purely in Zig, until I realised how extensive the HTTP spec is. Even more so with the newer versions of HTTP.


## Memory management made easy
When I learned Rust (or tried to), I never became comfortable with it, and I was constantly fighting the compiler.

Possibly, I'm simply a better programmer these days, but I find it more likely that Zig's approach to memory management is just simpler and more explicit.

Zig is not a fancy language, it really does feel close to C. I feel that this inherently makes it easier to learn than Rust.

Mostly writing Go recently, I expected that Zig's memory management would be a really big hurdle. While it has taken me a few days to become comfortable allocating memory on the heap, I was surprised how easy I found it. So far I've only had one memory leak, and the compiler made it trivial to locate.

I'm still not fully familiar with each of the standard library's allocators, and I mostly use the GeneralPurposeAllocator.


# Conclusion

I'm only a couple of weeks into my journey with Zig.

Would I use Zig for work? Probably not any time soon. The ecosystem is still to small. For example, there is still no official AWS SDK written in Zig. Despite this, I will continue building with Zig in my own time. 

My reason for beginning with Zig was to get into systems programming, and I'm really enjoying it. I remember faffing with header files in C as a teenager, and I know that building C projects can be a real pain. So far I'm quite happy with Zig, and I'm optimistic that a lot of the kinks will be ironed out as the language matures.

There will never be a perfect language for everyone for all use-cases. As I've been learning Zig, I've come to appreciate how hard it is to design a language that is fit for decades of mission-critical software engineering. It's incredible how good C is, despite it's (lack of) build system. I've also come to realise how much of Go they got right. Writing concurrent software in Zig has left me with an appreciation for Go's channels. The only thing that I would change about Go is the verbose error handling.

I feel that learning a new programming language allows us to open our minds to alternative paradigms. It teaches us how to design better software, and make better use of languages that we already know and love.