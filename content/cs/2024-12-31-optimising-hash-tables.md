---
title: Optimising hash tables
description: Making hash tables fast is really fun. As hash tables are used in most software, it's also something that can often be done to improve performance. This article explains how I implemented a hash table, and how I chose a suitable hash function. It also covers a bit about non-cryptographic hash functions in general.
date: 2024-12-31
---
While working on my HTTP server implementation, I was trying to optimise the critical path for processing reqeusts.

This is the worker loop, the event loop that handles the socket readiness notifications. When a socket becomes 'ready', it means that there is most likely data to read. As per the HTTP spec, we should terminate connections after processing the chosen limit of requests per connection. This limit is sent to the client in the `connection` header. At the bottom is where we read from the `connection_requests` map, and increment the stored value.
```zig
fn workerLoop(self: *Self) void {
    const EventType = switch (native_os) {
        .freebsd, .netbsd, .openbsd, .dragonfly, .macos => posix.Kevent,
        .linux => linux.epoll_event,
        else => unreachable,
    };
    var events: [256]EventType = undefined;
    // TODO: make request reader buffer size configurable
    // Buffer is aligned internally
    const reader = RequestReader.init(self.allocator, 4096) catch |err| {
        std.debug.print("error allocating reader: {any}\n", .{err});
        return;
    };
    defer reader.deinit();
    while (!self.shutdown.load(.unordered)) {
        const ready_count = self.io_handler.wait(&events) catch |err| {
            std.debug.print("error waiting for events: {any}\n", .{err});
            continue;
        };
        for (events[0..ready_count]) |event| {
            const fd: i32 = switch (native_os) {
                .freebsd, .netbsd, .openbsd, .dragonfly, .macos => @intCast(event.udata),
                .linux => event.data.fd,
                else => unreachable,
            };
            self.readSocket(fd, reader) catch |err| {
                self.closeSocket(fd);
                switch (err) {
                    error.EOF => {}, // Expected case
                    else => std.debug.print("error reading socket: {any}\n", .{err}),
                }
                continue;
            };
            // Here we get the number of requests from the connection_requests hash map.
            // This allows us to terminate connections once the request limit has been reached.
            const requests_handled = self.connection_requests.get(fd) orelse 0;
            if (requests_handled >= CONNECTION_MAX_REQUESTS) {
                // Close the socket if the request limit has been reached.
                self.closeSocket(fd);
            } else {
                // Here we increment the stored number of requests for the connection.
                self.connection_requests.put(fd, requests_handled + 1) catch |err| {
                    std.debug.print("error updating socket request count: {any}\n", .{err});
                };
            }
        }
    }
}
```

As you can see, this is certainly in the critical path, and if we can optimise this hash map, we can get a nice performance boost.

## Benchmarking AutoHashMap

But how does `std.AutoHashMap` perform for this use case? Well, let's benchmark it.
```zig
test "benchmark AutoHashMap put" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var map = std.AutoHashMap(i32, u32).init(allocator);
    defer map.deinit();
    const iterations = 100_000_000;
    var i: i32 = 0;
    var timer = try std.time.Timer.start();
    while (i < iterations) : (i += 1) {
        try map.put(i, 1);
    }
    const elapsed = timer.lap();
    const avg_ns = @divFloor(elapsed, iterations);
    std.debug.print("Average time: {d}ns\n", .{avg_ns});
}
// Output: Average time: 452ns

test "benchmark AutoHashMap get" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var map = std.AutoHashMap(i32, u32).init(allocator);
    defer map.deinit();
    const iterations = 100_000_000;
    var i: i32 = 0;
    var timer = try std.time.Timer.start();
    while (i < iterations) : (i += 1) {
        _ = map.get(i);
    }
    const elapsed = timer.lap();
    const avg_ns = @divFloor(elapsed, iterations);
    std.debug.print("Average time: {d}ns\n", .{avg_ns});
}
// Output: Average time: 9ns
```

So Zig's standard library AutoHashMap takes 452ns per call to `put`. The call to `get` is much faster at 9ns. Get is fairly fast, but the put is quite slow. I'm sure that we can do better than that. Let's write a hash map to find out.

