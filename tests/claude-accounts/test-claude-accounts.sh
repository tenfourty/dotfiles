#!/usr/bin/env bash
# claude-accounts: text from a remote machine never reaches the terminal with a control character in it,
# and the shipped machines.toml loads. Needs Python 3.11+ first on PATH (on the Mac: /opt/homebrew/bin).
# Exit non-zero on any FAIL.
set -u
here=$(cd "$(dirname "$0")" && pwd)
script="$here/../../dot_local/bin/executable_claude-accounts"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export CLAUDE_ACCOUNTS_STATE="$tmp/state"

# A hostile cswap: ESC, BEL and a C1 control in an alias, an email and an error message (valid JSON escapes).
cat > "$tmp/cswap" <<'SH'
#!/bin/bash
if [ "$FAKE" = err ]; then
  printf '{"error":{"message":"bad \\u001b[2Jthing \\u001b]0;pwn\\u0007 \\u009b31m"}}'; exit 1
fi
printf '{"accounts":[{"number":1,"email":"x@y.z\\u001b[31m","alias":"evil\\u001b]0;pwn\\u0007\\u009b2J","organizationUuid":"u","usageStatus":"ok"}]}'
SH
chmod 700 "$tmp/cswap"
cat > "$tmp/m.toml" <<TOML
[settings]
usage_reader = "m"
[accounts.a]
slot = 1
email = "a@b.c"
[machines.m]
route = "local"
mode = "login"
accounts = ["a"]
cswap = "$tmp/cswap"
TOML

fails=0
# A raw ESC (0x1b), BEL (0x07) or C1 (0xc2 0x80-0x9f in UTF-8) in the output is a failure.
bad() { LC_ALL=C grep -qE $'[\x01-\x08\x0b-\x1f\x7f]|\xc2[\x80-\x9f]'; }
check() { # name, then the command
  local name=$1 out; shift
  out=$("$@" 2>&1)
  if printf '%s' "$out" | bad; then echo "FAIL $name: control character in output"; fails=$((fails + 1))
  elif ! printf '%s' "$out" | grep -q '?'; then echo "FAIL $name: nothing was sanitised ($out)"; fails=$((fails + 1))
  else echo "ok   $name"; fi
}
export CLAUDE_ACCOUNTS_CONFIG="$tmp/m.toml"
check "check, hostile alias and email" env FAKE=ok python3 -I "$script" check
check "check, hostile error message"   env FAKE=err python3 -I "$script" check
check "fix --dry-run, hostile alias"   env FAKE=ok python3 -I "$script" fix --dry-run
check "fix --dry-run, hostile error"   env FAKE=err python3 -I "$script" fix --dry-run

# The shipped config loads (accounts, groups, machines and the reader are consistent).
if CLAUDE_ACCOUNTS_CONFIG="$here/../../dot_config/claude-accounts/machines.toml" python3 -I - "$script" <<'PY'
import importlib.machinery, importlib.util, sys
sys.dont_write_bytecode = True
loader = importlib.machinery.SourceFileLoader("ca", sys.argv[1])
mod = importlib.util.module_from_spec(importlib.util.spec_from_loader("ca", loader))
sys.modules["ca"] = mod
loader.exec_module(mod)
cfg = mod.load_config()
assert cfg.machines["mac"].mode == "login" and len(cfg.machines["mac"].accounts) == 7
assert all(m.mode == "token" for n, m in cfg.machines.items() if n != "mac")
assert cfg.machines["baba"].accounts == ("max01", "max02", "max03", "max04")
PY
then echo "ok   shipped machines.toml loads"; else echo "FAIL shipped machines.toml"; fails=$((fails + 1)); fi

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
