#!/bin/bash

# ==============================================================================
# TIMER  (Nord Aesthetic + Big Digits)
# ==============================================================================

# Nord Colors
NORD_POLAR_4=$'\e[38;2;76;86;106m'
NORD_SNOW_1=$'\e[38;2;216;222;233m'
NORD_CYAN=$'\e[38;2;143;188;187m'
NORD_BLUE=$'\e[38;2;136;192;208m'
NORD_GREEN=$'\e[38;2;163;190;140m'
NORD_RED=$'\e[38;2;191;97;106m'
NORD_ORANGE=$'\e[38;2;208;135;112m'
NORD_DIM=$'\e[38;5;240m'
RST=$'\e[0m'

# ==============================================================================
# BIG DIGITS  (5 rows tall)
# ==============================================================================

declare -A DIGITS

DIGITS[0]=' ██████ 
██    ██
██    ██
██    ██
 ██████ '

DIGITS[1]='   ██   
 ████   
   ██   
   ██   
 ██████ '

DIGITS[2]=' ██████ 
     ██ 
 ██████ 
██      
 ██████ '

DIGITS[3]=' ██████ 
     ██ 
  █████ 
     ██ 
 ██████ '

DIGITS[4]='██    ██
██    ██
 ███████
      ██
      ██'

DIGITS[5]=' ██████ 
██      
 ██████ 
     ██ 
 ██████ '

DIGITS[6]=' ██████ 
██      
███████ 
██    ██
 ██████ '

DIGITS[7]=' ██████ 
     ██ 
    ██  
   ██   
   ██   '

DIGITS[8]=' ██████ 
██    ██
 ██████ 
██    ██
 ██████ '

DIGITS[9]=' ██████ 
██    ██
 ███████
      ██
 ██████ '

DIGITS[:]='   
 █ 
   
 █ 
   '

DIGITS[' ']='   
   
   
   
   '

# ==============================================================================
# HELPERS
# ==============================================================================

_big_text_rows() {
    local text="$1"
    local rows=("" "" "" "" "")
    local i ch glyph

    for (( i=0; i<${#text}; i++ )); do
        ch="${text:$i:1}"
        [[ "$ch" == " " ]] && ch=' '

        if [[ -v "DIGITS[$ch]" ]]; then
            glyph="${DIGITS[$ch]}"
        else
            glyph="${DIGITS[' ']}"
        fi

        local r=0
        while IFS= read -r line; do
            rows[$r]+="$line "
            (( r++ ))
        done <<< "$glyph"
    done

    printf '%s\n' "${rows[@]}"
}

_parse_duration() {
    local raw="$1"
    local total=0 found=0

    if [[ -z "$raw" || ! "$raw" =~ ^[0-9] ]]; then
        echo -1; return
    fi

    while [[ "$raw" =~ ([0-9]+)([hms]) ]]; do
        local num="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"
        case "$unit" in
            h) (( total += num * 3600 )) ;;
            m) (( total += num * 60   )) ;;
            s) (( total += num        )) ;;
        esac
        found=1
        raw="${raw#*${BASH_REMATCH[0]}}"
    done

    [[ $found -eq 0 ]] && echo -1 || echo $total
}

_format_duration() {
    local secs=$1
    local h=$(( secs / 3600 ))
    local m=$(( (secs % 3600) / 60 ))
    local s=$(( secs % 60 ))

    if (( h > 0 )); then
        printf "%d:%02d:%02d" $h $m $s
    else
        printf "%02d:%02d" $m $s
    fi
}

_progress_bar() {
    local remaining=$1 total=$2 width=$3
    local filled=0 empty=0

    if (( total > 0 )); then
        filled=$(( (total - remaining) * width / total ))
    else
        filled=$width
    fi
    empty=$(( width - filled ))

    local bar="" i
    for (( i=0; i<filled; i++ )); do bar+="█"; done
    for (( i=0; i<empty;  i++ )); do bar+="░"; done
    printf '%s' "$bar"
}

_write_at() {
    local x=$1 y=$2 text="$3"
    printf '\e[%d;%dH%s' $(( y+1 )) $(( x+1 )) "$text"
}

_term_size() {
    read -r LINES COLUMNS < <(stty size 2>/dev/null || echo "24 80")
}

_center_x() {
    local text_len=$1 width=$2
    echo $(( (width - text_len) / 2 ))
}

_pad_line() {
    local pad=$1 text="$2" tail=$3
    printf '%*s%s%*s' "$pad" "" "$text" "$tail" ""
}

# ==============================================================================
# DRAW
# ==============================================================================

