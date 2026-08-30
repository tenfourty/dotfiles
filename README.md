# dotfiles

Managed with [chezmoi](https://chezmoi.io). Secrets are encrypted with
[age](https://age-encryption.org); the identity is **not** in this repo.

This repo is public. That is deliberate and safe only because of two things:

1. A **ggshield pre-commit hook** blocks unencrypted secrets. Verified in both
   directions — a clean commit passes, a real private key is rejected.
2. Anything revealing but not strictly secret is **age-encrypted** —
   `.ssh/config` in particular, since it accumulates internal hostnames.

## Restoring on a new machine

```sh
sudo dnf install chezmoi age            # or the local equivalent

# 1. Restore the age identity from the Dashlane secure note
#    titled "chezmoi dotfiles — age identity".
#
#    NOTE: `dcli note` reads a LOCAL vault copy. Without `dcli sync` first you
#    can silently restore a stale version of the note — observed in practice:
#    an edit made in the Dashlane app still returned the old 1-line content
#    until a sync was run, after which it returned the correct 3 lines.
mkdir -p ~/.config/chezmoi
dcli sync
dcli note -o json "chezmoi" | jq -r '.[0].content' > ~/.config/chezmoi/key.txt
chmod 600 ~/.config/chezmoi/key.txt

# 2. Verify it is the right key before trusting it.
age-keygen -y ~/.config/chezmoi/key.txt
#    must print: age1ycqmpcmcygk0keenge3kfa6ua3y53plnkud8x0wnalnh4mzdlenqvwv30n

# 3. Apply.
chezmoi init --apply https://github.com/tenfourty/dotfiles.git
```

`.chezmoi.toml.tmpl` generates the age configuration at init time, so step 3
works without any manual config. Without step 1 the repo clones fine and the
encrypted files simply stay encrypted.

The identity is **one key for all machines**, not one per machine — hence the
machine-agnostic note title.

## Not managed here

- `~/.bashrc.d/50-machine-docs.sh` — written by `~/dev/bootstrap.sh`
- `~/AGENTS.md`, `~/docs`, `~/me` — symlinks into Nextcloud-synced `~/dev`
- SSH private keys, the age identity, atuin's key and database

## Verifying before a push

```sh
ggshield secret scan repo .     # whole history
ggshield secret scan path -r -y .
```
