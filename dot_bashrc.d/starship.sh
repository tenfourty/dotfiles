# Starship prompt — https://starship.rs
# Guarded so the shell still starts cleanly if starship is absent
# (e.g. before install, or if the Terra repo is ever removed).
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi
