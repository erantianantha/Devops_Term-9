# Task 1 — IP addressing and subnetting

Worked by hand and then checked with [`subnet-practice.sh`](subnet-practice.sh), which I wrote for
this task. Its output is in [`output/raw-subnet.txt`](output/raw-subnet.txt).

## What an IPv4 address is

32 bits. The dotted-decimal form is a convenience for humans — four groups of 8 bits written as
numbers 0–255. My own machine's address, in both forms:

```
100.128.174.94   =   01100100.10000000.10101110.01011110
```

Those 32 bits are split into a **network part** and a **host part**. Every device on one network
shares the network part and has a unique host part. What decides where the split falls is the
**subnet mask**, and nothing else — the address alone cannot tell you.

## Classes

The original scheme fixed the split at an octet boundary based on the first octet:

| Class | First octet | Default mask | Networks | Hosts per network |
|---|---|---|---|---|
| A | 1–126 | 255.0.0.0 (/8) | 126 | 16,777,214 |
| B | 128–191 | 255.255.0.0 (/16) | 16,384 | 65,534 |
| C | 192–223 | 255.255.255.0 (/24) | 2,097,152 | 254 |
| D | 224–239 | — | multicast, no host split | — |
| E | 240–255 | — | reserved / experimental | — |

**Why class A is 1–126 and not 1–127:** `127.0.0.0/8` is reserved for loopback. `127.0.0.1` is the
famous one, but the whole /8 is reserved — `127.9.9.9` also loops back. So the class A range stops
at 126. `0.0.0.0/8` is reserved too, which is why it starts at 1.

Classes are effectively history. Since CIDR (1993) the mask is carried with the address and the
split can fall anywhere. They still matter for two reasons: interview questions, and some equipment
still assumes a "classful" default mask when you leave it blank.

## Masks and CIDR

The mask is 32 bits of "ones then zeroes". A `1` marks a network bit, a `0` marks a host bit, and
the ones must be contiguous. `/24` is just shorthand for "24 ones":

```
255.255.255.0  =  11111111.11111111.11111111.00000000  =  /24
255.255.240.0  =  11111111.11111111.11110000.00000000  =  /20
```

| CIDR | Mask | Total addresses | Usable hosts |
|---|---|---|---|
| /8 | 255.0.0.0 | 16,777,216 | 16,777,214 |
| /16 | 255.255.0.0 | 65,536 | 65,534 |
| /20 | 255.255.240.0 | 4,096 | 4,094 |
| /24 | 255.255.255.0 | 256 | 254 |
| /26 | 255.255.255.192 | 64 | 62 |
| /30 | 255.255.255.252 | 4 | 2 |
| /31 | 255.255.255.254 | 2 | **2** |
| /32 | 255.255.255.255 | 1 | **1** |

## Counting hosts

```
total addresses = 2^(32 - prefix)
usable hosts    = 2^(32 - prefix) - 2
```

The two that are subtracted are:

- **the network address** — all host bits `0`. It names the network itself and cannot be assigned.
- **the broadcast address** — all host bits `1`. Anything sent to it goes to every host on the
  network, so it cannot belong to one.

**The two exceptions**, both of which my script handles:

- **/31** — 2 usable, not 0. RFC 3021: on a point-to-point link there are exactly two ends and
  nothing to broadcast to, so both addresses are usable. Router-to-router links use these.
- **/32** — 1 usable. A single host route. Loopback interfaces and per-host firewall rules use
  them.

## Worked examples

### `192.168.1.100/26`

By hand first. /26 means 26 network bits, so the mask is `255.255.255.192`, because the fourth
octet is `11000000` = 192. Host bits: 32 − 26 = 6, so blocks are 2⁶ = 64 addresses wide, starting
at 0, 64, 128, 192.

`.100` falls in the 64–127 block:

```
network   192.168.1.64
first     192.168.1.65
last      192.168.1.126
broadcast 192.168.1.127
usable    62
```

Checked with the script:

```
  192.168.1.100/26
  address                192.168.1.100      11000000.10101000.00000001.01100100
  subnet mask            255.255.255.192    11111111.11111111.11111111.11000000
  network address        192.168.1.64       11000000.10101000.00000001.01000000
  broadcast              192.168.1.127      11000000.10101000.00000001.01111111
  usable hosts           62   = 2^(32-26) - 2 = 64 - 2
  host range             192.168.1.65  ->  192.168.1.126
```

The binary column is the part that makes it obvious rather than memorised: the network address is
the address with every host bit forced to 0, and the broadcast is the same address with every host
bit forced to 1. That is all the arithmetic there is.

### `203.0.113.9/30`

Host bits: 2, so 4 addresses per block, and `.9` is in the 8–11 block.

```
network 203.0.113.8, hosts .9 and .10, broadcast 203.0.113.11, usable 2
```

/30 is the classic point-to-point allocation — 4 addresses to connect two routers, which is why
/31 was invented.

## My own network, checked against the routing table

This is the part that was worth doing. `ipconfig` says:

```
IPv4 Address. . . . : 100.128.174.94
Subnet Mask . . . . : 255.255.240.0
Default Gateway . . : 100.128.160.1
```

`255.255.240.0` is /20, so the script says:

```
  network address        100.128.160.0
  broadcast              100.128.175.255
  host range             100.128.160.1  ->  100.128.175.254
  usable hosts           4094
```

And Windows' own routing table, from [`output/raw-routing.txt`](output/raw-routing.txt), agrees:

```
Network Destination        Netmask          Gateway       Interface
    100.128.160.0    255.255.240.0         On-link    100.128.174.94
  100.128.175.255  255.255.255.255         On-link    100.128.174.94
```

Line 1 is the network address my arithmetic produced. Line 2 is the broadcast address, which
Windows installs as its own /32 route. Two numbers I calculated from first principles, sitting in
the operating system's route table. That is the check the task is really asking for.

## Private ranges, and one that looks private and is not

| Range | CIDR | RFC | What it is |
|---|---|---|---|
| 10.0.0.0 – 10.255.255.255 | 10.0.0.0/8 | 1918 | private |
| 172.16.0.0 – 172.31.255.255 | 172.16.0.0/12 | 1918 | private |
| 192.168.0.0 – 192.168.255.255 | 192.168.0.0/16 | 1918 | private |
| 127.0.0.0 – 127.255.255.255 | 127.0.0.0/8 | 1122 | loopback |
| 169.254.0.0 – 169.254.255.255 | 169.254.0.0/16 | 3927 | link-local (APIPA) |
| 100.64.0.0 – 100.127.255.255 | 100.64.0.0/10 | 6598 | carrier-grade NAT |

Two traps in that table:

- **172.16.0.0/12 stops at 172.31.**, not 172.255. `172.32.5.5` is a public address. This is the
  one people get wrong, and it is why my script does a range comparison for that block instead of a
  prefix match on the string.
- **`100.x` is not automatically CGNAT.** My own address is `100.128.174.94`, which *looks* like
  RFC 6598 shared space — but that range ends at `100.127.255.255`, and mine is one step past it.
  `100.128.0.0` onwards is ordinary public space. My script prints `public` for it, and I only
  believed that after checking the boundary by hand.
- **169.254.x.x means DHCP failed.** Seeing it is a diagnosis, not a configuration.

## Errors to watch for in worked examples

Two things I check whenever I read a subnetting example, because both are common:

1. **Class against first octet.** An example that calls `172.16.x.x` "class C" is wrong — 172 is in
   128–191, so it is class B. Being private has nothing to do with class.
2. **Host count off by two.** `2^(32-prefix)` is the total; the usable count is two fewer, except
   for /31 and /32.
