cd repo && python3 - <<'PYEOF'
new_dn = '''cat > "$VW/bin/ssh" <<'EOF'
#!/usr/bin/env bash
echo fake
EOF
chmod 755 "$VW/bin/"*
'''
print(new_dn)
PYEOF
