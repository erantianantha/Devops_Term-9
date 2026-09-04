# Networking fundamentals

**Name:** Anantha  **Enrollment Number:** _(fill in)_  **Date:** 4 September 2026

Two tasks: IP addressing and subnetting on paper, then the networking commands run for real on this
machine.

| Task | Write-up |
|---|---|
| 1 | [task1-ip-addressing.md](task1-ip-addressing.md) — classes, masks, CIDR, host counts, private ranges |
| 2 | [task2-networking-commands.md](task2-networking-commands.md) — ten commands, real output, what each one told me |

```
networking fundamentals/
├── README.md
├── task1-ip-addressing.md
├── task2-networking-commands.md
├── subnet-practice.sh          a subnet calculator, written for task 1
└── output/
    ├── raw-identity.txt        hostname, ipconfig
    ├── raw-ping.txt            three pings: an IP, a name, the gateway
    ├── raw-tracert.txt         a full traceroute
    ├── raw-dns.txt             A, MX, NS and a reverse lookup
    ├── raw-http.txt            curl headers and a timing breakdown
    ├── raw-sockets.txt         netstat, listening and established
    ├── raw-routing.txt         route print and arp
    └── raw-subnet.txt          the calculator's own output
```

## Task 1 in short

An IPv4 address is 32 bits, split into a network part and a host part. **The mask decides where the
split falls** — the address on its own cannot tell you. Classes (A/B/C by first octet) fixed that
split at an octet boundary; CIDR replaced them by carrying the prefix length with the address.

```
usable hosts = 2^(32 - prefix) - 2
```

The two subtracted are the network address (all host bits 0) and the broadcast (all host bits 1).
The exceptions are **/31**, where both addresses are usable on a point-to-point link (RFC 3021),
and **/32**, a single host route.

## The calculator

```bash
bash subnet-practice.sh 192.168.1.100/26
bash subnet-practice.sh 10.0.0.5 255.255.255.0     # mask form works too
bash subnet-practice.sh                            # the worked examples
```

```
  192.168.1.100/26
  address                192.168.1.100      11000000.10101000.00000001.01100100
  subnet mask            255.255.255.192    11111111.11111111.11111111.11000000
  network address        192.168.1.64       11000000.10101000.00000001.01000000
  broadcast              192.168.1.127      11000000.10101000.00000001.01111111
  usable hosts           62   = 2^(32-26) - 2 = 64 - 2
  host range             192.168.1.65  ->  192.168.1.126
  class (by 1st octet)   C
  scope                  private  (RFC 1918, 192.168.0.0/16)
```

It works on a single 32-bit integer rather than octet by octet, which is what an address actually
is and what makes every operation one line: the network address is `ip & mask`, the broadcast is
`net | ~mask`, and the binary column makes both obvious rather than memorised.

## Task 2 in short

Ten commands, run on Windows 11: `hostname`, `ipconfig`, `ping`, `tracert`, `nslookup`, `curl`,
`netstat`, `route print`, `arp`, and a port check. The write-up has the output and what each one
established.

## The bit that made the two tasks meet

`ipconfig` reports `100.128.174.94 / 255.255.240.0`. That is a /20, so by hand the network address
is `100.128.160.0` and the broadcast is `100.128.175.255`. Windows' own routing table:

```
    100.128.160.0    255.255.240.0         On-link    100.128.174.94
  100.128.175.255  255.255.255.255         On-link    100.128.174.94
```

Both numbers, calculated from the mask, sitting in the operating system's route table. That check
is what turned Task 1 from an exercise into something I believe.

## Three findings

1. **TTL in a ping reply is a free hop count.** The gateway answers with TTL 64 (it started at 64,
   zero hops); Google answers with 120 (started at 128, so ~8 hops).
2. **A row of stars in `tracert` is usually not a failure.** Hops 9–12 time out here while the
   destination is perfectly reachable — those routers simply do not reply to expired TTLs.
3. **`100.128.x.x` is not CGNAT.** RFC 6598 shared space is `100.64.0.0/10`, which ends at
   `100.127.255.255`. My address is one octet past it and is ordinary public space. The calculator
   gets this right because it compares ranges rather than matching on `100.`.

## A note on what is in `output/`

These captures contain the local IP range, the gateway, the DNS server's name and the addresses of
other devices on the same Wi-Fi. **MAC addresses have been replaced** with `xx-xx-xx-xx-xx-xx`
before committing:

```bash
sed -i -E 's/([0-9a-f]{2}-){5}[0-9a-f]{2}/xx-xx-xx-xx-xx-xx/gI' output/raw-routing.txt
```

An `arp -a` table is a list of the hardware addresses of everything on the network you are sitting
on, and it does not belong in a public repository.