## Implementing our own hash map
So we need to write a map that stores a u32 (32-bit unsigned integer) for each i32 (32-bit signed integer). Under the hood, file descriptors are normally i32. These values are always positive, only being negative in the case of an error (normally -1 in this case). With this knowledge, we can simplify our hash map by using an unsigned integer for our key. This makes writing a hash function much easier.

```zig
pub const FdMap = struct {
    allocator: std.mem.Allocator, // Allocator used to allocate and free memory
    values: []u32, // Slice in which we will store our values
    g: []u32, // The displacement of our values
}
```
If you're not familiar with Zig, the allocator is necessary to allocate memory. We will use it when initialising the hash map, and we will use it to free the memory when we deinitialise it.

Let's write the code to initialise and deinitialise our hash map.
```zig
pub const FdMap = struct {
    // ...
    pub fn init(allocator: std.mem.Allocator, max_fds: usize) !*@This() {
        const self = try allocator.create(@This()); // Create a pointer to this FdMap
        self.* = .{
            // Store our allocator so that we can free allocated memory later
            .allocator = allocator,
            // Allocate the desired number of values
            .values = try allocator.alloc(u32, max_fds),
            // Allocate the same number of u32s for storing each value's' displacement
            .g = try allocator.alloc(u32, max_fds),
        };
        @memset(self.values, 0);
        @memset(self.g, 0);
        return self;
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.values);
        self.allocator.free(self.g);
        self.allocator.destroy(self);
    }
}
```

Now we need a hash function. xxHash is pretty fast, but is not optimised for small values. When hashing small values, simple hash functions tend to perform best. This is because there is little overhead from complex instructions. Also, when hashing small values, complex instructions often fail to improve the distribution of values.

Before we write a hash function, we need it to take two inputs; the file descriptor, and a displacement. The displacement allows us to resolve collisions. In the case of a collision, we simply increment the displacement until we find an empty slot in the map.

### Multiply-then-shift hash function
The simplest hash function that I'm aware of is multiply-then-shift.
```zig
fn hash(d: u32, fd: u32) u32 {
    return ((fd +% d) *% 11) >> 1;
}
```
Let's break down how it works...

#### Components
1. `fd +% d`: Combines the file descriptor with the displacement value using wrapping addition
2. `*% 11`: Multiplies by a small prime number (11) using wrapping multiplication
3. `>> 1`: Shifts right by 1 bit, effectively dividing by 2

#### Example flow
For input `fd = 5` and `d = 0`:
1. `5 +% 0 = 5`
2. `5 *% 11 = 55`
3. `55 >> 1 = 27`

#### Why it works (sort of)
- Multiplication by odd numbers (like 11) helps to spread bits
- Right shift helps to distribute high-order bits into result
- Wrapping operations prevent overflow
- Prime multiplier helps reduce patterns in output

#### Limitations
- Very simple distribution pattern
- Poor avalanche effect (small input changes create small output changes)
- Likely to cause more collisions than sophisticated hash functions

The deal-breaker is that sequential inputs produce sequential outputs with small gaps. This will not work at all for our file descriptor use case because file descriptors tend to be assigned in a sequential manner.