_draw_static() {
    local w=$1 h=$2 label="$3" start_row=$4 hint_row=$5

    printf '\e[2J'

    local label_line="  󰔛  $label"
    local label_len=${#label_line}
    local lpad=$(( (w - label_len) / 2 ))
    local ltail=$(( w - lpad - label_len ))
    _write_at 0 $(( start_row - 2 )) "$(printf '%*s' "$lpad" "")${NORD_DIM}${label_line}${RST}$(printf '%*s' "$ltail" "")"

    local hint="Ctrl+C to cancel"
    local hint_len=${#hint}
    local hpad=$(( (w - hint_len) / 2 ))
    local htail=$(( w - hpad - hint_len ))
    _write_at 0 "$hint_row" "$(printf '%*s' "$hpad" "")${NORD_DIM}${hint}${RST}$(printf '%*s' "$htail" "")"
}

_draw_dynamic() {
    local remaining=$1 total=$2 w=$3 start_row=$4 bar_row=$5 pct_row=$6

    local pct=$(( total > 0 ? (total - remaining) * 100 / total : 100 ))
    local time_str
    time_str=$(_format_duration "$remaining")
    local bar_width=$(( w - 8 < 20 ? 20 : w - 8 ))

    # Colors based on remaining time
    local time_color bar_color
    if (( remaining <= 10 )); then
        time_color="${NORD_RED}"
        bar_color="${NORD_RED}"
    elif (( remaining <= 60 )); then
        time_color="${NORD_ORANGE}"
        bar_color="${NORD_ORANGE}"
    else
        time_color="${NORD_GREEN}"
        bar_color="${NORD_BLUE}"
    fi

    # Big digits
    local rows_str
    rows_str=$(_big_text_rows "$time_str")
    mapfile -t rows <<< "$rows_str"
    # rows has 10 lines (5 from each call) — take only 5
    local row_width=${#rows[0]}
    local tpad=$(( (w - row_width) / 2 ))
    local r
    for (( r=0; r<5; r++ )); do
        local tail=$(( w - tpad - ${#rows[$r]} ))
        _write_at 0 $(( start_row + r )) "$(printf '%*s' "$tpad" "")${time_color}${rows[$r]}${RST}$(printf '%*s' "$tail" "")"
    done

    # Progress bar
    local bar
    bar=$(_progress_bar "$remaining" "$total" "$bar_width")
    local bar_line="  ${bar}  "
    local bar_line_len=$(( bar_width + 4 ))
    local bpad=$(( (w - bar_line_len) / 2 ))
    local btail=$(( w - bpad - bar_line_len ))
    _write_at 0 "$bar_row" "$(printf '%*s' "$bpad" "")${bar_color}${bar_line}${RST}$(printf '%*s' "$btail" "")"

    # Percentage
    local pct_str="${pct}%"
    local ppad=$(( (w - ${#pct_str}) / 2 ))
    local ptail=$(( w - ppad - ${#pct_str} ))
    _write_at 0 "$pct_row" "$(printf '%*s' "$ppad" "")${NORD_DIM}${pct_str}${RST}$(printf '%*s' "$ptail" "")"
}

# ==============================================================================
# MAIN
# ==============================================================================

if [[ -z "$1" ]]; then
    echo ""
    echo -e "${NORD_CYAN}󰔛  Usage: timer <duration>${RST}"
    echo -e "${NORD_POLAR_4}─────────────────────────────────────────────────────${RST}"
    echo -e "${NORD_DIM}   Examples:  30s   5m   1h   1h30m   2h15m30s${RST}"
    echo -e "${NORD_POLAR_4}─────────────────────────────────────────────────────${RST}"
    echo ""
    exit 1
fi

total_secs=$(_parse_duration "$1")
if (( total_secs <= 0 )); then
    echo -e "${NORD_RED}󰅙  Invalid duration '$1'. Examples: 30s  5m  1h  1h30m${RST}"
    exit 1
fi

# Enter alternate screen buffer, hide cursor
printf '\e[?1049h'
printf '\e[?25l'

remaining=$total_secs
last_w=0
last_h=0
start_row=0
bar_row=0
pct_row=0
hint_row=0

_cleanup() {
    printf '\e[?25h'   # show cursor
    printf '\e[?1049l' # exit alternate screen
    exit 0
}
trap _cleanup INT TERM EXIT

while (( remaining >= 0 )); do
    _term_size
    w=$COLUMNS
    h=$LINES

    if [[ "$w" != "$last_w" || "$h" != "$last_h" ]]; then
        mid=$(( h / 2 - 2 ))
        start_row=$mid
        bar_row=$(( mid + 7 ))
        pct_row=$(( mid + 9 ))
        hint_row=$(( mid + 11 ))

        _draw_static "$w" "$h" "$1" "$start_row" "$hint_row"
        last_w=$w
        last_h=$h
    fi

    _draw_dynamic "$remaining" "$total_secs" "$w" "$start_row" "$bar_row" "$pct_row"

    (( remaining == 0 )) && break
    sleep 1
    (( remaining-- ))
done

# Done screen
printf '\e[2J'
_term_size
w=$COLUMNS
h=$LINES
mid=$(( h / 2 ))

done_msg="󰄬  Timer complete!"
done_pad=$(( (w - ${#done_msg}) / 2 ))
_write_at "$done_pad" $(( mid - 1 )) "${NORD_GREEN}${done_msg}${RST}"

sub_str=$(_format_duration "$total_secs")
sub_pad=$(( (w - ${#sub_str}) / 2 ))
_write_at "$sub_pad" $(( mid + 1 )) "${NORD_DIM}${sub_str}${RST}"

# Beep sequence — try paplay/pw-play, fall back to terminal bell
_beep() {
    if command -v paplay &>/dev/null; then
        paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null &
    elif command -v pw-play &>/dev/null; then
        pw-play /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null &
    else
        printf '\a'
    fi
}
_beep; sleep 0.3; _beep; sleep 0.3; _beep

sleep 2