# wgm-helper.sh — shared by scripts/wgm/wgm.sh and reset.sh

_wgm_set_paths() {
    local base="$1"
    WGM_ROOT="$base/.config/arch-config-files/wgm"
    CONFIGS_DIR="$WGM_ROOT/configs"
    WARP_DIR="$WGM_ROOT/warp"
    WARP_CONF="$WARP_DIR/warp.conf"
    WG_DIR="/etc/wireguard"
    BACKUP_ROOT="$base/Documents/wgm-backup"
}

_get_active_tunnel() {
    wg show interfaces 2>/dev/null | awk '{print $1; exit}'
}
