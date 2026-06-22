NORD_POLAR_4=$'\e[38;2;76;86;106m'
NORD_SNOW_1=$'\e[38;2;216;222;233m'
NORD_CYAN=$'\e[38;2;143;188;187m'
NORD_BLUE=$'\e[38;2;136;192;208m'
NORD_D_BLUE=$'\e[38;2;129;161;193m'
NORD_RED=$'\e[38;2;191;97;106m'
NORD_ORANGE=$'\e[38;2;208;135;112m'
NORD_YELLOW=$'\e[38;2;235;203;139m'
NORD_GREEN=$'\e[38;2;163;190;140m'
NORD_MAGENTA=$'\e[38;2;180;142;173m'
NORD_DIM=$'\e[38;5;240m'
RST=$'\e[0m'

_print_header() {
    echo -e "\n ${NORD_CYAN}${1}  ${NORD_SNOW_1}${2}${RST}"
    echo -e " ${NORD_POLAR_4}─────────────────────────────────────────────────────${RST}"
}

_print_status() {
    local color=$NORD_BLUE
    [[ "$1" == "󰄬" ]] && color=$NORD_GREEN
    [[ "$1" == "󰅙" ]] && color=$NORD_RED
    [[ "$1" == "󰀦" ]] && color=$NORD_ORANGE
    echo -e " ${color}${1}  ${NORD_SNOW_1}${2}${RST}"
}

_print_result() {
    local code=$1; shift
    _print_status "$([ "$code" -eq 0 ] && echo 󰄬 || echo 󰅙)" "$*"
}

_print_pkg_line() {
    local pkg=$(awk '{print $1}' <<< "$1")
    local ver=$(awk '{$1=""; print $0}' <<< "$1" | xargs)
    printf "  ${NORD_GREEN}%-35s${RST} ${NORD_SNOW_1}%s${RST}\n" "$pkg" "$ver"
}