### Much better multiply-then-shift hash function
This is significantly better than the above example, while still being relatively simple. This hash function can be found on [Stack Overflow](https://stackoverflow.com/questions/664014/what-integer-hash-function-are-good-that-accepts-an-integer-hash-key)
```zig
fn hash(d: u32, fd: u32) u32 {
    const k: u32 = 0x45d9f3b;  // carefully chosen multiplier
    return ((fd +% d) *% k) >> 16;
}
```
#### Properties
- Uses simple arithmetic operations
- Combines displacement and key with wrapping addition
- Multiplies by a carefully chosen constant
- Uses right shift to distribute high-order bits
- Performs better than MurmurHash's 32-bit finalizer
- Nearly matches AES quality (though not quite)
- Provides excellent confusion and diffusion properties
- Ensures each output bit changes with approximately equal probability when an input bit changes

This is actually a really interesting hash function for a couple of reasons. The multiplier was chosen through testing and optimisation for 32-bit integer hashing. It was selected using a multi-threaded [test program](https://github.com/h2database/h2database/blob/master/h2/src/test/org/h2/test/store/CalculateHashConstant.java) that ran for many hours, evaluating several key properties:
- Avalanche effect: Number of output bits that change when a single input bit changes (should average around 16)
- Independence of output bit changes: Output bits should not depend on each other
- Change probability: Equal probability of each output bit changing when any input bit is changed

### Continuing with our implementation
For now, let's settle on the better multiply-then shift hash function. Now we need to implement three methods; get, put, and remove.

#### Put method
```zig
pub fn put(self: *@This(), fd: posix.socket_t, value: u32) !void {
    // Reject negative file descriptors as they can't be cast to unsigned
    if (fd < 0) return error.NegativeFileDescriptor;
    // Convert file descriptor to unsigned integer
    const fd_u: u32 = @intCast(fd);
    // Calculate initial slot using hash with 0 displacement
    const initial_slot: u32 = hash(0, fd_u) % @as(u32, @intCast(self.values.len));
    // If initial slot is empty (contains 0), we can use it directly
    if (self.values[initial_slot] == 0) {
        // Store the value in the initial slot
        self.values[initial_slot] = value;
        // Mark this slot as direct mapping by setting highest bit and storing index
        self.g[initial_slot] = initial_slot | (1 << 31);
        return;
    }
    // Initial slot was occupied, try different displacement values
    var d: u32 = 1;
    // Try each possible displacement value until we run out of space
    while (d < self.values.len) : (d += 1) {
        // Calculate new slot using current displacement value
        const next_slot: u32 = hash(d, fd_u) % @as(u32, @intCast(self.values.len));
        // If we found an empty slot
        if (self.values[next_slot] == 0) {
            // Store the value in the found slot
            self.values[next_slot] = value;
            // Store displacement value in initial slot (no high bit means displaced)
            self.g[initial_slot] = d;
            return;
        }
    }
    // If we get here, we tried all possible displacements and found no empty slot
    return error.MapFull;
}
```

#### Get method
```zig
pub fn get(self: *@This(), fd: posix.socket_t) ?u32 {
    if (fd < 0) return null; // Can't cast negative int to unsigned
    const fd_u: u32 = @intCast(fd);
    // Calculate slot by hashing fd, with 0 as the displacement.
    // Mod length of the array to keep it in-bounds.
    const slot = hash(0, fd_u) % self.g.len;
    // Look up displacement value from g array.
    // If highest bit is set, this is a direct mapping.
    // Otherwise, it's a displacement value for perfect hashing.
    const d = self.g[slot];

    return if (d & (@as(u32, 1) << 31) != 0)
        // Highest bit set means direct mapping.
        // Clear the highest bit to get the actual index into values array.
        self.values[d & ~(@as(u32, 1) << 31)]
    else
        // No direct mapping, use displacement value to compute perfect hash.
        // Hash again with displacement value to find final slot.
        self.values[hash(d, fd_u) % self.values.len];
}
```

#### Remove method
```zig
pub fn remove(self: *@This(), fd: posix.socket_t) ?u32 {
    // Reject negative file descriptors
    if (fd < 0) return null;
    // Convert file descriptor to unsigned integer
    const fd_u: u32 = @intCast(fd);
    // Calculate initial slot using hash with 0 displacement
    const slot = hash(0, fd_u) % self.g.len;
    // Get displacement or direct mapping value
    const d = self.g[slot];
    // Check if this is a direct mapping (highest bit set)
    if (d & (@as(u32, 1) << 31) != 0) {
        // Clear highest bit to get actual slot index
        const value_slot = d & ~(@as(u32, 1) << 31);
        // Get the value at this slot
        const value = self.values[value_slot];
        // If slot is empty, key wasn't in map
        if (value == 0) return null;
        // Clear the value slot
        self.values[value_slot] = 0;
        // Clear the displacement/mapping
        self.g[slot] = 0;
        // Return the removed value
        return value;
    }
    // Not direct mapping, calculate slot using displacement value
    const value_slot = hash(d, fd_u) % self.values.len;
    // Get the value at calculated slot
    const value = self.values[value_slot];
    // If slot is empty, key wasn't in map
    if (value == 0) return null;
    // Clear the value slot
    self.values[value_slot] = 0;
    // Clear the displacement value
    self.g[slot] = 0;
    // Return the removed value
    return value;
}
```

### Testing our implementation
Let's test our implementation...
```zig
test "basic usage" {
    const map = try FdMap.init(std.testing.allocator, 10);
    defer map.deinit();
    try map.put(0, 1);
    try map.put(1, 2);
    try std.testing.expectEqual(1, map.get(0) orelse 0);
    try std.testing.expectEqual(2, map.get(1) orelse 0);
    const removed = map.remove(1) orelse 0;
    try std.testing.expectEqual(2, removed);
    try std.testing.expectEqual(0, map.get(1) orelse 0);
}

test "benchmark put" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const iterations = 100_000_000;
    const map = try FdMap.init(allocator, iterations);
    defer map.deinit();
    var i: i32 = 0;
    var timer = try std.time.Timer.start();
    while (i < iterations) : (i += 1) {
        try map.put(i, 1);
    }
    const elapsed = timer.lap();
    const avg_ns = @divFloor(elapsed, iterations);
    std.debug.print("Average time: {d}ns\n", .{avg_ns});
}
```
```
[2024-12-31T22:08:39.714Z] Running test: fdmap.zig - benchmark put
Command failed: /Applications/zig-macos-aarch64-0.14.0-dev.2384+cbc05e0b1/zig test --test-filter benchmark put /Users/joey/peregrine/src/fdmap.zig
1/1 fdmap.test.benchmark put...FAIL (MapFull)
/Users/joey/peregrine/src/fdmap.zig:71:9: 0x100eb4f87 in put (test)
        return error.MapFull;
        ^
/Users/joey/peregrine/src/fdmap.zig:138:9: 0x100eb58eb in test.benchmark put (test)
        try map.put(i, 1);
        ^
0 passed; 0 skipped; 1 failed.
error: the following test command failed with exit code 1:
/Users/joey/.cache/zig/o/49534da1a301810292d9c4407a3b5011/test --seed=0xf921a199
```
Oh dear, the map filled up... There should have been enough space in the map, because we use the number of iterations as the map size.
We need a better hash function.

### Better hash function
```zig
fn hash(d: u32, fd: u32) u32 {
    var h: u32 = if (d == 0) 0x01000193 else d;
    h = (h *% 0x01000193) ^ fd;
    return h;
}
```
This is FNV-1a, and has excellent distribution properties with integers. It's also a fast for small inputs, due to it's simple instructions.
The `*%` operator simply ensures that the multiplication wraps-around in case of overflow.

### Benchmark again...
Our implementation manages 100M puts in just a couple of seconds, averaging 130ns on my machine. That's a nice improvement from 452ns.

I'm sure we can do better than that, though. What's wrong?

### Powers of two
After watching [this video](https://www.youtube.com/watch?v=DMQ_HcNSOAI), I learned that sizing tables to powers of two can yeild improved performance. Let's try.

```zig
fn nextPowerOf2(value: usize) usize {
    var v = value -% 1;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    return v +% 1;
}
```

Now, let's modify our init function to ensure that the array size is a power of two...
```zig
pub fn init(allocator: std.mem.Allocator, max_fds: usize) !*@This() {
    const self = try allocator.create(@This());
    const nextPow2 = nextPowerOf2(max_fds);
    self.* = .{
        .allocator = allocator,
        .values = try allocator.alloc(u32, nextPow2),
        .g = try allocator.alloc(u32, nextPow2),
    };
    @memset(self.values, 0);
    @memset(self.g, 0);
    return self;
}
```

Ensuring that the array sizes were powers of two reduced the benchmark down to 9ns. That's much more like it!

### Inlining the hash function
We can also inline the function to reduce function call overhead. For a small, frequently called function like a hash calculation, we can save several CPU cycles per call, which becomes significant when the function is called millions of times. In addition, when inlined, the CPU can better predict branches, and register allocation becomes more efficient.

```zig
inline fn hash(d: u32, fd: u32) u32 {
    const prime: u32 = 0x01000193;
    return (if (d == 0) prime else d) *% prime ^ fd;
}
```

This gives us an extra nanosecond. From 452ns down to 8ns per put operation. So that's how I made a really fast hash map for storing file descriptors. You can see the final implementation [here](https://github.com/intob/peregrine/blob/main/src/fdmap.zig).
