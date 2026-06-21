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

CREATE TABLE IF NOT EXISTS filters (
    oob_time_sec  INTEGER NOT NULL,
    oob_time_usec INTEGER NOT NULL,
    kind          TEXT NOT NULL,
    value         TEXT NOT NULL,
    PRIMARY KEY (kind, value)
);

CREATE TRIGGER upsert_filters AFTER INSERT ON log
BEGIN
    INSERT INTO filters (oob_time_sec, oob_time_usec, kind, value)
    SELECT NEW.oob_time_sec, NEW.oob_time_usec, 'iiface', NEW.oob_in
    WHERE NEW.oob_in <> ''
    ON CONFLICT (kind, value) DO UPDATE SET
        oob_time_sec = NEW.oob_time_sec,
        oob_time_usec = NEW.oob_time_usec;

    INSERT INTO filters (oob_time_sec, oob_time_usec, kind, value)
    SELECT NEW.oob_time_sec, NEW.oob_time_usec, 'oiface', NEW.oob_out
    WHERE NEW.oob_out <> ''
    ON CONFLICT (kind, value) DO UPDATE SET
        oob_time_sec = NEW.oob_time_sec,
        oob_time_usec = NEW.oob_time_usec;

    INSERT INTO filters (oob_time_sec, oob_time_usec, kind, value)
    SELECT NEW.oob_time_sec, NEW.oob_time_usec, 'protocol', CAST(NEW.ip_protocol AS TEXT)
    WHERE NEW.ip_protocol IS NOT NULL
    ON CONFLICT (kind, value) DO UPDATE SET
        oob_time_sec = NEW.oob_time_sec,
        oob_time_usec = NEW.oob_time_usec;
END;

PRAGMA journal_mode = WAL;
