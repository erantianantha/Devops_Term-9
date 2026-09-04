#!/usr/bin/env bash
#
# subnet-practice.sh — work out everything about an IPv4 address and prefix.
#
#   bash subnet-practice.sh 192.168.1.100/26
#   bash subnet-practice.sh 10.0.0.5 255.255.255.0
#   bash subnet-practice.sh                      # runs the built-in examples
#
# All arithmetic is done on a single 32-bit integer, because that is what an
# IPv4 address actually is. Working octet by octet is where subnetting gets
# confusing; converting once at the start and formatting once at the end makes
# every operation a one-liner.

set -u

# --- conversions -------------------------------------------------------------

to_int() {              # 192.168.1.100 -> 3232235876
    local IFS=. ; read -r a b c d <<< "$1"
    echo $(( (a << 24) + (b << 16) + (c << 8) + d ))
}

to_dotted() {           # 3232235876 -> 192.168.1.100
    local n=$1
    echo "$(( (n >> 24) & 255 )).$(( (n >> 16) & 255 )).$(( (n >> 8) & 255 )).$(( n & 255 ))"
}

to_binary() {           # 192.168.1.100 -> 11000000.10101000.00000001.01100100
    local n=$1 out="" i byte bits
    for i in 24 16 8 0; do
        byte=$(( (n >> i) & 255 )); bits=""
        for b in 128 64 32 16 8 4 2 1; do
            if [ $(( byte & b )) -ne 0 ]; then bits="${bits}1"; else bits="${bits}0"; fi
        done
        out="${out}${bits}."
    done
    echo "${out%.}"
}

mask_to_prefix() {      # 255.255.240.0 -> 20
    local n bits=0 i
    n=$(to_int "$1")
    for i in $(seq 31 -1 0); do
        if [ $(( (n >> i) & 1 )) -eq 1 ]; then bits=$((bits+1)); else break; fi
    done
    echo "$bits"
}

class_of() {            # by first octet, the pre-CIDR classification
    local first=$1
    if   [ "$first" -eq 0 ];                              then echo "reserved (this network)"
    elif [ "$first" -le 126 ];                            then echo "A"
    elif [ "$first" -eq 127 ];                            then echo "loopback (127.0.0.0/8)"
    elif [ "$first" -le 191 ];                            then echo "B"
    elif [ "$first" -le 223 ];                            then echo "C"
    elif [ "$first" -le 239 ];                            then echo "D (multicast)"
    else                                                       echo "E (experimental)"
    fi
}

scope_of() {            # RFC 1918, and the ones people forget
    local ip=$1 n=$2
    case "$ip" in
        10.*)         echo "private  (RFC 1918, 10.0.0.0/8)"; return ;;
        192.168.*)    echo "private  (RFC 1918, 192.168.0.0/16)"; return ;;
        127.*)        echo "loopback (RFC 1122)"; return ;;
        169.254.*)    echo "link-local / APIPA (RFC 3927) -- means DHCP failed"; return ;;
    esac
    # 172.16.0.0/12 and 100.64.0.0/10 need a range test, not a prefix match:
    # 172.32.x.x is public and 100.128.x.x is not.
    if [ "$n" -ge "$(to_int 172.16.0.0)" ] && [ "$n" -le "$(to_int 172.31.255.255)" ]; then
        echo "private  (RFC 1918, 172.16.0.0/12)"
    elif [ "$n" -ge "$(to_int 100.64.0.0)" ] && [ "$n" -le "$(to_int 100.127.255.255)" ]; then
        echo "shared address space (RFC 6598) -- carrier-grade NAT, not RFC 1918"
    else
        echo "public"
    fi
}

# --- the calculation ---------------------------------------------------------

analyse() {
    local ip=$1 prefix=$2
    local ip_int mask net bcast total usable first last

    ip_int=$(to_int "$ip")

    # The mask is "prefix ones followed by zeroes". Building it by shifting
    # avoids a lookup table and makes /0 and /32 fall out correctly.
    if [ "$prefix" -eq 0 ]; then mask=0
    else mask=$(( (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF )); fi

    net=$(( ip_int & mask ))                    # host bits cleared
    bcast=$(( net | (~mask & 0xFFFFFFFF) ))     # host bits all set
    total=$(( 1 << (32 - prefix) ))

    printf '\n  %s/%s\n' "$ip" "$prefix"
    printf '  %s\n' "----------------------------------------------------------"
    printf '  %-22s %-18s %s\n' "address"        "$ip"               "$(to_binary "$ip_int")"
    printf '  %-22s %-18s %s\n' "subnet mask"    "$(to_dotted $mask)" "$(to_binary "$mask")"
    printf '  %-22s %-18s %s\n' "wildcard mask"  "$(to_dotted $(( ~mask & 0xFFFFFFFF )))" ""
    printf '  %-22s %-18s %s\n' "network address" "$(to_dotted $net)" "$(to_binary "$net")"
    printf '  %-22s %-18s %s\n' "broadcast"      "$(to_dotted $bcast)" "$(to_binary "$bcast")"

    # /31 and /32 are the exceptions to "subtract two". A /32 is one host with
    # no network or broadcast address at all; a /31 is the point-to-point case
    # from RFC 3021, where both addresses are usable because a link with two
    # ends does not need a broadcast.
    if   [ "$prefix" -eq 32 ]; then
        usable=1; first=$ip; last=$ip
        printf '  %-22s %s\n' "usable hosts" "1  (a /32 is a single host route)"
    elif [ "$prefix" -eq 31 ]; then
        usable=2; first=$(to_dotted $net); last=$(to_dotted $bcast)
        printf '  %-22s %s\n' "usable hosts" "2  (RFC 3021 point-to-point, no broadcast)"
    else
        usable=$(( total - 2 ))
        first=$(to_dotted $(( net + 1 ))); last=$(to_dotted $(( bcast - 1 )))
        printf '  %-22s %s\n' "usable hosts" "$usable   = 2^(32-$prefix) - 2 = $total - 2"
    fi

    printf '  %-22s %s  ->  %s\n' "host range" "$first" "$last"
    printf '  %-22s %s\n' "total addresses" "$total"
    printf '  %-22s %s\n' "class (by 1st octet)" "$(class_of "${ip%%.*}")"
    printf '  %-22s %s\n' "scope" "$(scope_of "$ip" "$ip_int")"
}

# --- argument handling -------------------------------------------------------

if [ $# -eq 0 ]; then
    cat <<'TXT'
  no arguments given, so here are the examples I worked through by hand.
  usage:
    bash subnet-practice.sh 192.168.1.100/26
    bash subnet-practice.sh 10.0.0.5 255.255.255.0
TXT
    for case in \
        "192.168.1.100/24" \
        "192.168.1.100/26" \
        "10.0.0.5/8" \
        "172.16.34.200/20" \
        "203.0.113.9/30" \
        "8.8.8.8/32"
    do
        analyse "${case%%/*}" "${case##*/}"
    done
    exit 0
fi

case "$1" in
    */*)  analyse "${1%%/*}" "${1##*/}" ;;
    *)    if [ $# -lt 2 ]; then
              echo "give either a.b.c.d/prefix or 'a.b.c.d 255.255.255.0'"; exit 2
          fi
          analyse "$1" "$(mask_to_prefix "$2")" ;;
esac
