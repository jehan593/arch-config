# ==============================================================================
# DEPENDENCY CHECK — pure helper: no user-facing output. Emits the names of any
# missing commands to stdout (one per line) and returns non-zero if any are
# missing or if called with no arguments; callers print via printfc.
# ==============================================================================

_test_dependencies() {
    [ $# -eq 0 ] && return 1

    local missing=() cmd app
    for cmd in "$@"; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done

    [ ${#missing[@]} -gt 0 ] || return 0

    for app in "${missing[@]}"; do
        printf '%s\n' "$app"
    done
    return 1
}
