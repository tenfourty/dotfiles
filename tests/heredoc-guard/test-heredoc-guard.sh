#!/usr/bin/env bash
# Table tests for heredoc-guard. Exit non-zero on any FAIL.
set -u
here=$(cd "$(dirname "$0")" && pwd)
guard="$here/../../dot_claude/hooks/executable_heredoc-guard"
fx="$here/fixtures"
gen=$(mktemp -d)
trap 'rm -rf "$gen"' EXIT

# <<- fixtures need literal tabs: build them with printf.
printf 'if true; then\n\tcat <<-EOF\n\t\tindented $HOME\n\tEOF\nfi\n' > "$gen/dash-tabs.sh"
printf 'bash <<-EOF\n\tcat <<-EOF\n\tx\n\tEOF\n\techo leak\nEOF\n' > "$gen/dash-nested-same.sh"
# A plain outer heredoc is not ended by a tab-indented line: bash keeps it open.
printf 'cat <<EOF\n\tcat <<-EOF\n\tEOF\nEOF\necho after\n' > "$gen/dash-inner-plain-outer.sh"
printf 'cat <<-EOF\n\tcat <<EOF\nEOF\necho leak\nEOF\n' > "$gen/plain-inner-dash-outer.sh"

# JSON payload from a command file (python -c, no heredoc).
mkjson() { # tool_name file
  python3 -I -c 'import json,sys; print(json.dumps({"tool_name":sys.argv[1],"tool_input":{"command":open(sys.argv[2]).read()}}))' "$1" "$2"
}

fails=0
run() { # name expected_exit stdin_payload
  local name=$1 want=$2 payload=$3 got err t0 t1 ms
  t0=$(date +%s%N)
  err=$(printf '%s' "$payload" | "$guard" 2>&1 >/dev/null); got=$?
  t1=$(date +%s%N); ms=$(( (t1 - t0) / 1000000 ))
  if [ "$got" = "$want" ]; then
    printf 'PASS  %-24s want=%s got=%s %4sms\n' "$name" "$want" "$got" "$ms"
  else
    printf 'FAIL  %-24s want=%s got=%s %4sms %s\n' "$name" "$want" "$got" "$ms" "$err"
    fails=$((fails + 1))
  fi
}

run same-delim-in-python 2 "$(mkjson Bash "$fx/same-delim-in-python.sh")"
run bare-nested-same    2 "$(mkjson Bash "$fx/bare-nested-same.sh")"
run dash-nested-same    2 "$(mkjson Bash "$gen/dash-nested-same.sh")"
run unterminated-same   2 "$(mkjson Bash "$fx/unterminated-same.sh")"
run nested-distinct     0 "$(mkjson Bash "$fx/nested-distinct.sh")"
run plain               0 "$(mkjson Bash "$fx/plain.sh")"
run dash-tabs           0 "$(mkjson Bash "$gen/dash-tabs.sh")"
run quoted-delims       0 "$(mkjson Bash "$fx/quoted-double.sh")"
run herestring          0 "$(mkjson Bash "$fx/herestring.sh")"
run sequential-eof      0 "$(mkjson Bash "$fx/sequential.sh")"
run bash-c-string       0 "$(mkjson Bash "$fx/bash-c.sh")"
run unterminated-plain  0 "$(mkjson Bash "$fx/unterminated-plain.sh")"
run comment-and-quotes  0 "$(mkjson Bash "$fx/comment-opener.sh")"
run non-bash-tool       0 "$(mkjson Write "$fx/same-delim-in-python.sh")"
run garbage-stdin       0 'this is {not json'
run empty-stdin         0 ''
run json-array          0 '[1,2,3]'

# Must pass: a false refusal stops every agent on every machine.
for f in mention-in-body mention-commit-msg mention-then-real quotes-in-commit-msg \
         multi-on-one-line arithmetic multi-line-pipeline quoted-angle; do
  run "$f" 0 "$(mkjson Bash "$fx/$f.sh")"
done
run dash-inner-plain-outer 0 "$(mkjson Bash "$gen/dash-inner-plain-outer.sh")"

# Must refuse: the shape, including where an earlier construct could hide it.
for f in dq-subst-nested bare-arith-before param-expansion-before \
         ansi-c-quote-before two-inner mixed-quoting; do
  run "$f" 2 "$(mkjson Bash "$fx/$f.sh")"
done
run plain-inner-dash-outer 2 "$(mkjson Bash "$gen/plain-inner-dash-outer.sh")"

echo "fails=$fails"
[ "$fails" -eq 0 ]
