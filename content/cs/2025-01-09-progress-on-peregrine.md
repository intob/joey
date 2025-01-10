---
title: Progress on the Peregrine HTTP server
description: As a way for me to dive deeper into Zig, I'm writing a HTTP server from scratch. This article describes some of the work I've done recently, and a few lessons that I've learned.
date: 2025-01-09
---
I'm implementing a HTTP server from scratch in Zig, as a fun way to learn the Zig systems programming language, and also to get more comfortable and familiar with some modern kernel features that make highly performant network IO possible.

I started this project on the 24th December 2024, and within a couple of days, I had a bare-bones TCP server that could parse and respond to HTTP requests. Initially, I followed Karl Seguin's excellent [guide to creating a TCP server in Zig](https://www.openmymind.net/TCP-Server-In-Zig-Part-1-Single-Threaded/). If you're interested in learning Zig, after solving some [Ziglings](https://codeberg.org/ziglings/exercises/), I suggest that you look at Karl's blog posts on Zig.

After some light optimisation work, I wrote some example applications because I know that the best way to test the usability of your library is to use it.

Initially, the server was initialised with an `on_request(request, response) void` handler function. I found that this approach made it difficult to create a stateful request handler. After trying a VTable-based interface, I settled on the more idiomatic Zig generic pattern, leveraging Zig's comptime metaprogramming. Basically, you just call `Server(MyHandler).init(config)`, where Server is a function that returns a type of Server that has your handler built in at compile time. You then simply define your handler as the implementation of an interface, containing at least the required methods. If the user messes anything up, the program will simply fail to compile, and some useful error will be output.

Anyway, with the nicer API, I implemented a simple counter server where the handler increments a counter on each request, and responds with the current value. I then wanted to see my server doing something useful, so I wrote a directory server, and served this website locally. To my delight, the server was working great, and the implementation of the DirServer helper required no significant changes to the server. It was fun to see the server working well, serving binaries and text files that were rendered correctly by the browser.

At this point, the server was slightly more performant than Go's stdlib HTTP server. Go's HTTP server is a good benchmark, because it's well written and used extensively in production. Also, it supports HTTP/2 and TLS out of the box, which is really great. Unfortunately, Peregrine does not yet support HTTP/2 or TLS. However, Peregrine does beat Go's HTTP server in one regard, and that is built in support for WebSockets. Peregrine features full support for WebSockets, and adding WebSocket support to your application is as easy as handling the connection upgrade by calling the upgrade helper function, and implementing the WS handler methods in your handler. It really could not be easier, and I'm quite happy with how that turned out.

Slightly more performant than Go's HTTP server? There is no way that we can be happy with that... afterall, many HTTP servers outperform Go's.

From my own tests, NGINX only marginally outperforms Go's, even with some tuning such as enabling Kqueue/Epoll and setting the thread count equal to the CPU core count. That surprised me, because as far as I know, Go relies on it's runtime scheduler, and does not use Kqueue/Epoll for socket readiness notifications, which should eliminate wasted CPU time spent polling the sockets.

At the front of the pack is [Zap](https://github.com/zigzap/zap), built on [Facil.io](https://facil.io). Zap is basically Zig bindings for the HTTP server part of Facil.io. Facil.io is a marvellous networking library written in C. The more I study and benchmark Facil.io, the more I've come to appreciate it's stability and performance. On my M2 Pro, Zap will process in exess of 170K static GET requests per second with 1000 connections. I've not yet found a HTTP server that outperforms this with 1000 connections. Please let me know if there is one.

As a baseline, on 28th December, 4 days after the start of the project, Peregrine was doing around 86K static GET requests per second with 1000 connections. Similar to Go's stdlib HTTP server and also similar to (tuned) NGINX. At this point, Zap/Facil.io does more than twice the throughput. We have a lot of work to do...

## Step 1: Improve the handler
As I mentioned earlier, the nature of the library's on_request hook made implementing a stateful handler inconvenient at best. This was at the top of my list. I implemented a VTable-based interface, but I didn't like that the user needed to declare the VTable in their handler:
```zig
// commit 0beb0019df043abb43e924d4aa8234f479eba607
// ./example/basic.zig
const MyHandler = struct {
    const vtable: pereg.HandlerVTable = .{
        .handle = handle,
    };

    pub fn handle(ptr: *anyopaque, req: *pereg.Request, resp: *pereg.Response) void {
        const self = @as(*@This(), @alignCast(@ptrCast(ptr)));
        self.handleWithError(req, resp) catch |err| {
            std.debug.print("error handling request: {any}\n", .{err});
        };
    }

    inline fn handleWithError(_: *@This(), _: *pereg.Request, resp: *pereg.Response) !void {
        _ = try resp.setBody("Kawww\n");
        const len_header = try pereg.Header.init(.{ .key = "Content-Length", .value = "6" });
        try resp.headers.append(len_header);
    }
};
```
This version actually performed quite well, doing a little over 160K requests per second. That's nearly a 2x improvement from our baseline! In retrospect, I'm surprised that this version performs so well, because the indirection of the VTable lookup should cost at least a few nanoseconds, not to mention that this indirection should increase CPU cache misses for calls to handler methods. It seems that function pointers are even more costly than VTables. Anyway, this performs well, but it's quite ugly, and does not make use of what Zig has to offer. We need a better way to 'inject' our handler into the server.
```zig
// commit 2d13a14cd5ed77de040bea003ad37a55020fb54d
// ./example/basic.zig
const std = @import("std");
const pereg = @import("peregrine");

const MyHandler = struct {
    pub fn init(allocator: std.mem.Allocator) !*@This() {
        return try allocator.create(@This());
    }

    pub fn deinit(_: *@This()) void {}

    pub fn handle(self: *@This(), req: *pereg.Request, resp: *pereg.Response) void {
        self.handleWithError(req, resp) catch |err| {
            std.debug.print("error handling request: {any}\n", .{err});
        };
    }

    fn handleWithError(_: *@This(), _: *pereg.Request, resp: *pereg.Response) !void {
        _ = try resp.setBody("Kawww\n");
        const len_header = try pereg.Header.init(.{ .key = "Content-Length", .value = "6" });
        try resp.headers.append(len_header);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    const srv = try pereg.Server(MyHandler).init(allocator, 3000, .{});
    std.debug.print("listening on 0.0.0.0:3000\n", .{});
    try srv.start(); // Blocks if there is no error
}
```
By the way, sorry for `@This()` in the method signatures, this was pasted as committed. I've since started declaring `const Self = @This();` to clean up method signatures. This looks much better. Our handler simply implements the 3 required methods; init, deinit, and handle. Our handler is then given to the Server by making Server a function that returns a type. Our handler is passed to the 'constructor' as a parameter. Under the hood:
```zig
// commit 2d13a14cd5ed77de040bea003ad37a55020fb54d
// ./src/server.zig
pub fn Server(comptime Handler: type) type {
    return struct {
        comptime {
            if (!@hasDecl(Handler, "init")) {
                @compileError("Handler must implement init(std.mem.Allocator) !*@This()");
            }
            if (!@hasDecl(Handler, "deinit")) {
                @compileError("Handler must implement deinit(*@This()) void");
            }
            if (!@hasDecl(Handler, "handle")) {
                @compileError("Handle must implement handle(*@This(), *Request, *Response) void");
            }
        }

        handler: *Handler,
        // ...
    };
}
```
Pretty simple, right? As it should be. As you can see, we will get a compile error if our handler is missing any of the 3 required methods.

## Step 2: optimise the request parser
Being a text protocol, efficient parsing of a HTTP request comes down to well-implemented buffered reading from the socket, and optimised parsing operations. The parts of a HTTP request are delimited by CRLF (sometimes clients may use bare LF line endings). The first line contains the request method, path, and HTTP version. The following lines contain headers, until an empty line. If present, the request body would follow. The length would be specified in a Content-Length header. For example (without body):
```
GET /path/to/resource HTTP/1.1\r\n
Host: localhost\r\n
User-Agent: Microsoft Internet Explorer 6\r\n
Accept: */*\r\n
Connection: keep-alive\r\n
\r\n
```
As a side note, the Connection header is the client's request for the server to either close or keep-alive the TCP connection. HTTP/1.1 introduced the keep-alive mechanism, allowing connections to be reused. This greatly improves HTTP's efficiency, expecially as modern websites typically consist of many resources that are requested individually. In HTTP/1.0, clients had to create a new connection for each request. Our server must handle both HTTP/1.0 and HTTP/1.1 as a bare minimum. HTTP/2 and HTTP/3 would be great to have, but these are binary protocols, and must be upgraded to from a HTTP/1.1 connection. Additionally, HTTP/3 is not over TCP, but QUIC, which is over UDP. Support for HTTP/2 and 3 may come later.

So, how to parse this request? Logically, we should read it line-by-line. So far, I've found that efficient request parsing is about minimising search and copy operations.

If you're interested, check out [./src/reader.zig](https://github.com/intob/peregrine/blob/main/src/reader.zig). I'll spare you a complicated code-dump.

### Method, path and version
In essence, the method and version are parsed first, at the begining and the end of the first line. Parsing the method was originally done using a compile-time generated lookup table of 8-byte masks. SIMD operations were then used to compare the first 8 bytes of the request with the lookup table. In practice, I was not happy with how some methods were parsed fairly quickly (9ns), but other methods further down the lookup table took considerably longer (over 30ns) due them requiring more comparisons.

While a few nanoseconds may seem negligible, I'm trying to keep request parsing under 2000 CPU cycles. That's around 600ns on my M2 Pro.

I also tried a switch of the method length before byte comparisons, but this necessitated finding the first ' ', which cost more than the saving of narrowing down the number of possible methods.

Today, I settled on the following:
```zig
pub const Method = enum(u4) {
    GET,
    PUT,
    HEAD,
    POST,
    PATCH,
    TRACE,
    DELETE,
    CONNECT,
    OPTIONS,

    pub fn parse(bytes: []const u8) !Method {
        if (bytes.len < 3) return error.UnsupportedMethod;
        return switch (bytes[0]) {
            'G' => .GET,
            'P' => switch (bytes[1]) {
                'O' => .POST,
                'U' => .PUT,
                'A' => .PATCH,
                else => error.UnsupportedMethod,
            },
            'H' => .HEAD,
            'T' => .TRACE,
            'D' => .DELETE,
            'C' => .CONNECT,
            'O' => .OPTIONS,
            else => error.UnsupportedMethod,
        };
    }

    pub fn toLength(self: Method) usize {
        return switch (self) {
            .GET => 3,
            .PUT => 3,
            .HEAD => 4,
            .POST => 4,
            .PATCH => 5,
            .TRACE => 5,
            .DELETE => 6,
            .CONNECT => 7,
            .OPTIONS => 7,
        };
    }
};
```
As beautiful as the comptime-generated lookup table was, I found that the overhead of initialising SIMD vectors was too expensive for this use-case. The above solution is much faster, with methods parsed between 6ns and 9ns. We simply give it at least 3 bytes, and in the fewest operations possible, it will return the method.

We then parse the HTTP version. Not worthy of a code-dump, we simply take the last 8 bytes of the request line, and check that the 6th byte is '1' (HTTP/1), the 7th byte is '.', and switch over the 8th byte to return the version enum 1.0 or 1.1. You can see it in [./src/version.zig](https://github.com/intob/peregrine/blob/main/src/version.zig).

Next is extracting the path. You probably noticed the toLength method in the Method enum. We know that everything between the method and the version (minus the spaces) is the path and query. We also know that the version is 8 bytes in length. Therefore, by calling toLength() on the method, we have the position of the beginning of the path without a single scalar search for the delimiting spaces (' ').

But what about separating the query from the path? We could simply defer this until (if ever) the query is needed, omitting the search for '?', but I found that this hurt the usability of the library. I may change this again because searching for '?' is relatively expensive, and not always required. For now, the path and query are separated, but the query is never parsed, and instead stored in it's raw URL-encoded form. Calling request.parseQuery() will populate a hash map in the request.

### Parsing headers
Here, we simply read the headers line-by-line, parsing them using a scalar search for ':' which is the delimiter for the key-value pair. The header is simply a struct with key and value fields. If you're looking at [./src/header.zig](https://github.com/intob/peregrine/blob/main/src/header.zig) and wondering why Header contains fixed-sized arrays and length fields... Requests are pre-allocated with a fixed-sized array of 32 Headers. This means that we don't need to allocate headers for each request.

Some of the most important optimisations can manifest as quite ugly 'hacky' tricks. Such is the case for the Connection header. The Connection header is a little special, because it isn't really for an application/library user to think about, but a client request for the server to handle the connection in a specific way. The value is normally either "keep-alive" or "close". The server may still choose to close the connection, for example, if the limit of connection requests has been reached. Therefore, when we respond to a HTTP/1.1 request, we most often need to evaluate the Connection header. Initially, I was searching for the Connection header while generating the response, but I noticed that we could save a few nanoseconds by moving this into the header parsing step, as we're already iterating over the headers. This was as simple as adding a boolean flag to the request `keep_alive`. Looking at the implementation at time of writing, it's so ugly that I don't want to dump the code here! If you want, check it out in the parseHeaders method in [./src/reader.zig](https://github.com/intob/peregrine/blob/main/src/reader.zig). Basically, we do a quick process of elimination by raw length, before checking if the value starts with 'cl' for 'close'. Notice the `conn_header_found` flag in the method to prevent wasted operations after we've found it.

### SIMD for `reader.readLine`
How could I forget? `reader.readLine(fd: posix.socket_t)` is right in the critical path. See [./src/reader.zig](https://github.com/intob/peregrine/blob/main/src/reader.zig).

One important optimisation here is the use of SIMD (vectors/chunks) when searching for line-endings. Rather than check byte-by-byte if we have a new-line character, we can leverage the SIMD (single-instruction-multiple-data) support of modern CPUs. This allows us to fill a mask with new-line characters, and check whether each 16-byte chunk contains the new-line. If it does, we simply call the built-in @ctz (count trailing zeros) to calculate it's offset (position) in the chunk.

For any remaining bytes (if the line-length is not divisible by 16), we simply iterate over them byte-by-byte.

The use of SIMD is often integral to efficient data processing, and you will see it a lot.

## Step 3: Write iovecs
Finally for this article, when the [./src/worker.zig](https://github.com/intob/peregrine/blob/main/src/worker.zig) responds to a request, making a syscall to write each part of the response, or concatenating the response status line, headers, and body buffers, we can make use of `posix.writev` to write a slice of iovecs (IO vectors) with a single syscall. This is much more efficient. Thanks to Karl Seguin for his [guide to writing iovecs in Zig](https://www.openmymind.net/TCP-Server-In-Zig-Part-3-Minimizing-Writes-and-Reads/). I'd like to reiterate just how helpful I've found his guides, so thank you Karl.

## Wrap up
I hope you found some of this interesting. I quite enjoy writing these, as it's a good way for me to reflect on some of the decisions that I've made while. While writing this, I even found a couple of little things that I can improve.

Thanks to Bo (author of Facil.io), for his advice for optimising the server implementation. Facil.io still outperforms Peregrine by around 10%, and shows better stability of response times under load. I think that this is due to Bo's superior solution for distributing and scheduling the computation.

Today, I implemented a fairly performant ring buffer queue (50ns for one read and one write). Maybe I can still improve this by a factor of 2, as a hardware lock should only take a single cycle.
```zig
const std = @import("std");

pub fn RingQueue(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        buffer: []T,
        read_index: usize = 0,
        write_index: usize = 0,
        mutex: std.Thread.Mutex = .{},
        not_empty: std.Thread.Condition = .{},
        not_full: std.Thread.Condition = .{},

        pub fn init(allocator: std.mem.Allocator, capacity: usize) !*Self {
            const self = try allocator.create(Self);
            self.* = .{
                .allocator = allocator,
                .buffer = try allocator.alloc(T, capacity),
            };
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.buffer);
            self.allocator.destroy(self);
        }

        fn isFull(self: *Self) bool {
            return (self.write_index + 1) % self.buffer.len == self.read_index;
        }

        fn isEmpty(self: *Self) bool {
            return self.write_index == self.read_index;
        }

        pub fn write(self: *Self, data: T) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            while (self.isFull()) {
                self.not_full.wait(&self.mutex);
            }
            self.buffer[self.write_index] = data;
            self.write_index = (self.write_index + 1) % self.buffer.len;

            self.not_empty.signal();
        }

        pub fn read(self: *Self) T {
            self.mutex.lock();
            defer self.mutex.unlock();
            while (self.isEmpty()) {
                self.not_empty.wait(&self.mutex);
            }
            const data = self.buffer[self.read_index];
            self.read_index = (self.read_index + 1) % self.buffer.len;
            self.not_full.signal();
            return data;
        }
    };
}
```
This queue will make it possible to distribute work (requests to handle) to a thread pool on a FIFO basis. This would prevent long-running handlers from blocking an entire worker, which could block multiple connections.

I also learned that Zig supports async/await as this could be an even better way for each worker in the pool to handle multiple requests concurrently.

Peace & love!
J
