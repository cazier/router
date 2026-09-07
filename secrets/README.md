# Secrets

Managed with [sops-nix](https://github.com/Mic92/sops-nix).

## Prerequisites

`sops` and `age` in the system path.

## Edit / add / remove a value

    sops secrets/<path-to-secret-file>.yaml

The yaml file will contain `key: value` pairs, and the keys must match the `sops.secrets.<key>` in the Nix modules.

Adding a secret also needs a declaration in the relevant module, e.g.:

    sops.secrets.<key>.owner = "some-user";

Removing one: delete the key here and the `sops.secrets.<name>` block.

## Show a value

    sops decrypt secrets/<path-to-secret-file>.yaml
    sops decrypt --extract '["wireguard-private-key"]' secrets/<path-to-secret-file>.yaml

## Rotate the age key

1. New keypair: `age-keygen -o /var/lib/sops/keyfile` (back up the old one first)
2. Put the new recipient (`age-keygen -y /var/lib/sops/keyfile`) in `.sops.yaml`
3. Re-encrypt each file: `sops updatekeys secrets/<path-to-secret-file>.yaml
