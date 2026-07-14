# wpm-helper.sh — shared by tools/wpm.sh and reset.sh

_wpm_set_paths() {
    local base="$1"
    CONF_DIR="$base/.config/arch-config-files/wpm"
    BACKUP_ROOT="$base/Documents/wpm-backup"
}
