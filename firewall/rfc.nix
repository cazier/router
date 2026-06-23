{
  # RFC1918 private network ranges
  PRIVATE_NETWORKS = [
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
  ];

  # Bogon/martian addresses that should never appear on public internet (IPv4)
  IPV4_BOGONS = [
    "0.0.0.0/8"
    "10.0.0.0/8"
    "100.64.0.0/10"
    "127.0.0.0/8"
    "169.254.0.0/16"
    "172.16.0.0/12"
    "192.0.0.0/24"
    "192.0.2.0/24"
    # "192.168.0.0/16"
    "198.18.0.0/15"
    "198.51.100.0/24"
    "203.0.113.0/24"
    "224.0.0.0/4"
    "240.0.0.0/4"
  ];

  # Bogon IPv6 addresses that should never appear as sources on public internet.
  IPV6_BOGONS = [
    "::/128"
    "::1/128"
    "::ffff:0:0/96"
    "::/96"
    "100::/64"
    "2001:db8::/32"
    "2001:10::/28"
    "fc00::/7"
    "fe80::/10"
    "ff00::/8"
    "2002::/16"
    "3ffe::/16"
  ];
}
