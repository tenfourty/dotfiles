#!/usr/bin/env bash
# Claude Code status line
#   Line 1: starship (directory, git, language versions) via the "claude" profile
#   Line 2: model, context usage, prompt-cache stats, cost, duration, diff stat
#   Line 3: rate limits + session flags  (only when that data is present)
#
# Schema: https://code.claude.com/docs/en/statusline
# Starship profile is defined in ~/.config/starship.toml under [profiles].

set -uo pipefail

STARSHIP_BIN="${HOME}/.cargo/bin/starship"
input=$(cat)

# --- one jq call for everything ------------------------------------------
# NOTE: values are read one-per-line via mapfile, NOT `IFS=$'\t' read`.
# Tab is an IFS *whitespace* character, so consecutive empty fields collapse
# and silently shift every later field left -- which previously handed `rl7`
# the string "false" and made `(( rl7 >= 0 ))` fail under `set -u`.
mapfile -t F < <(
  jq -r '[
    (.workspace.current_dir // .cwd // "."),
    (.model.display_name // "?"),
    (.context_window.used_percentage // 0 | floor),
    ((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)),
    (.context_window.context_window_size // 0),
    (.context_window.current_usage.input_tokens // 0),
    (.context_window.current_usage.cache_creation_input_tokens // 0),
    (.context_window.current_usage.cache_read_input_tokens // 0),
    (.cost.total_cost_usd // 0),
    (.cost.total_duration_ms // 0),
    (.cost.total_lines_added // 0),
    (.cost.total_lines_removed // 0),
    (.output_style.name // ""),
    (.agent.name // ""),
    (.rate_limits.five_hour.used_percentage // -1 | floor),
    (.rate_limits.five_hour.resets_at // 0),
    (.rate_limits.seven_day.used_percentage // -1 | floor),
    (.effort.level // ""),
    (.fast_mode // false),
    (.thinking.enabled // false)
  ] | .[] | tostring' <<< "$input" 2>/dev/null
)

cwd="${F[0]:-.}"        ; model="${F[1]:-?}"
pct="${F[2]:-0}"        ; used="${F[3]:-0}"     ; winsize="${F[4]:-0}"
cin="${F[5]:-0}"        ; ccreate="${F[6]:-0}"  ; cread="${F[7]:-0}"
cost="${F[8]:-0}"       ; dur="${F[9]:-0}"
added="${F[10]:-0}"     ; removed="${F[11]:-0}"
style="${F[12]:-}"      ; agent="${F[13]:-}"
rl5="${F[14]:--1}"      ; rl5r="${F[15]:-0}"    ; rl7="${F[16]:--1}"
effort="${F[17]:-}"     ; fastmode="${F[18]:-false}" ; thinking="${F[19]:-false}"

# Force integer fields to be integers, so a malformed payload can never turn
# an arithmetic context into an indirect variable reference.
for v in pct used winsize cin ccreate cread dur added removed rl5 rl5r rl7; do
    [[ "${!v}" =~ ^-?[0-9]+$ ]] || printf -v "$v" '%s' 0
done
[[ "$cost" =~ ^[0-9]*\.?[0-9]+$ ]] || cost=0
: "${cwd:=.}" ; : "${model:=?}"

D=$'\033[0m'; DIM=$'\033[2m'; B=$'\033[1m'
GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'
CYN=$'\033[36m'; MAG=$'\033[35m'; BLU=$'\033[34m'

hum() { # humanise a token count
    local n=$1
    if   (( n >= 1000000 )); then awk "BEGIN{printf \"%.1fM\", $n/1000000}"
    elif (( n >= 1000 ));    then awk "BEGIN{printf \"%.0fk\", $n/1000}"
    else                          printf '%s' "$n"
    fi
}
bar() { # bar <pct> -> 10-cell bar
    local p=$1 f=$((${1}/10)) i out=""
    (( f > 10 )) && f=10; (( f < 0 )) && f=0
    for ((i=0;i<10;i++)); do (( i < f )) && out+="█" || out+="░"; done
    printf '%s' "$out"
}
pctcol() { # pctcol <pct> -> colour by pressure
    if   (( $1 >= 75 )); then printf '%s' "$RED"
    elif (( $1 >= 50 )); then printf '%s' "$YEL"
    else                      printf '%s' "$GRN"; fi
}

# --- line 1: starship ------------------------------------------------------
if [[ -x "$STARSHIP_BIN" ]]; then
    # starship emits no trailing newline; printf supplies one so line 2
    # does not run onto the end of line 1.
    # `env -u STARSHIP_SHELL` is essential. `starship init bash` exports
    # STARSHIP_SHELL=bash, and Claude Code inherits it from the shell it was
    # launched from. With it set, starship wraps every ANSI code in bash PS1
    # escapes (\[ and \]) which only mean something inside a prompt -- in the
    # status line they render literally as "\[\]~\[\]".
    line1=$(env -u STARSHIP_SHELL "$STARSHIP_BIN" prompt --profile claude \
        --path "$cwd" --logical-path "$cwd" \
        --terminal-width "${COLUMNS:-120}" 2>/dev/null \
      | sed '/^[[:space:]]*$/d')
    [[ -n "$line1" ]] && printf '%s\n' "$line1"
fi

# --- line 2: context, cache, cost -----------------------------------------
CC=$(pctcol "$pct")
out="${B}${MAG}${model}${D}"
out+="  ${CC}$(bar "$pct")${D} ${CC}${B}${pct}%${D}"
(( winsize > 0 )) && out+="${DIM}($(hum "$used")/$(hum "$winsize"))${D}"

# Prompt cache. total input = fresh + cache writes + cache reads.
# Hit rate = reads / total input -- high is good and means cheap, fast turns.
total_in=$(( cin + ccreate + cread ))
if (( total_in > 0 && (cread > 0 || ccreate > 0) )); then
    hit=$(( cread * 100 / total_in ))
    if   (( hit >= 70 )); then HC="$GRN"
    elif (( hit >= 30 )); then HC="$YEL"
    else                       HC="$DIM"
    fi
    out+="  ${HC}⚡${hit}%${D}${DIM}[$(hum "$cread")↓ $(hum "$ccreate")↑ $(hum "$cin")•]${D}"
fi

out+="  ${DIM}\$${D}$(awk "BEGIN{printf \"%.2f\", $cost}")"

secs=$(( dur / 1000 ))
if   (( secs >= 3600 )); then el=$(printf '%dh%02dm' $((secs/3600)) $(((secs%3600)/60)))
elif (( secs >= 60 ));   then el=$(printf '%dm%02ds' $((secs/60)) $((secs%60)))
else                          el="${secs}s"; fi
out+="  ${DIM}${el}${D}"

(( added > 0 || removed > 0 )) && out+="  ${GRN}+${added}${D}/${RED}-${removed}${D}"
[[ -n "${agent:-}" ]] && out+="  ${DIM}⚙${D}${CYN}${agent}${D}"
[[ -n "${style:-}" && "$style" != "default" && "$style" != "null" ]] && out+="  ${DIM}${style}${D}"
printf '%b\n' "$out"

# --- line 3: rate limits + flags (conditional) -----------------------------
# rate_limits appears only for Claude.ai Pro/Max after the first API response,
# and each window can be independently absent -- hence the -1 sentinel.
l3=""
if (( rl5 >= 0 )); then
    C=$(pctcol "$rl5"); l3+="${DIM}5h${D} ${C}$(bar "$rl5") ${rl5}%${D}"
    if (( rl5r > 0 )); then
        now=$(date +%s); left=$(( rl5r - now ))
        (( left > 0 )) && l3+="${DIM}→$(( left/3600 ))h$(printf '%02d' $(( (left%3600)/60 )))m${D}"
    fi
fi
if (( rl7 >= 0 )); then
    C=$(pctcol "$rl7"); [[ -n "$l3" ]] && l3+="  "
    l3+="${DIM}7d${D} ${C}$(bar "$rl7") ${rl7}%${D}"
fi
flags=""
[[ -n "${effort:-}" && "$effort" != "null" ]] && flags+=" ${BLU}${effort}${D}"
[[ "${fastmode:-false}" == "true" ]] && flags+=" ${YEL}fast${D}"
[[ "${thinking:-false}" == "true" ]] && flags+=" ${DIM}think${D}"
if [[ -n "$flags" ]]; then
    if [[ -n "$l3" ]]; then l3+="  ${DIM}·${D}${flags}"
    else                    l3+="${flags# }"      # no leading pad when alone
    fi
fi
[[ -n "$l3" ]] && printf '%b\n' "$l3"

exit 0   # never report failure: the last test above is falsy on a bare payload
