# TODO

- [ ] **DHCP option 138** — add option 138 (value: `192.168.99.1`) to the DHCP server config on whichever VLAN(s) the APs are on, so they can find the Omada controller without broadcast discovery after a reset or re-adoption.

- [ ] **SSH `ListenAddress`** — add `listenAddresses = [{address = "192.168.99.1";}]` to `services.openssh` in `configuration.nix` once the router is no longer accessed over WAN.
