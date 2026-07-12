#!/bin/bash

# WireGuard Manager (wpm)

source "$ARCH_CONFIG_PATH/helpers/common-helpers.sh"
source "$ARCH_CONFIG_PATH/scripts/wpm/wpm-helper.sh"

_test_dependencies wireproxy ss fzf || exit 1

BINARY_PATH="/usr/bin/wireproxy"
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

_wpm_set_paths "$REAL_HOME"

if [ "$EUID" -ne 0 ]; then
    echo -e "${NORD_CYAN}Elevating...${RST}"
    exec sudo -E bash "$(realpath "$0")" "$@"
fi

_wpm_tunnel_info() {
    local service="$1"
    NAME=$(basename "$service" .service)
    STATUS=$(systemctl is-active "$NAME")
    CONF_FILE="$CONF_DIR/${NAME%-wpm}.conf"
    PORT=$(grep "BindAddress" "$CONF_FILE" 2>/dev/null | tr -d ' ' | awk -F':' '{print $NF}')
    [[ "$STATUS" == "active" ]] && S_COL="${NORD_GREEN}" || S_COL="${NORD_RED}"
}

wpm_add() {
    if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
        _print_status "warning" "Usage: wpm add <name> <config> <port>"
        return 1
    fi

    local NAME="$1"
    CONFIG_PATH=$(realpath "$2" 2>/dev/null)
    if [[ -z "$CONFIG_PATH" ]]; then
        _print_status "error" "File not found: $2"
        return 1
    fi

    local SERVICE_NAME="${NAME}-wpm"
    local CONF_DEST="$CONF_DIR/${NAME}.conf"

    if [[ -f "$CONF_DEST" || -f "/etc/systemd/system/${SERVICE_NAME}.service" ]]; then
        _print_status "error" "Name '$NAME' already in use"
        return 1
    fi

    PORT=$3
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
        _print_status "error" "Invalid port: $PORT"
        return 1
    fi

    if ss -tlnp | grep -q ":$PORT "; then
        _print_status "error" "Port $PORT is already in use"
        return 1
    fi

    local f existing_port
    for f in "$CONF_DIR"/*.conf; do
        [[ -f "$f" ]] || continue
        existing_port=$(grep "BindAddress" "$f" 2>/dev/null | tr -d ' ' | awk -F':' '{print $NF}')
        if [[ "$existing_port" == "$PORT" ]]; then
            _print_status "error" "Port $PORT already assigned to $(basename "$f" .conf)"
            return 1
        fi
    done

    _print_header "Installing: $NAME" ""

    mkdir -p "$CONF_DIR"
    cp "$CONFIG_PATH" "$CONF_DEST"
    chmod 600 "$CONF_DEST"
    _print_status "success" "Config copied"

    if grep -q "BindAddress" "$CONF_DEST"; then
        sed -i "s/BindAddress = .*/BindAddress = 127.0.0.1:$PORT/" "$CONF_DEST"
    else
        echo -e "\n[Socks5]\nBindAddress = 127.0.0.1:$PORT" >> "$CONF_DEST"
    fi
    _print_status "success" "Bound to port $PORT"

    cat <<UNIT > /etc/systemd/system/${SERVICE_NAME}.service
[Unit]
Description=wpm tunnel ($NAME)
After=network.target

[Service]
Type=simple
ExecStart=$BINARY_PATH -c $CONF_DEST
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

    systemctl daemon-reload
    _print_result $? "Reloaded daemon"

    systemctl enable "$SERVICE_NAME"
    _print_result $? "Enabled service"

    systemctl restart "$SERVICE_NAME"
    _print_result $? "Started service"

    echo ""
}

