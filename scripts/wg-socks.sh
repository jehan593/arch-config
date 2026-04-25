#!/bin/bash

# ==============================================================================
# WIREGUARD SOCKS5 MANAGER (Nord Aesthetic)
# ==============================================================================

# Nord Colors
NORD_POLAR_4='\e[38;2;76;86;106m'
NORD_SNOW_1='\e[38;2;216;222;233m'
NORD_CYAN='\e[38;2;143;188;187m'
NORD_BLUE='\e[38;2;136;192;208m'
NORD_D_BLUE='\e[38;2;129;161;193m'
NORD_GREEN='\e[38;2;163;190;140m'
NORD_RED='\e[38;2;191;97;106m'
NORD_ORANGE='\e[38;2;208;135;112m'
RST='\e[0m'

HEADER_LINE="${NORD_POLAR_4}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}"

BINARY_PATH="/usr/bin/wireproxy"
CONF_DIR="/etc/wireproxy"
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# Elevation check
if [ "$EUID" -ne 0 ]; then
    echo -e "\n${NORD_CYAN}󰮯${RST}  ${NORD_SNOW_1}Elevating privileges for wg-socks...${RST}"
    exec sudo bash "$(realpath "$0")" "$@"
fi

# --- UI Helpers ---

_print_header() {
    echo -e "\n${1}  ${NORD_SNOW_1}${2}${RST}"
    echo -e "${HEADER_LINE}"
}

_print_footer() {
    echo -e "${HEADER_LINE}\n"
}

_print_row() {
    printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%s${RST} %-12s ${NORD_SNOW_1}%s${RST}\n" "$1" "$2" "$3"
}

_print_status() {
    local color=$NORD_BLUE
    [[ "$1" == "󰄬" ]] && color=$NORD_GREEN
    [[ "$1" == "󰅙" ]] && color=$NORD_RED
    printf "${NORD_POLAR_4}│${RST}  ${color}%s${RST}  %s\n" "$1" "$2"
}

_pass_thru() {
    while IFS= read -r line; do
        printf '\e[38;2;118;138;161m│  %s\e[0m\n' "$line"
    done
}

_run() {
    local label="$1"; shift
    local output
    output=$("$@" 2>&1)
    if [[ $? -eq 0 ]]; then
        [[ -n "$output" ]] && echo "$output" | _pass_thru
        _print_row "󰄬" "$label" "Done"
    else
        [[ -n "$output" ]] && echo "$output" | _pass_thru
        _print_row "󰅙" "$label" "Failed"
    fi
}

# --- Actions ---

install_socks() {
    if [[ -z "$1" || -z "$2" ]]; then
        _print_header "${NORD_RED}󰅙${RST}" "Installation Error"
        _print_status "󰅙" "Usage: wg-socks install <config_path> <port>"
        _print_footer; exit 1
    fi

    [[ -f "$BINARY_PATH" ]] || {
        _print_header "${NORD_RED}󰅙${RST}" "Missing Binary"
        _print_status "󰅙" "wireproxy not found at $BINARY_PATH"
        _print_footer; exit 1
    }

    CONFIG_PATH=$(realpath "$1" 2>/dev/null) || {
        _print_header "${NORD_RED}󰅙${RST}" "File Error"
        _print_status "󰅙" "File not found: $1"
        _print_footer; exit 1
    }

    PORT=$2
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
        _print_header "${NORD_RED}󰅙${RST}" "Port Error"
        _print_status "󰅙" "Invalid port: $PORT"
        _print_footer; exit 1
    fi

    ss -tlnp | grep -q ":$PORT " && {
        _print_header "${NORD_RED}󰅙${RST}" "Port Conflict"
        _print_status "󰅙" "Port $PORT is already in use."
        _print_footer; exit 1
    }

    local CONFIG_BASE=$(basename "$CONFIG_PATH" .conf)
    local SERVICE_NAME="${CONFIG_BASE}-wgsocks"
    local CONF_DEST="$CONF_DIR/${CONFIG_BASE}.conf"

    _print_header "${NORD_CYAN}󱌣${RST}" "Installing Tunnel: $CONFIG_BASE"

    mkdir -p "$CONF_DIR"
    cp "$CONFIG_PATH" "$CONF_DEST"
    chmod 600 "$CONF_DEST"
    _print_row "󰋊" "Config" "Copied to $CONF_DIR"

    if grep -q "BindAddress" "$CONF_DEST"; then
        sed -i "s/BindAddress = .*/BindAddress = 127.0.0.1:$PORT/" "$CONF_DEST"
    else
        echo -e "\n[Socks5]\nBindAddress = 127.0.0.1:$PORT" >> "$CONF_DEST"
    fi
    _print_row "󰈀" "SOCKS5" "Bound to 127.0.0.1:$PORT"

    cat <<UNIT > /etc/systemd/system/${SERVICE_NAME}.service
[Unit]
Description=WireGuard Socks5 ($CONFIG_BASE)
After=network.target

[Service]
Type=simple
ExecStart=$BINARY_PATH -c $CONF_DEST
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

    _run "Daemon reload" systemctl daemon-reload
    _run "Enable service" systemctl enable "$SERVICE_NAME"
    _run "Start service"  systemctl restart "$SERVICE_NAME"

    _print_row "󱄄" "Service" "$SERVICE_NAME"
    _print_row "󰩟" "Port"    "$PORT"
    _print_row "󰄬" "Status"  "$(systemctl is-active "$SERVICE_NAME")"
    _print_footer
}

