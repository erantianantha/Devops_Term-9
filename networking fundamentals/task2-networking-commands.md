# Task 2 — networking commands

Every block below is real output from this machine (Windows 11, Git Bash). Raw captures are in
[`output/`](output/); MAC addresses have been replaced with `xx-xx-xx-xx-xx-xx` before committing.

## 1. `hostname`

```
$ hostname
anantha
```

The name this machine answers to on the local network. It comes from the OS configuration, not from
DNS, and changing it does not change what a DNS server says about you.

## 2. `ipconfig` (`ip a` on Linux)

```
Wireless LAN adapter Wi-Fi:
   Link-local IPv6 Address . . . . . : fe80::f8fb:c41:e0d4:3823%6
   IPv4 Address. . . . . . . . . . . : 100.128.174.94
   Subnet Mask . . . . . . . . . . . : 255.255.240.0
   Default Gateway . . . . . . . . . : 100.128.160.1

Ethernet adapter Ethernet:
   Media State . . . . . . . . . . . : Media disconnected
```

Five adapters are listed and only one is carrying traffic. **"Media disconnected" is the first
thing to look for** — a machine with six adapters and no address on any of them looks broken in a
dozen ways, and the actual fault is one line.

The `%6` on the IPv6 address is a zone index. Link-local addresses are only unique per interface,
so the interface number is part of the address.

`255.255.240.0` is /20, which is worked through in Task 1 and matches the routing table.

## 3. `ping`

```
$ ping -n 4 8.8.8.8
Reply from 8.8.8.8: bytes=32 time=18ms TTL=120
Reply from 8.8.8.8: bytes=32 time=35ms TTL=120
Reply from 8.8.8.8: bytes=32 time=35ms TTL=120
Reply from 8.8.8.8: bytes=32 time=18ms TTL=120

Ping statistics for 8.8.8.8:
    Packets: Sent = 4, Received = 4, Lost = 0 (0% loss),
    Minimum = 18ms, Maximum = 35ms, Average = 26ms
```

```
$ ping -n 3 100.128.160.1          # the default gateway
Reply from 100.128.160.1: bytes=32 time=78ms TTL=64
Reply from 100.128.160.1: bytes=32 time=2ms TTL=64
Reply from 100.128.160.1: bytes=32 time=5ms TTL=64
```

**TTL tells you roughly how far away the answer came from.** It starts at 64, 128 or 255 and each
router decrements it. The gateway replies with 64 — it *is* 64, so zero hops. Google replies with
120, which started at 128, so about 8 routers in between. That number is free information in every
reply.

**The gateway ping is the diagnostic one.** 2–5ms is a healthy local link; the 78ms first packet is
the Wi-Fi radio waking up, and it is normal to discard the first sample.

**Ping an IP first, then a name.** If `ping 8.8.8.8` works and `ping google.com` does not, routing
is fine and DNS is broken. That single comparison narrows the problem more than any other command
here.

```
$ ping -n 4 google.com
Pinging google.com [192.178.211.102] with 32 bytes of data:
Reply from 192.178.211.102: bytes=32 time=19ms TTL=109
    Minimum = 15ms, Maximum = 125ms, Average = 47ms
```

Both work here, so both layers are healthy. The 125ms outlier against a 15ms minimum is Wi-Fi, not
the far end.

## 4. `tracert` (`traceroute` on Linux)

```
$ tracert -d -h 12 google.com
Tracing route to google.com [192.178.211.102] over a maximum of 12 hops:

  1     6 ms     3 ms     5 ms  100.128.160.1        <- my gateway
  2    14 ms    15 ms    45 ms  114.79.130.29        <- the ISP
  3    14 ms    29 ms    15 ms  72.14.208.165        <- into Google's network
  4     *       61 ms   172 ms  192.178.84.175
  5    67 ms     *       96 ms  142.250.213.100
  6    53 ms    22 ms    75 ms  192.178.254.235
  7    21 ms    43 ms    20 ms  142.251.224.133
  8    34 ms    18 ms    16 ms  192.178.254.121
  9     *        *        *     Request timed out.
 10     *        *        *     Request timed out.
```

**How it works:** it sends packets with TTL=1, then 2, then 3. Each router that decrements a TTL to
zero must send back "time exceeded", and that reply reveals the router's address. It is a clever
use of an error message, not a feature anyone designed for this.

**A row of stars is usually not a failure.** Hops 9–12 time out but hop 8 answered and the
destination is reachable — those routers are configured not to reply to expired TTLs, which is a
common policy. A real failure looks different: stars from hop N to the end, with the destination
also unreachable.