wpm_ls() {
    shopt -s nullglob
    local services=(/etc/systemd/system/*-wpm.service)

    _print_header "wpm Tunnels" ""

    if [[ ${#services[@]} -eq 0 ]]; then
        _print_status "error" "No tunnels found"
        echo ""; return
    fi

    printf "${NORD_D_BLUE}%-25s %-12s %-10s${RST}\n" "SERVICE" "STATUS" "PORT"
    echo -e "${NORD_POLAR_4}─────────────────────────────────────────────────────${RST}"

    local service
    for service in "${services[@]}"; do
        _wpm_tunnel_info "$service"
        printf "${NORD_BLUE}%-25s${RST} ${S_COL}%-12s${RST} ${NORD_SNOW_1}%s${RST}\n" \
            "$NAME" "$STATUS" "$PORT"
    done

    echo ""
}

_wpm_pick_tunnels() {
    local prompt="$1"

    shopt -s nullglob
    local services=(/etc/systemd/system/*-wpm.service)

    if [[ ${#services[@]} -eq 0 ]]; then
        _print_status "error" "No tunnels found"
        return 1
    fi

    local lines=() service
    for service in "${services[@]}"; do
        _wpm_tunnel_info "$service"
        lines+=("$(printf "%-25s %-12s %-10s" "$NAME" "$STATUS" "$PORT")")
    done

    local selected
    selected=$(printf '%s\n' "${lines[@]}" | fzf -m \
        --bind=ctrl-a:toggle-all \
        --header="TAB: select | CTRL-A: toggle all | ENTER: confirm" \
        --prompt="$prompt > " --reverse --height=40%)
    if [[ -z "$selected" ]]; then
        _print_status "info" "Cancelled"
        return 1
    fi

    WPM_PICKED=()
    local name
    while IFS= read -r line; do
        name=$(awk '{print $1}' <<< "$line")
        WPM_PICKED+=("/etc/systemd/system/${name}.service")
    done <<< "$selected"
}

wpm_rm() {
    _print_header "Uninstall Tunnel" ""
    _wpm_pick_tunnels "Uninstall" || { echo ""; return; }
    local to_remove=("${WPM_PICKED[@]}") service

    echo ""
    _print_status "warning" "Will uninstall ${#to_remove[@]} tunnel(s):"
    for service in "${to_remove[@]}"; do
        echo -e "${NORD_RED}$(basename "$service" .service)${RST}"
    done

    echo ""
    read -p "$(echo -e "${NORD_BLUE}Confirm? [y/N]: ${RST}")" confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && { _print_status "warning" "Cancelled"; echo ""; return; }

    echo ""
    mkdir -p "$BACKUP_ROOT"
    chown -R "$REAL_USER:$REAL_USER" "$BACKUP_ROOT"

    for service in "${to_remove[@]}"; do
        local NAME=$(basename "$service" .service)
        local CONF_FILE="$CONF_DIR/${NAME%-wpm}.conf"

        if [[ -f "$CONF_FILE" ]]; then
            cp "$CONF_FILE" "$BACKUP_ROOT/${NAME%-wpm}.conf"
            _print_status "success" "Backup saved to Documents/wpm-backup"
        fi

        systemctl stop "$NAME"
        systemctl disable "$NAME"
        rm -f "$service" "$CONF_FILE"
        systemctl daemon-reload
        _print_status "success" "Removed $NAME"
        echo ""
    done
}

_wpm_bulk_action() {
    local verb="$1" header_text="$2" past_tense="$3" prompt="$4"

    _print_header "$header_text" ""
    _wpm_pick_tunnels "$prompt" || { echo ""; return; }

    local service
    for service in "${WPM_PICKED[@]}"; do
        local NAME=$(basename "$service" .service)
        systemctl "$verb" "$NAME"
        _print_result $? "$past_tense $NAME"
    done

    echo ""
}

wpm_start()   { _wpm_bulk_action start   "Starting Tunnels"   "Started"   "Start"; }
wpm_stop()    { _wpm_bulk_action stop    "Stopping Tunnels"   "Stopped"   "Stop"; }
wpm_restart() { _wpm_bulk_action restart "Restarting Tunnels" "Restarted" "Restart"; }

# --- Router ---
case "$1" in
    add)     wpm_add "$2" "$3" "$4" ;;
    ls)      wpm_ls ;;
    rm)      wpm_rm ;;
    start)   wpm_start ;;
    stop)    wpm_stop ;;
    restart) wpm_restart ;;
    *)
        _print_header "wpm Manager" ""
        printf "${NORD_CYAN}%-12s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "add"     "<name> <conf> <port>  Install tunnel"
        printf "${NORD_CYAN}%-12s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "ls"      "List tunnels"
        printf "${NORD_CYAN}%-12s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "rm"      "Uninstall tunnels"
        printf "${NORD_CYAN}%-12s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "start"   "Start tunnels"
        printf "${NORD_CYAN}%-12s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "stop"    "Stop tunnels"
        printf "${NORD_CYAN}%-12s${RST}${NORD_POLAR_4} -> ${RST}${NORD_SNOW_1}%s${RST}\n" "restart" "Restart tunnels"
        echo ""
        exit 1
        ;;
esac