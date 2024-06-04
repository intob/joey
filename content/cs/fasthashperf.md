---
title: Comparing the performance of non-cryptographic hash functions
description: I benchmarked some fast hash functions in Go...
date: 2024-05-19
---
In order to speed up a UDP packet filter, I benchmarked some fast hash functions to find the fastest. I compared two implementations of Murmur3, and FNV from the Go standard library.

Before getting to it, I was particularly surprised by how much faster the uint64 variants were than their byte slice counterparts. This goes to show how much we can benefit from 64-bit registers in modern CPUs, by avoiding byte slices where possible.

As I did not want to spend a whole evening benchmarking, I limited this study to 64-bit hashes. If in future I encounter a use-case to compare other bit widths, I'll extend the repository and update this article.

# Results
The following results are from a 12-core Apple M2 Pro.
```
# key: Benchmark_<HASH_FN>_<HASH_LEN>_l<INPUT_LEN>
goos: darwin
goarch: arm64
pkg: github.com/intob/fasthashperf
Benchmark_murmur3twmb_64_l16-12                         47093220                24.60 ns/op
Benchmark_murmur3spaolacci_64_l16-12                    48799498                25.15 ns/op
Benchmark_fnva_64_l16-12                                50898858                23.64 ns/op
Benchmark_fnv_64_l16-12                                 51845462                23.63 ns/op
Benchmark_murmur3twmb_64_l32-12                         46655617                26.40 ns/op
Benchmark_murmur3spaolacci_64_l32-12                    45743836                27.00 ns/op
Benchmark_fnva_64_l32-12                                34505275                35.93 ns/op
Benchmark_fnv_64_l32-12                                 33381009                36.11 ns/op
Benchmark_murmur3twmb_64_l512-12                        11900127                98.44 ns/op
Benchmark_murmur3spaolacci_64_l512-12                   11690503               103.5 ns/op
Benchmark_fnva_64_l512-12                                1795224               672.7 ns/op
Benchmark_fnv_64_l512-12                                 1791697               669.6 ns/op
Benchmark_uint64_murmur3twmb_64_l16-12                  100000000               10.59 ns/op
Benchmark_uint64_murmur3spaolacci_64_l16-12             100000000               11.08 ns/op
Benchmark_uint64_fnva_64_l16-12                         129080316                9.248 ns/op
Benchmark_uint64_fnv_64_l16-12                          128857820                9.351 ns/op
Benchmark_uint64_murmur3twmb_64_l32-12                  98238195                12.30 ns/op
Benchmark_uint64_murmur3spaolacci_64_l32-12             93423382                12.87 ns/op
Benchmark_uint64_fnva_64_l32-12                         60410413                20.31 ns/op
Benchmark_uint64_fnv_64_l32-12                          59049549                20.77 ns/op
Benchmark_uint64_murmur3twmb_64_l512-12                 13842320                88.53 ns/op
Benchmark_uint64_murmur3spaolacci_64_l512-12            12947748                93.31 ns/op
Benchmark_uint64_fnva_64_l512-12                         1835164               656.7 ns/op
Benchmark_uint64_fnv_64_l512-12                          1779769               671.2 ns/op
PASS
ok      github.com/intob/fasthashperf   34.274s
```

# Findings

## FNV vs FNVa
There seems to be little difference when comparing the performance of FNV and FNVa for byte slices, although FNVa seems to have the edge for 64-bit arithmetic.

## Murmur3 vs FNV(a)
Murmur3 is significantly faster than FNV(a) for all input lengths over 16 bytes, with the difference becoming more pronounced with increased input length. For input lengths of 16 bytes or less, FNV(a) seems to be slightly faster.

## github.com/spaolacci/murmur3 vs github.com/twmb/murmur3
The implementation from github.com/twmb is slightly faster on all counts. Thanks to both for their implementations.

# Repository
https://github.com/intob/fasthashperf
