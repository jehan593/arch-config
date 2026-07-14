# ==============================================================================
# LINK HELPERS — shared by setup.sh/reset.sh to walk mirrored file trees
# ==============================================================================

# Walks every file under etc/ (mirrors /etc exactly, any depth)
# calling _etc_file_action(src, dest) for each — the caller (setup.sh/reset.sh)
# defines that function to either install or remove the policy file.
_each_etc_file() {
    [[ -d "$DOTDIR/etc" ]] || return 0

    local file rel
    while IFS= read -r -d '' file; do
        rel="${file#"$DOTDIR"/}"
        _etc_file_action "$file" "/$rel"
    done < <(find "$DOTDIR/etc" -type f -print0)
}

# Walks every file under home/ (mirrors $HOME's structure exactly, any depth)
# calling _home_file_action(src, target) for each — the caller
# (setup.sh/reset.sh) defines that function to either create or remove the symlink.
_each_home_file() {
    [[ -d "$DOTDIR/home" ]] || return 0

    local file rel
    while IFS= read -r -d '' file; do
        rel="${file#"$DOTDIR"/home/}"
        _home_file_action "$file" "$HOME/$rel"
    done < <(find "$DOTDIR/home" -type f -print0)
}

# Walks each script under tools/, calling _tool_file_action(name, src) for
# each — the caller (setup.sh/reset.sh) defines that function to either link
# or unlink it from /usr/local/bin.
_each_tool_file() {
    [[ -d "$DOTDIR/tools" ]] || return 0

    local src name
    for src in "$DOTDIR/tools/"*.sh; do
        [[ -f "$src" ]] || continue
        name=$(basename "$src" .sh)
        _tool_file_action "$name" "$src"
    done
}