**`-d` skips reverse DNS**, which turns a 30-second trace into a 5-second one.

Latency does not increase monotonically (hop 4 shows 172ms, hop 7 shows 20ms). ICMP replies are the
lowest-priority work a router does, so a slow-looking middle hop rarely means anything.

## 5. `nslookup`

```
$ nslookup google.com
Server:  wifi.height8tech.com
Address:  100.128.160.1

Name:    google.com
Addresses:  2404:6800:4000:1025::65
          192.178.211.138
          192.178.211.102
          ... (10 addresses in total)
```

The `Server:` block is which resolver answered — here, the gateway itself, which is the router
doing DNS for the LAN. Ten addresses for one name is round-robin load balancing at the DNS layer,
and it is why two machines can legitimately reach different Google servers.

```
$ nslookup -type=MX gmail.com
gmail.com  MX preference = 5,  mail exchanger = gmail-smtp-in.l.google.com
gmail.com  MX preference = 10, mail exchanger = alt1.gmail-smtp-in.l.google.com
gmail.com  MX preference = 20, mail exchanger = alt2.gmail-smtp-in.l.google.com
```

MX records route mail. **Lower preference wins** — 5 is tried before 10 — which reads backwards
until you think of it as a cost rather than a priority.

```
$ nslookup -type=NS wikipedia.org      # which servers are authoritative
$ nslookup 8.8.8.8                     # reverse: address -> name
```

A reverse lookup uses the `in-addr.arpa` tree and is a completely separate record from the forward
one. Forward and reverse disagreeing is normal, not an error.

## 6. `curl`

```
$ curl -I https://example.com
HTTP/1.1 200 OK
Date: Fri, 04 Sep 2026 17:46:39 GMT
Content-Type: text/html
Server: cloudflare
cf-cache-status: HIT
CF-RAY: a35ed09ea8f83ab3-BOM
```

`-I` asks for headers only (a HEAD request), which is the fastest possible "is this thing up".
`Server: cloudflare` and `cf-cache-status: HIT` say I never reached the origin server — a CDN edge
answered from cache. `-BOM` in the ray ID is the Mumbai edge, which explains the latency.

The timing breakdown is the part of curl worth knowing:

```
$ curl -s -o /dev/null -w '...' https://www.wikipedia.org
dns_lookup:   0.181256s
tcp_connect:  0.253964s
tls_done:     0.814917s
first_byte:   0.906310s
total:        1.123379s
http_code:    200
remote_ip:    103.102.166.224
```

Those numbers are cumulative, so the phases are: DNS 181ms, TCP handshake 73ms, **TLS 561ms**,
server thinking 91ms, download 217ms. The TLS handshake is half the page load. Being able to point
at that number is the difference between "the site is slow" and something to fix.

```
$ curl -sS --max-time 5 http://127.0.0.1:9
curl: (7) Failed to connect to 127.0.0.1 port 9 after 2043 ms: Could not connect to server
```

**Error 7 is refused; a timeout is a different failure.** Refused means something answered "no" —
the host is up and nothing is listening on that port. A timeout means nothing answered at all,
which points at a firewall or a wrong address. Two different causes, and curl distinguishes them.

## 7. `netstat`

```
$ netstat -an | grep LISTENING | head
  TCP    0.0.0.0:80             0.0.0.0:0              LISTENING
  TCP    0.0.0.0:135            0.0.0.0:0              LISTENING
  TCP    0.0.0.0:445            0.0.0.0:0              LISTENING
  TCP    0.0.0.0:5000           0.0.0.0:0              LISTENING
  TCP    0.0.0.0:8085           0.0.0.0:0              LISTENING
  TCP    0.0.0.0:8090           0.0.0.0:0              LISTENING

$ netstat -an | grep ESTABLISHED | head -3
  TCP    100.128.174.94:49311   104.26.6.150:443       ESTABLISHED
  TCP    100.128.174.94:49363   40.79.167.9:443        ESTABLISHED
```

**LISTENING** is a server waiting for connections. **ESTABLISHED** is a live conversation with a
specific remote address.

`0.0.0.0:80` means "port 80 on every interface" — the same `0.0.0.0` versus `127.0.0.1` distinction
that decides whether a container is reachable, seen here from the host side.

The high local port numbers (49311, 49363) are **ephemeral ports**: the OS allocates one per
outgoing connection, which is what lets one machine hold hundreds of connections to port 443.

