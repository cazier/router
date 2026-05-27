CREATE TABLE IF NOT EXISTS log (
    oob_time_sec  INTEGER NOT NULL,
    oob_time_usec INTEGER NOT NULL,
    oob_prefix    TEXT NOT NULL,
    oob_in        TEXT NOT NULL,
    oob_out       TEXT NOT NULL,
    ip_saddr_str  TEXT NOT NULL,
    ip_daddr_str  TEXT NOT NULL,
    ip_protocol   INTEGER,
    ip_ttl        INTEGER,
    tcp_sport     INTEGER,
    tcp_dport     INTEGER,
    udp_sport     INTEGER,
    udp_dport     INTEGER,
    icmp_type     INTEGER,
    icmp_code     INTEGER,
    raw_pktlen    INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS protocol_options (
    oob_time_sec INTEGER NOT NULL,
    oob_time_usec INTEGER NOT NULL,
    ip_protocol INTEGER,
    UNIQUE(ip_protocol) ON CONFLICT REPLACE
);

CREATE TABLE IF NOT EXISTS iiface_options (
    oob_time_sec INTEGER NOT NULL,
    oob_time_usec INTEGER NOT NULL,
    oob_in TEXT NOT NULL,
    UNIQUE(oob_in) ON CONFLICT REPLACE
);

CREATE TABLE IF NOT EXISTS oiface_options (
    oob_time_sec INTEGER NOT NULL,
    oob_time_usec INTEGER NOT NULL,
    oob_out TEXT NOT NULL,
    UNIQUE(oob_out) ON CONFLICT REPLACE
);

PRAGMA journal_mode = WAL;
