git commit -m "$(cat <<'EOF'
an odd " quote
EOF
)" && cat <<EOF
ok
EOF
