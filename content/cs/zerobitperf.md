---
title: Comparing performance of de Bruijn sequence against a lookup table
description: "Precomputed de Bruijn sequences are cool, but are they faster than simple lookup tables?"
date: 2024-05-17
---
While optimising the naive proof-of-work algorithm in my dave protocol implementation, I compared the efficiency of some methods of counting the number of leading zero bits in a byte slice.

# Approaches

## 1. Naive approach
```go
func nzerobit_1(key []byte) int {
    var count int
    for _, b := range key {
        for i := 0; i < 8; i++ {
            if b&(1<<i) == 0 {
                count++
            } else {
                return count
            }
        }
    }
    return count
}
```
Iterating over each byte in the given key, we use the bitwise AND operator `&` to check if the `i`-th bit of the byte is zero. The expression `1<<i` creates a bitmask with only the `i`-th bit set to 1, and the `&` operator performs a bitwise AND operation between the byte and the bitmask. If the result is zero, it means that the `i`-th bit is zero, and we increment the count. If the bit is set, we return the current value of count.

## 2. Right shift
```go
func nzerobit_2(key []byte) int {
    var count int
    for _, b := range key {
        for i := 0; i < 8; i++ {
            if (b>>i)&1 == 0 {
                count++
            } else {
                return count
            }
        }
    }
    return count
}
```
Instead of using `b&(1<<i) == 0`, we can use `(b>>i)&1 == 0`, avoiding the expensive left shift operation. This should yeild a small performance improvement.

## 3. Unroll loop
```go
func nzerobit_3(key []byte) int {
    var count int
    for _, b := range key {
        if (b>>0)&1 == 0 { count++ } else { return count }
        if (b>>1)&1 == 0 { count++ } else { return count }
        if (b>>2)&1 == 0 { count++ } else { return count }
        if (b>>3)&1 == 0 { count++ } else { return count }
        if (b>>4)&1 == 0 { count++ } else { return count }
        if (b>>5)&1 == 0 { count++ } else { return count }
        if (b>>6)&1 == 0 { count++ } else { return count }
        if (b>>7)&1 == 0 { count++ } else { return count }
    }
    return count
}
```
Loops are expensive. Loop unrolling can help reduce loop overhead, and enable better instruction-level parallelism.

## 4. Simple lookup table
We can create a lookup table storing the number of leading zero bits for every possible byte value.
```go
var zeros = [256]int{
    8, 7, 6, 6, 5, 5, 5, 5, 4, 4, 4, 4, 4, 4, 4, 4,
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
}

func nzerobit_4(key []byte) int {
    var count int
    for _, b := range key {
        count += zeros[b]
        if b != 0 {
            return count
        }
    }
    return count
}
```
While simple, this approach can be significantly faster for small input sizes. As my use case is counting the number of leading zero bits in a 256 bit hash, this method could yeild great results.

## 5. De Bruijn sequence
```go
var debruijn64 = [64]byte{
    0, 1, 2, 53, 3, 7, 54, 27, 4, 38, 41, 8, 34,
    55, 48, 28, 62, 5, 39, 46, 44, 42, 22, 9, 24,
    35, 59, 56, 49, 18, 29, 11, 63, 52, 6, 26,
    37, 40, 33, 47, 61, 45, 43, 21, 23, 58, 17,
    10, 51, 25, 36, 32, 60, 20, 57, 16, 50, 31,
    19, 15, 30, 14, 13, 12,
}

func nzerobit_5(key []byte) int {
    for i, b := range key {
        if b != 0 {
            x := uint64(b&-b)*0x03f79d71b4ca8b09>>58
            return i*8 + int(debruijn64[x])
        }
    }
    return len(key) * 8
}
```
The debruijn64 array is a precomputed lookup table that maps the position of the least significant set bit in a byte to the number of trailing zeros.

`i*8` gives the number of zero bits in the previous bytes. `b&-b` isolates the least significant set bit in the current byte. `uint64(b&-b)*0x03f79d71b4ca8b09` multiplies the isolated bit with a magic constant to generate a unique index into the table. `>>58` shifts the result to the right by 58 bits to bring the relevant bits into the least significant position. The looked-up value represents the number of trailing zeros in the current byte, which is added to `i*8` to get the total number of leading zero bits.

The de Bruijn sequence lookup table provides a constant-time method to determine the number of trailing zeros in a byte. By combining this with the byte index, the function efficiently calculates the total number of leading zero bits in the byte slice.

# Benchmarks
The following results are from a 12-core Apple M2 Pro.

The simple lookup and de Bruijn sequence are the clear winners, regardless of byte length and number of leading zero bytes. As there is no clear winner between these two, I suggest running tests for your specific use case.

## 16 bytes, 4 leading zero bytes
```
Benchmark_1-12    	53595952	        22.68 ns/op
Benchmark_2-12    	54691712	        22.68 ns/op
Benchmark_3-12    	76803686	        15.74 ns/op
Benchmark_4-12    	421736720	         2.861 ns/op
Benchmark_5-12    	423180349	         2.864 ns/op
```

## 32 bytes, 2 leading zero bytes
```
Benchmark_1-12    	80881609	        14.65 ns/op
Benchmark_2-12    	86697114	        13.87 ns/op
Benchmark_3-12    	100000000	        11.22 ns/op
Benchmark_4-12    	577513431	         2.087 ns/op
Benchmark_5-12    	570226458	         2.076 ns/op
```

## 32 bytes, 4 leading zero bytes
```
Benchmark_1-12    	49990105	        23.07 ns/op
Benchmark_2-12    	54375429	        21.99 ns/op
Benchmark_3-12    	76524105	        15.73 ns/op
Benchmark_4-12    	413261740	         2.862 ns/op
Benchmark_5-12    	403608087	         2.912 ns/op
```

## 32 bytes, 8 leading zero bytes
```
Benchmark_1-12    	34218296	        35.23 ns/op
Benchmark_2-12    	35122378	        34.62 ns/op
Benchmark_3-12    	62954121	        19.30 ns/op
Benchmark_4-12    	315074923	         3.810 ns/op
Benchmark_5-12    	315627609	         3.805 ns/op
```

## 64 bytes, 4 leading zero bytes
```
Benchmark_1-12    	50546887	        23.29 ns/op
Benchmark_2-12    	51958827	        22.18 ns/op
Benchmark_3-12    	73563591	        15.65 ns/op
Benchmark_4-12    	401217024	         3.052 ns/op
Benchmark_5-12    	386922139	         3.040 ns/op
```

## 128 bytes, 4 leading zero bytes
```
Benchmark_1-12    	53089023	        22.98 ns/op
Benchmark_2-12    	53183925	        22.37 ns/op
Benchmark_3-12    	74646594	        16.12 ns/op
Benchmark_4-12    	142048627	         8.512 ns/op
Benchmark_5-12    	142594008	         8.442 ns/op
```

## 256 bytes, 4 leading zero bytes
```
Benchmark_1-12    	51616419	        23.62 ns/op
Benchmark_2-12    	53396121	        22.98 ns/op
Benchmark_3-12    	57543146	        18.51 ns/op
Benchmark_4-12    	100000000	        10.83 ns/op
Benchmark_5-12    	100000000	        10.89 ns/op
```

## 256 bytes, 64 leading zero bytes
```
Benchmark_1-12    	 5252018	       231.0 ns/op
Benchmark_2-12    	 5165072	       231.0 ns/op
Benchmark_3-12    	12656263	        97.03 ns/op
Benchmark_4-12    	57885492	        20.43 ns/op
Benchmark_5-12    	58068614	        20.46 ns/op
```

# Repo
https://github.com/intob/zerobitperf