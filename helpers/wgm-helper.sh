# wgm-helper.sh — shared by tools/wgm.sh and reset.sh

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

_wgm_dns_to_resolved() {
    local conf="$1" servers
    servers=$(awk -F'=' '/^DNS[[:space:]]*=/ {print $2}' "$conf" | tr ',' ' ' | tr -s ' ' '\n' | grep -E '^[0-9a-fA-F.:]+$' | paste -sd' ' -)
    [[ -n "$servers" ]] || return 0
    sed -i -e '/^DNS[[:space:]]*=/d' -e '/^PostUp = resolvectl/d' -e '/^PostDown = resolvectl/d' "$conf"
    sed -i "/^\[Interface\]/a PostUp = resolvectl dns %i $servers; resolvectl domain %i ~.\nPostDown = resolvectl revert %i" "$conf"
}
