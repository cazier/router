{
  # RFC1918 private network ranges
  privateNets = [
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
  ];

  # Bogon/martian addresses that should never appear on public internet
  bogons = [
    "0.0.0.0/8" # "This" network (RFC1122)
    "10.0.0.0/8" # Private (RFC1918)
    "100.64.0.0/10" # Carrier-grade NAT (RFC6598)
    "127.0.0.0/8" # Loopback (RFC1122)
    "169.254.0.0/16" # Link-local (RFC3927)
    "172.16.0.0/12" # Private (RFC1918)
    "192.0.0.0/24" # IETF protocol assignments (RFC6890)
    "192.0.2.0/24" # TEST-NET-1 documentation (RFC5737)
    "192.168.0.0/16" # Private (RFC1918)
    "198.18.0.0/15" # Benchmarking (RFC2544)
    "198.51.100.0/24" # TEST-NET-2 documentation (RFC5737)
    "203.0.113.0/24" # TEST-NET-3 documentation (RFC5737)
    "224.0.0.0/4" # Multicast (RFC5771)
    "240.0.0.0/4" # Reserved/future use (RFC1112)
  ];
}