To find which process owns a port: `netstat -ano` adds a PID column, then
`tasklist /FI "PID eq <n>"` names it. On Linux it is one command, `ss -tlnp`.

## 8. Routing table

```
$ route print -4
Network Destination        Netmask          Gateway       Interface  Metric
          0.0.0.0          0.0.0.0    100.128.160.1   100.128.174.94     35
    100.128.160.0    255.255.240.0         On-link    100.128.174.94    291
   100.128.174.94  255.255.255.255         On-link    100.128.174.94    291
  100.128.175.255  255.255.255.255         On-link    100.128.174.94    291
        127.0.0.0        255.0.0.0         On-link         127.0.0.1    331
     172.24.160.0    255.255.240.0         On-link      172.24.160.1   5256
```

Line by line:

- `0.0.0.0/0` is the **default route**: anything not matched by a more specific line goes to
  `100.128.160.1`. A /0 matches everything, so it is always the least specific match.
- `100.128.160.0/20` is my own subnet, **On-link** — reachable directly, no router involved.
  **That is the network address calculated in Task 1.**
- `100.128.175.255/32` is the broadcast address for that subnet, also from Task 1.
- `172.24.160.0/20` is WSL2's virtual network, where Docker's Linux containers live. It is in a
  Windows routing table because Docker Desktop put it there.

Routing is **longest prefix wins**: a /32 beats a /20 beats a /0. `Metric` only breaks ties between
routes of equal prefix length.

## 9. `arp -a`

```
Interface: 100.128.174.94 --- 0x6
  Internet Address      Physical Address      Type
  100.128.160.1         xx-xx-xx-xx-xx-xx     dynamic
  100.128.160.72        xx-xx-xx-xx-xx-xx     dynamic
  100.128.160.96        xx-xx-xx-xx-xx-xx     dynamic
  100.128.160.99        xx-xx-xx-xx-xx-xx     dynamic
```

ARP maps an **IP address to a MAC address**. Ethernet frames are addressed by MAC, so before
sending to a local IP the machine has to ask "who has 100.128.160.1?" and cache the answer.

The entries I do not recognise are other devices on the same Wi-Fi that this machine has exchanged
frames with. **ARP only ever sees the local subnet** — anything past the gateway never appears,
because those packets are addressed to the gateway's MAC, not the destination's.

The MACs are masked in the committed capture. An ARP table is a list of the hardware addresses of
every device on the network you are sitting on, which is not something to publish.

## 10. Port checks

```
$ curl -sI -m 5 https://example.com          # 200 -> 443 open and serving
$ curl -sS -m 5 http://127.0.0.1:9           # curl: (7) refused -> nothing listening
$ netstat -an | grep ':8090'                 # confirm from the other side
  TCP    0.0.0.0:8090           0.0.0.0:0              LISTENING
```

Two commands from two directions is what makes it a confirmation. `netstat` says a process is
bound; curl says a connection actually completes. They can disagree — a process bound to
`127.0.0.1` appears in `netstat` and refuses every connection from elsewhere, which is a
five-minute mystery if you only ran one of the two.

On Windows, `Test-NetConnection -ComputerName host -Port 443` does the same job in one command.

## Troubleshooting order

1. **`ipconfig`** — is there an address at all? `169.254.x.x` means DHCP failed, and nothing else
   matters until that is fixed.
2. **`ping <gateway>`** — is the local link up? Failure: cable, Wi-Fi, or the router.
3. **`ping 8.8.8.8`** — does routing off the LAN work? Failure: the router's upstream.
4. **`ping google.com`** — does DNS work? If only this fails, the resolver is the problem, not the
   network.
5. **`tracert`** — where does it stop? This tells you whose problem it is.
6. **`curl -I`** — is the service itself answering? A working network and a dead service look
   identical until this step.
7. **`netstat`** — locally, is anything actually bound to that port?

Each step assumes the ones above it passed, which is the whole value of keeping the order.

## Three things I only learned by running these

1. **TTL in a ping reply is a free hop count.** 64 from the gateway, 120 from Google, so about 8
   routers in between. Reading about ping would not have given me that.
2. **The network and broadcast addresses I calculated in Task 1 are literally in `route print`.**
   Subnet arithmetic stopped being an exercise at that point.
3. **`100.128.x.x` is not carrier-grade NAT**, even though it looks like it should be. RFC 6598
   shared space ends at `100.127.255.255`. One octet between "behind CGNAT" and "public address",
   and the only way to be sure was to check the boundary instead of trusting the pattern.
