# Atuin shell history — https://atuin.sh
#
# Named zz- so it sorts AFTER starship.sh inside ~/.bashrc.d. Atuin bundles its
# own copy of bash-preexec and hooks PROMPT_COMMAND; loading it after starship
# preserves the order the installer originally set up in ~/.bashrc.

. "$HOME/.atuin/bin/env"
eval "$(atuin init bash)"

# --- Default the interactive search to: THIS HOST, CURRENT DIRECTORY ---------
#
# Atuin has no combined host+directory filter mode -- filter_mode is a single
# value. Verified empirically: filter_mode = "directory" is NOT host-scoped; in
# ~/ it returned wahala 240, baba 114, zoomer 48, xps13 5. The docs only imply
# host scoping; they are wrong on this point.
#
# The CLI does accept `--cwd` as a filter *independent* of --filter-mode, so:
#   filter_mode = "host"   (set in ~/.config/atuin/config.toml)
#   + --cwd "$PWD"         (injected below)
# together give "this host, this directory".
#
# Escape hatch: `ATUIN_NO_CWD_FILTER=1` searches all directories for one
# command, and plain `atuin search -i` is always unrestricted.
if declare -f __atuin_search_cmd >/dev/null 2>&1 &&
   ! declare -f __atuin_search_cmd_unscoped >/dev/null 2>&1; then
    # Guard against double-wrapping: ~/.bashrc gets sourced more than once here
    # (visible as ~/.cargo/bin appearing repeatedly in PATH).
    eval "__atuin_search_cmd_unscoped() $(declare -f __atuin_search_cmd | tail -n +2)"
    __atuin_search_cmd() {
        if [[ -n ${ATUIN_NO_CWD_FILTER:-} ]]; then
            __atuin_search_cmd_unscoped "$@"
        else
            __atuin_search_cmd_unscoped --cwd "$PWD" "$@"
        fi
    }
fi
