#!/bin/bash

# Timer

source "$HOME/arch-config/scripts/helpers.sh"

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

    while [[ "$raw" =~ ([0-9]+\.?[0-9]*)([hms]) ]]; do
        local num="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"
        local secs
        case "$unit" in
            h) secs=$(awk "BEGIN { printf \"%d\", $num * 3600 + 0.5 }") ;;
            m) secs=$(awk "BEGIN { printf \"%d\", $num * 60   + 0.5 }") ;;
            s) secs=$(awk "BEGIN { printf \"%d\", $num        + 0.5 }") ;;
        esac
        (( total += secs ))
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

# Centers raw `text` across full width `w` at row `row`, wrapped in `color`.
# Padding on both sides is written so the line fully overwrites any
# previous (wider) content on redraw.
# Usage: _write_centered <w> <row> <text> <color>
_write_centered() {
    local w=$1 row=$2 text="$3" color="$4"
    local len=${#text}
    local pad=$(( (w - len) / 2 ))
    local tail=$(( w - pad - len ))
    _write_at 0 "$row" "$(printf '%*s' "$pad" "")${color}${text}${RST}$(printf '%*s' "$tail" "")"
}

_draw_static() {
    local w=$1 h=$2 label="$3" start_row=$4 hint_row=$5

    printf '\e[2J'

    local label_line="  󰔛  $label"
    _write_centered "$w" $(( start_row - 2 )) "$label_line" "${NORD_DIM}"

    local hint="Space/P: Pause · Ctrl+C: Cancel"
    _write_centered "$w" "$hint_row" "$hint" "${NORD_DIM}"
}

_draw_dynamic() {
    local remaining=$1 total=$2 w=$3 start_row=$4 bar_row=$5 pct_row=$6 paused=$7

    local pct=$(( total > 0 ? (total - remaining) * 100 / total : 100 ))
    local time_str
    time_str=$(_format_duration "$remaining")
    local bar_width=$(( w - 8 < 20 ? 20 : w - 8 ))

    local time_color bar_color
    if [[ "$paused" == "1" ]]; then
        time_color="${NORD_YELLOW}"
        bar_color="${NORD_YELLOW}"
    elif (( remaining <= 10 )); then
        time_color="${NORD_RED}"
        bar_color="${NORD_RED}"
    elif (( remaining <= 60 )); then
        time_color="${NORD_ORANGE}"
        bar_color="${NORD_ORANGE}"
    else
        time_color="${NORD_GREEN}"
        bar_color="${NORD_BLUE}"
    fi

    local rows_str
    rows_str=$(_big_text_rows "$time_str")
    mapfile -t rows <<< "$rows_str"
    local row_width=${#rows[0]}
    local tpad=$(( (w - row_width) / 2 ))
    local r
    for (( r=0; r<5; r++ )); do
        local tail=$(( w - tpad - ${#rows[$r]} ))
        _write_at 0 $(( start_row + r )) "$(printf '%*s' "$tpad" "")${time_color}${rows[$r]}${RST}$(printf '%*s' "$tail" "")"
    done

    local bar
    bar=$(_progress_bar "$remaining" "$total" "$bar_width")
    local bar_line="  ${bar}  "
    _write_centered "$w" "$bar_row" "$bar_line" "${bar_color}"

    local pct_str
    if [[ "$paused" == "1" ]]; then
        pct_str="󰏤  Paused"
    else
        pct_str="${pct}%"
    fi
    _write_centered "$w" "$pct_row" "$pct_str" "${NORD_DIM}"
}

if [[ -z "$1" ]]; then
    echo -e "\n ${NORD_CYAN}󰔛  Usage: timer <duration>${RST}"
    echo -e " ${NORD_POLAR_4}─────────────────────────────────────────────────────${RST}"
    echo -e "  ${NORD_SNOW_1}Examples: 30s, 5m, 1h, 1h30m${RST}"
    echo -e " ${NORD_POLAR_4}─────────────────────────────────────────────────────${RST}\n"
    exit 1
fi

total_secs=$(_parse_duration "$1")
if (( total_secs <= 0 )); then
    echo -e " ${NORD_RED}󰅙  Invalid duration: $1${RST}"
    exit 1
fi

printf '\e[?1049h'
printf '\e[?25l'

stty_save=$(stty -g)
stty -echo -icanon min 0 time 0

remaining=$total_secs
paused=0
last_w=0
last_h=0
start_row=0
bar_row=0
pct_row=0
hint_row=0

_cleanup() {
    stty "$stty_save"
    printf '\e[?25h'
    printf '\e[?1049l'
    exit 0
}
trap _cleanup INT TERM EXIT

_check_resize() {
    local label="$1"
    _term_size
    w=$COLUMNS
    h=$LINES

    if [[ "$w" != "$last_w" || "$h" != "$last_h" ]]; then
        mid=$(( h / 2 - 2 ))
        start_row=$mid
        bar_row=$(( mid + 7 ))
        pct_row=$(( mid + 9 ))
        hint_row=$(( mid + 11 ))

        _draw_static "$w" "$h" "$label" "$start_row" "$hint_row"
        _draw_dynamic "$remaining" "$total_secs" "$w" "$start_row" "$bar_row" "$pct_row" "$paused"
        last_w=$w
        last_h=$h
        return 0
    fi
    return 1
}

while (( remaining >= 0 )); do
    _check_resize "$1" || _draw_dynamic "$remaining" "$total_secs" "$w" "$start_row" "$bar_row" "$pct_row" "$paused"

    (( remaining == 0 && paused == 0 )) && break

    ticks=0
    while (( ticks < 10 )); do
        key=""
        IFS= read -r -s -n1 -t 0.1 key || true
        if [[ "$key" == " " || "$key" == "p" || "$key" == "P" ]]; then
            if [[ "$paused" == "0" ]]; then
                paused=1
            else
                paused=0
            fi
            _draw_dynamic "$remaining" "$total_secs" "$w" "$start_row" "$bar_row" "$pct_row" "$paused"
        fi
        _check_resize "$1"
        [[ "$paused" == "0" ]] && (( ticks++ )) || true
    done

    [[ "$paused" == "0" ]] && (( remaining-- )) || true
done

stty "$stty_save"

printf '\e[2J'
_term_size
w=$COLUMNS
h=$LINES
mid=$(( h / 2 ))

done_msg="󰄬  Finished"
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