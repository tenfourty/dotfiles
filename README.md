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

## Reproducing this machine

`chezmoi apply` restores dotfiles **and** provisions the system, from
`.chezmoidata/packages.yaml`:

| Script | Does |
|---|---|
| `run_onchange_10-repos.sh` | Enables COPRs; installs the committed `etc-repos/*.repo` files verbatim |
| `run_onchange_20-packages.sh` | Installs missing dnf packages |
| `run_onchange_30-flatpak.sh` | Adds flathub, installs missing flatpaks |
| `run_onchange_40-user-tools.sh` | `cargo binstall` and `uv tool install` |

`run_onchange_` means each script re-runs only when its rendered content
changes. Every script embeds a hash of the manifest, so editing
`packages.yaml` re-triggers them all on the next apply. They are idempotent:
on a machine that already has everything they print "all present" and change
nothing. Verified.

Regenerate the manifest from the live system:

```sh
machine-manifest --write && chezmoi apply
```

The manifest is a **curated draft**, not gospel. dnf does not reliably record
"the user asked for this" across a system-upgrade chain, so the generator
filters out kernels, `lib*`/`*-libs` dependencies and packages whose repo
attribution was lost. Read the diff before committing it.

### What this does NOT reproduce

Honest limits — these need doing by hand on a fresh machine:

- **Disk layout, LUKS, and the passphrase.** Set at install time.
- **BIOS settings** — Secure Boot, Thunderbolt security level, battery charge
  thresholds. On Dell these are scriptable from Linux via `dell-wmi-sysman`
  (see `docs/`), but they need the BIOS admin password.
- **Kernel command line** — `mem_sleep_default=deep intel_iommu=on iommu=pt`.
- **KDE settings that KDE rewrites at runtime** — `kwinrc`,
  `kglobalshortcutsrc`. Version-controlling files a daemon rewrites produces
  permanent spurious diffs; the settings that matter are documented instead.
- **Application state and credentials** — browser profiles, Slack, Beeper.
- **Data.** This repo is config only.

## macOS

The work MacBook uses the same repo, OS-gated. `.chezmoiignore`'s darwin block
skips everything Linux-only, the provisioning scripts, `.ssh`, and the files not
yet reconciled with the Mac's own versions — adoption is one line at a time, so
an apply never rewrites something the Mac already has. `.gitconfig` is a template:
on darwin it only carries the name, the ggshield `hooksPath`, and two
age-encrypted includes, `~/.config/git/work-gg.inc` (work identity, signing, gh
helper) and `~/.config/git/forge.inc` (forge credentials, per-remote identity).
Without the age identity those two are skipped rather than failing the apply.

```sh
brew install chezmoi age git-delta
chezmoi init --source ~/repos/dotfiles     # clone lives with the other repos
chezmoi status                             # must be empty before trusting an apply
```

## Not managed here

- `~/.bashrc.d/50-machine-docs.sh` — written by `~/dev/bootstrap.sh`
- `~/AGENTS.md`, `~/docs`, `~/me` — symlinks into Nextcloud-synced `~/dev`
- SSH private keys, the age identity, atuin's key and database

## Rex on the Mac

`chezmoi apply` writes the launchd jobs but doesn't load them. On a new Mac, load each with
`launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/<job>.plist`: `dev.rex-backup` and the
`dev.rex-tunnel.*` jobs. The tunnels also need the `*-herdr` SSH aliases and keys, which aren't
managed here, and a Rex server on each host. Add each tunnel's socket in the Rex app with
Add Remote Host, as `unix://$HOME/.local/state/rex-tunnels/<host>.sock`.

`dot_config/rex/rex-image-paste` is a copy of github.com/pablasso/rex-image-paste at 1d883ef with
one local change, so read upstream's diff before updating it.

## Claude accounts across machines

`claude-accounts` (`dot_local/bin/executable_claude-accounts`, config in `dot_config/claude-accounts/machines.toml`,
Mac only) keeps the seven Claude Code accounts working on every machine with as few browser sign-ins as possible.
The Mac holds real OAuth logins for all seven (`gg`, `gg-eng`, `personal`, `max01`..`max04`) and is the only machine
that reads usage. baba, jbrown-dev and the office VMs hold one-year setup-tokens (`claude setup-token`, then
`cswap add-token`), one approval per account, delivered to every machine that needs it. baba's existing OAuth
entries are never removed or switched: they show as "extra".

```sh
claude-accounts check              # what works where (read-only)
claude-accounts fix --dry-run      # what it would ask you to approve; sends nothing
claude-accounts fix                # interactive, in a terminal on the Mac
claude-accounts sync-usage         # push the Mac's usage readings to the token machines now
```

The launchd job `dev.claude-accounts.sync-usage` runs `sync-usage` every 5 minutes (`cswap list --json` on the Mac,
then `cswap import-usage <file> --hold 1200` on each token machine). Like the Rex jobs, `chezmoi apply` writes it
but does not load it: `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.claude-accounts.sync-usage.plist`.
Its log is `~/.local/state/claude-accounts/sync-usage.log`.

Two things that bite a launchd job here. baba is reached as `baba-herdr` (plain key `~/.ssh/herdr_baba`), not
`baba`: Secretive's public key sits in an app container that launchd jobs may not read, and Secretive cannot sign
while the Mac is locked, so a failing timer would earn a Warpgate block (5 failed logins in 15 minutes). The timer
also sits out 30 minutes after any refused SSH login. Text from other machines is printed through `clean()`, which
turns control characters into `?`. Tests: `PATH=/opt/homebrew/bin:$PATH bash tests/claude-accounts/test-claude-accounts.sh`.

## Claude Code guard hooks

`dot_claude/hooks/executable_heredoc-guard` is a PreToolUse hook, wired up in
`dot_claude/settings.json`, that refuses a heredoc whose body reuses its own
delimiter: bash ends the outer heredoc at the inner terminator and runs the
rest of the body as commands. It allows on any internal error. Tests live in
`tests/`, which chezmoi does not install:

```sh
bash tests/heredoc-guard/test-heredoc-guard.sh
```

On macOS `settings.json` is still in the not-reconciled list in
`.chezmoiignore`, so the hook file arrives there but is not active until that
file is reconciled or the entry is added by hand.

## Verifying before a push

```sh
ggshield secret scan repo .     # whole history
ggshield secret scan path -r -y .
```
