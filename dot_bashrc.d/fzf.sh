# fzf key bindings (Ctrl-R history, Ctrl-T files, Alt-C cd) and completion.
# Fedora ships these under /usr/share/fzf/shell/ rather than wiring them up.
# NOTE: atuin also binds Ctrl-R and loads later (zz- prefix), so atuin wins
# there deliberately — fzf still provides Ctrl-T and Alt-C.
[ -f /usr/share/fzf/shell/key-bindings.bash ] && . /usr/share/fzf/shell/key-bindings.bash
[ -f /usr/share/fzf/shell/completion.bash ]   && . /usr/share/fzf/shell/completion.bash
