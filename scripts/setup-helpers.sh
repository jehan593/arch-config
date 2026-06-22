COLOR_GRAY='\e[90m'
COLOR_WHITE='\e[97m'
COLOR_CYAN='\e[36m'
COLOR_BLUE='\e[34m'
COLOR_GREEN='\e[32m'
COLOR_RED='\e[31m'
COLOR_YELLOW='\e[33m'
RST='\e[0m'

_print_header() {
    echo -e "\n ${COLOR_CYAN}:: ${COLOR_WHITE}${2}${RST}"
    echo -e " ${COLOR_GRAY}─────────────────────────────────────────────────────${RST}"
}

_print_status() {
    local symbol="$1"
    local color=$COLOR_BLUE
    if [[ "$symbol" == "󰄬" || "$symbol" == "[+]" ]]; then
        color=$COLOR_GREEN
        symbol="[+]"
    elif [[ "$symbol" == "󰅙" || "$symbol" == "[!]" ]]; then
        color=$COLOR_RED
        symbol="[!]"
    elif [[ "$symbol" == "󰀦" || "$symbol" == "[*]" || "$symbol" == "󰋼" ]]; then
        color=$COLOR_YELLOW
        symbol="[*]"
    fi
    echo -e " ${color}${symbol}${RST}  ${COLOR_WHITE}${2}${RST}"
}

ok()   { _print_status "[+]" "$1"; }
err()  { _print_status "[!]" "$1"; }
info() { _print_status "[*]" "$1"; }