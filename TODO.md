# TODO

- [ ] Switch MGMT VLAN to be tag 0 instead of 99?

- [ ] **DHCP option 138** — add option 138 (value: `192.168.99.1`) to the DHCP server config on whichever VLAN(s) the APs are on, so they can find the Omada controller without broadcast discovery after a reset or re-adoption.
