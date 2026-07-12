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
    echo -e "\n${NORD_CYAN}${1}${NORD_SNOW_1}${2}${RST}"
    echo -e "${NORD_POLAR_4}─────────────────────────────────────────────────────${RST}"
}

_print_status() {
    local color
    case "$1" in
        "success") color=$NORD_GREEN  ;;
        "error")   color=$NORD_RED    ;;
        "warning") color=$NORD_YELLOW ;;
        "info")    color=$NORD_POLAR_4 ;;
        *)         color=$NORD_BLUE    ;;
    esac
    echo -e "${color}${2}${RST}"
}

_print_result() {
    local code=$1; shift
    _print_status "$([ "$code" -eq 0 ] && echo "success" || echo "error")" "$*"
}

_test_dependencies() {
    local missing=() cmd
    for cmd in "$@"; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        _print_status "error" "Missing dependencies: ${missing[*]}"
        return 1
    fi
    return 0
}
