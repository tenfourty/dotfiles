cd repo && python3 - <<'EOF'
import pathlib
p = pathlib.Path("docs/dev-notes.md")
new_dn = '''## Fake ssh for tests
```
VW=$(mktemp -d)
mkdir -p "$VW/bin"
cat > "$VW/bin/ssh" <<'EOF'
#!/usr/bin/env bash
echo "fake ssh $*"
EOF
chmod 755 "$VW/bin/"*
```
'''
p.write_text(p.read_text() + new_dn)
EOF
