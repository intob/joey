---
title: The beginning of project Peregrine - a bleeding fast HTTP server
description: As a way for me to dive deeper into Zig, I'm writing a HTTP server from scratch.
date: 2024-12-26
---
If you're very familiar with Zig, then you'll know that the standard library HTTP server is not written to be highly performant.

[Zap](https://github.com/zigzap/zap) is an alternative. Zap is built on the fantastic [Facil.io](https://facil.io) networking library written in C.

Now, while there are plenty of fast HTTP servers, at time of writing, I couldn't find a production-ready high-performance HTTP server written purely in Zig.

As I need a real project to get deeper into the language, and having never written a HTTP server from scratch before, I felt that this would be a great opportunity to have fun learning about Zig, async IO, vectored IO, memory alignment, zero-alloc, zero-copy and a bunch of other systems stuff.

[Peregrine - a bleeding fast HTTP server](https://github.com/intob/peregrine)

My goal with this project is to write a robust, performant and simple HTTP server. In doing so, I will learn much of the Zig language, and a bunch about systems programming.

I started this project on 2024-12-24, two days ago at time of writing. So how far have I got in two days?

Currently, we have the main components of the server implemented. The server is written in a library form, and exposes a clean API to create a server and handle requests.

There is a worker pool. Each worker runs on it's own thread. For now, connecting sockets are assigned to a worker using round-robin distribution. This means that we don't need a scheduler.

Kqueue is the FreeBSD/MacOS solution for async IO. It's a kernel event system. Basically, you register interest in a type of event. You then process the events. We have one of these event buses for our server's main thread, where we accept connections. Each connecting socket is then assigned to a worker by registering interest in the client socket's events with the worker's event bus. This means that when clients write to the socket, the appropriate worker is notified and will process the event. In this case, the worker processing the event means reading from the socket.

For the Linux kernel, there is a different solution, called epoll. In some ways Kqueue is superior to epoll because Kqueue allows registering interest in multiple events with a single system call. Conversely, with epoll, each interest must be registered with separate sys calls. In our case, this won't make any difference because we make a sys call every time we accept a new connection. If we didn't, clients would have to wait until their socket was registered. Otherwise, epoll is very similar to kqueue, as far as I know. In the next days, I will implement epoll to support Linux.

When each worker starts, it does all of it's heap allocations that it needs for normal operation. Ideally, no further heap allocations will be made per-request. This zero-alloc approach greatly improves performance because we don't need to wait for memory to be allocated on the heap before progressing with processing each request.

Each worker can handle one request at a time. This constraint allows us to reuse the buffers and data structures that it allocates. The only thing we have to ensure is that they are properly reset before reuse.

Getting deeper into the guts of the server, each worker creates a request reader. This request reader reads from a given socket, and maintains a buffer of read-but-unprocessed data. When we call readRequest, unprocessed data in the buffer will be read before compacting the buffer and making another syscall to get more data. This approach means that fewer syscalls are used to read each request, while not needing a particularly large buffer.

One optimisation that I've made already is that buffers are properly aligned. This means that the data's memory address is a multiple of it's size. Memory alignment is cruicial for high-performance software because the CPU accesses memory most efficiently when data is naturally aligned. This allows the processor to fetch memory in a single operation, whereas misaligned data may require multiple accesses. Additionally, aligned data structures help to optimise cache efficiency. When data crosses cache line boundaries, it can result in additional cache misses, resulting in performance degredation.

Below is the critical path of the worker's event loop. Each kernel event is processed as follows.
```zig
// ./src/worker.zig
fn handleKevent(self: *Worker, socket: posix.socket_t, reader: *request.RequestReader) !void {
    defer posix.close(socket);
    self.req.reset();
    try reader.readRequest(socket, self.req);
    self.resp.reset();
    self.on_request(self.req, self.resp);
    if (!self.resp.hijacked) try self.respond(socket);
}

fn respond(self: *Worker, socket: posix.socket_t) !void {
    const headers_len = try self.resp.serialiseHeaders(&self.resp_buf);
    if (self.resp.body_len > 0) {
        var iovecs = [_]posix.iovec_const{
            .{ .base = @ptrCast(self.resp_buf[0..headers_len]), .len = headers_len },
            .{ .base = @ptrCast(self.resp.body[0..self.resp.body_len]), .len = self.resp.body_len },
        };
        const written = try posix.writev(socket, &iovecs);
        if (written != headers_len + self.resp.body_len) {
            return error.WriteError;
        }
        return;
    }
    try writeAll(socket, self.resp_buf[0..headers_len]);
}
```

One optimisation you can see above is in the respond method. This is called after the user's on_request handler is called, providing that they did not hijack the response. More on that later. If the response has a body, vectored IO is used to write the headers and body in a single syscall, without needing to concatenate the buffers. If there is no body, the response is written by repeatedly writing to the socket until all bytes are written. Without a body, this is likely to be achieved in a single syscall.

Making use of x86's SIMD and ARM's NEON capabilities allow us to speed up a variety of operations. One example that you will see often is chunking. This is where slices are processed in chunks, rather than operating on single bytes. This is important because operating on single bytes does not make good use of the cache. A good example of this is in Zig's stdlib: `std.mem.indexOfScalarPos`. See below:
```zig
pub fn indexOfScalarPos(comptime T: type, slice: []const T, start_index: usize, value: T) ?usize {
    if (start_index >= slice.len) return null;

    var i: usize = start_index;
    if (backend_supports_vectors and
        !std.debug.inValgrind() and // https://github.com/ziglang/zig/issues/17717
        !@inComptime() and
        (@typeInfo(T) == .int or @typeInfo(T) == .float) and std.math.isPowerOfTwo(@bitSizeOf(T)))
    {
        if (std.simd.suggestVectorLength(T)) |block_len| {
            // For Intel Nehalem (2009) and AMD Bulldozer (2012) or later, unaligned loads on aligned data result
            // in the same execution as aligned loads. We ignore older arch's here and don't bother pre-aligning.
            //
            // Use `std.simd.suggestVectorLength(T)` to get the same alignment as used in this function
            // however this usually isn't necessary unless your arch has a performance penalty due to this.
            //
            // This may differ for other arch's. Arm for example costs a cycle when loading across a cache
            // line so explicit alignment prologues may be worth exploration.

            // Unrolling here is ~10% improvement. We can then do one bounds check every 2 blocks
            // instead of one which adds up.
            const Block = @Vector(block_len, T);
            if (i + 2 * block_len < slice.len) {
                const mask: Block = @splat(value);
                while (true) {
                    inline for (0..2) |_| {
                        const block: Block = slice[i..][0..block_len].*;
                        const matches = block == mask;
                        if (@reduce(.Or, matches)) {
                            return i + std.simd.firstTrue(matches).?;
                        }
                        i += block_len;
                    }
                    if (i + 2 * block_len >= slice.len) break;
                }
            }

            // {block_len, block_len / 2} check
            inline for (0..2) |j| {
                const block_x_len = block_len / (1 << j);
                comptime if (block_x_len < 4) break;

                const BlockX = @Vector(block_x_len, T);
                if (i + block_x_len < slice.len) {
                    const mask: BlockX = @splat(value);
                    const block: BlockX = slice[i..][0..block_x_len].*;
                    const matches = block == mask;
                    if (@reduce(.Or, matches)) {
                        return i + std.simd.firstTrue(matches).?;
                    }
                    i += block_x_len;
                }
            }
        }
    }

    for (slice[i..], i..) |c, j| {
        if (c == value) return j;
    }
    return null;
}
```
This searches a slice for a specific value. Normally this would be a slice of bytes, and we'd be searching for a byte. If we were to search the slice byte-by-byte, the CPU would have to individually load each byte into a register for comparison. In the above example, you can see how a bit mask is used to efficiently test if the target byte is somewhere in the chunk.

The naive and much slower implementation would be as follows:
```zig
pub fn indexOfPos(comptime T: type, slice []const T, start_index: usize, value T) ?usize
    if (start_index >= slice.len) return null;
    var i: usize = 0;
    while (i < slice.len) : (i += 1) {
        if (slice[i] == value) return i;
    }
    return null;
```

Often, adding some room for complexity allows us to solve problems more efficiently. Good engineering is partly about balancing performance gains with simplicity. A good engineer knows what to optimise, and what not to. Tight loops in critical paths tend to offer the greatest reward for optimisation.

Anyway, hopefully that was interesting. After a couple of days, we have the bare bones of a high-performance HTTP server, written purely in Zig. Considering that I'm new to systems programming and Zig, I feel that I'm doing alright. It surely is a very fun and expressive language. I'm enjoying the build speed and the quality of the compiler's errors.

Stay tuned for my progress, as I will be working on this to make it production-ready. I'm not sure how long it will take, but I am sure that I'll continue learning a lot.

Peace and love!
J