list_socks() {
    shopt -s nullglob
    local services=(/etc/systemd/system/*-wgsocks.service)

    _print_header "${NORD_CYAN}󰒄${RST}" "SOCKS5 Tunnels"

    if [[ ${#services[@]} -eq 0 ]]; then
        _print_status "󰋼" "No tunnels found."
        _print_footer; return
    fi

    printf "${NORD_POLAR_4}│${RST}  ${NORD_D_BLUE}%-25s %-12s %-10s${RST}\n" "SERVICE" "STATUS" "PORT"
    echo -e "${NORD_POLAR_4}├─────────────────────────────────────────────────────${RST}"

    for service in "${services[@]}"; do
        local NAME=$(basename "$service" .service)
        local STATUS=$(systemctl is-active "$NAME")
        local CONF_FILE="$CONF_DIR/${NAME%-wgsocks}.conf"
        local PORT=$(grep "BindAddress" "$CONF_FILE" 2>/dev/null | tr -d ' ' | awk -F':' '{print $NF}')
        [[ "$STATUS" == "active" ]] && S_COL="${NORD_GREEN}" || S_COL="${NORD_RED}"
        printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%-25s${RST} ${S_COL}%-12s${RST} ${NORD_SNOW_1}%s${RST}\n" \
            "$NAME" "$STATUS" "$PORT"
    done

    _print_footer
}

uninstall_socks() {
    shopt -s nullglob
    local services=(/etc/systemd/system/*-wgsocks.service)

    _print_header "${NORD_RED}󰆑${RST}" "Uninstall Tunnel"

    if [[ ${#services[@]} -eq 0 ]]; then
        _print_status "󰋼" "No tunnels found."
        _print_footer; return
    fi

    printf "${NORD_POLAR_4}│${RST}  ${NORD_D_BLUE}%-6s %-25s %-12s %-10s${RST}\n" "NO." "SERVICE" "STATUS" "PORT"
    echo -e "${NORD_POLAR_4}├─────────────────────────────────────────────────────${RST}"
    local i=1
    for service in "${services[@]}"; do
        local NAME=$(basename "$service" .service)
        local STATUS=$(systemctl is-active "$NAME")
        local CONF_FILE="$CONF_DIR/${NAME%-wgsocks}.conf"
        local PORT=$(grep "BindAddress" "$CONF_FILE" 2>/dev/null | tr -d ' ' | awk -F':' '{print $NF}')
        [[ "$STATUS" == "active" ]] && S_COL="${NORD_GREEN}" || S_COL="${NORD_RED}"
        printf "${NORD_POLAR_4}│${RST}  ${NORD_CYAN}%-6s${RST} ${NORD_BLUE}%-25s${RST} ${S_COL}%-12s${RST} ${NORD_SNOW_1}%s${RST}\n" \
            "$i" "$NAME" "$STATUS" "$PORT"
        (( i++ ))
    done

    echo ""
    printf "${NORD_POLAR_4}│${RST}  ${NORD_SNOW_1}Enter numbers to uninstall (comma separated): ${RST}"
    read -r input
    [[ -z "$input" ]] && { _print_status "󰋼" "Aborted."; _print_footer; return; }

    IFS=',' read -ra selections <<< "$input"
    local to_remove=()
    for sel in "${selections[@]}"; do
        sel=$(echo "$sel" | tr -d ' ')
        if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel >= i )); then
            _print_status "󰅙" "Invalid selection: $sel — skipping"
            continue
        fi
        to_remove+=("${services[$((sel - 1))]}")
    done

    [[ ${#to_remove[@]} -eq 0 ]] && { _print_status "󰅙" "No valid selections."; _print_footer; return; }

    echo ""
    _print_status "󰀦" "Will uninstall ${#to_remove[@]} tunnel(s):"
    for service in "${to_remove[@]}"; do
        printf "${NORD_POLAR_4}│${RST}    ${NORD_RED}󰆑${RST}  %s\n" "$(basename "$service" .service)"
    done
    echo ""
    printf "${NORD_POLAR_4}│${RST}  ${NORD_SNOW_1}Confirm? [y/N]: ${RST}"
    read -r confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && { _print_status "󰋼" "Aborted."; _print_footer; return; }

    echo ""
    local DESKTOP="$REAL_HOME/Desktop"
    mkdir -p "$DESKTOP"
    for service in "${to_remove[@]}"; do
        local NAME=$(basename "$service" .service)
        local CONF_FILE="$CONF_DIR/${NAME%-wgsocks}.conf"

        if [[ -f "$CONF_FILE" ]]; then
            cp "$CONF_FILE" "$DESKTOP/${NAME%-wgsocks}-wgsocks-backup.conf"
            _print_row "󰋊" "Backup" "$DESKTOP/${NAME%-wgsocks}-wgsocks-backup.conf"
        fi

        _run "Stop $NAME"    systemctl stop "$NAME"
        _run "Disable $NAME" systemctl disable "$NAME"
        rm -f "$service" "$CONF_FILE"
        _run "Daemon reload" systemctl daemon-reload
        _print_status "󰄬" "$NAME removed."
        echo ""
    done

    _print_footer
}

refresh_socks() {
    shopt -s nullglob
    local services=(/etc/systemd/system/*-wgsocks.service)

    _print_header "${NORD_CYAN}󰑮${RST}" "Refreshing Tunnels"

    if [[ ${#services[@]} -eq 0 ]]; then
        _print_status "󰋼" "No tunnels found."
        _print_footer; return
    fi

    for service in "${services[@]}"; do
        local NAME=$(basename "$service" .service)
        _run "Restart $NAME" systemctl restart "$NAME"
    done

    _print_footer
}

# --- Router ---
case "$1" in
    install)   install_socks "$2" "$3" ;;
    list)      list_socks ;;
    uninstall) uninstall_socks ;;
    refresh)   refresh_socks ;;
    *)
        _print_header "${NORD_CYAN}󰒄${RST}" "WireGuard SOCKS5 Manager"
        printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%-12s${RST} ${NORD_SNOW_1}%s${RST}\n" "install"   "<conf> <port>  Install new tunnel"
        printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%-12s${RST} ${NORD_SNOW_1}%s${RST}\n" "list"      "               List all tunnels"
        printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%-12s${RST} ${NORD_SNOW_1}%s${RST}\n" "uninstall" "               Uninstall tunnel(s)"
        printf "${NORD_POLAR_4}│${RST}  ${NORD_BLUE}%-12s${RST} ${NORD_SNOW_1}%s${RST}\n" "refresh"   "               Restart all tunnels"
        _print_footer
        exit 1
        ;;
esac
