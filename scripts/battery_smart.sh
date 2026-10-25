#!/usr/bin/env bash
#  shellcheck disable=SC1091
#  Directives for shellcheck directly after bang path are global
#
#   Copyright (c) 2021,2022,2024,2026: Jacob.Lundqvist@gmail.com
#   License: MIT
#
#   Part of https://github.com/jaclu/tmux-battery
#

#
#  If log_file is undefined, no logging will occur,
#  so comment it out for normal usage.
#
# log_file=~/tmp/tmux-battery.log

#
#  If $log_file is empty or undefined, no logging will occur.
#
log_it() {
    [[ -n "$log_file" ]] || return
    printf "[%s][%s] %s\n" "$(date '+%H:%M:%S')" "$$" "$@" >>"$log_file"
}

is_aldente() {
    # ensures the charge limit is defined and AlDente is running
    [[ -n $aldente_charge_limit ]] && pgrep AlDente >/dev/null
}

detect_charge_limit() {
    #
    # Currently can only detect charge limit on MacOS
    #
    # Provides:
    #   chargge_limit - if it could be detected and func returns true
    #
    local status

    [[ "$(uname -s)" == "Darwin" ]] || return 1
    status=$(pmset -g battlimit 2>/dev/null) || return 1
    case $status in
        *"No battery level limits set"*) return 1 ;; # "no limit"
        *) ;;
    esac
    charge_limit=$(
        printf '%s\n' "$status" \
            | sed -n 's/.*chargeSocLimitSoc[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/\1/p' \
            | sort -n | head -n 1
    )
    return 0
}

cache_check() {
    [[ -f $f_cached_result ]] || return

    local current_time
    local file_mod_time
    local time_diff

    # if one assignment fails, try the next one...
    file_mod_time=$(
        # date -r should normally work and is faster than stat
        date -r "$f_cached_result" +%s 2>/dev/null
    ) || file_mod_time=$( # GNU/Linux fallback
        stat -c %Y "$f_cached_result" 2>/dev/null
    ) || file_mod_time=$( # BSD & Darwin fallback
        stat -f %m "$f_cached_result" 2>/dev/null
    ) || file_mod_time=0 # invalidate cache by setting a zero timestamp

    current_time=$(date +%s)
    time_diff=$((current_time - file_mod_time))
    if ((time_diff < cache_max_age)); then
        # log_it "Using cached result"
        cat "$f_cached_result"
        exit 0
    else
        # cache miss
        rm -f "$f_cached_result"
    fi
}

clear_battery_status() {
    log_it "clear_battery_status()"
    echo "" >"$f_cached_result"
}

check_status() {
    local status
    local icon_status
    local percentage
    local charge_limit charge_ok_level
    local color_bg
    local remain

    status=$(battery_status)
    icon_status=$(print_icon_status "$status")
    percentage="$("$CURRENT_DIR"/battery_percentage.sh | sed -e 's/%//')"

    if is_aldente; then
        charge_limit="$aldente_charge_limit"
        if [[ -n $aldente_sailing_floor ]]; then
            charge_ok_level="$aldente_sailing_floor"
            log_it "Using AlDente charge limits: $charge_ok_level - $charge_limit"
        else
            charge_ok_level="$charge_limit"
            log_it "Using AlDente charge limit: $charge_limit"
        fi
    elif detect_charge_limit; then
        # basic charge_limit does not offer a span of valid levels
        charge_ok_level="$charge_limit"
        log_it "Using MacOS charge limit: $charge_limit"
    fi
    [[ -n $charge_limit ]] && {
        if [[ $percentage -gt $charge_limit ]]; then
            case $status in
                charging* | charged) icon_status+='🔺' ;;
                *attached*) icon_status='🔌🔻' ;;
                *) icon_status+='🔻' ;;
            esac
        elif [[ $percentage -ge $charge_ok_level && $status != discharging ]]; then
            clear_battery_status
            return
        fi
    }

    log_it "status[$status] percentage[$percentage] icon_status[$icon_status]"
    if [[ $status != discharging && $percentage -ge 98 ]]; then
        # If almost full and plugged in: no need to see details about battery state.
        clear_battery_status
    else
        color_bg=$(print_color_charge bg)
        remain=$(print_battery_remain)
        printf "%s" "${color_bg}$icon_status ${percentage} ${remain}#[default] " \
            >"$f_cached_result"
    fi
}

#===============================================================
#
#   Main
#
#===============================================================

# This script may be triggered frequently, potentially every 5 seconds or less.
# On slower systems, this frequent execution can lead to noticeable delays
# due to the script’s substantial processing requirements.
# To improve responsiveness and reduce system load, a cached result is used
# to limit full processing to once every 30 seconds.
# This approach roughly reduces the runtime by a factor of twenty on a cache hit.

CURRENT_DIR=$(cd "${0%/*}/" && pwd)
PLUGIN_DIR=$(dirname "$CURRENT_DIR")

f_cached_result="$PLUGIN_DIR"/.cache.smart_status
cache_max_age=30 # seconds

# If AlDente is used, its limits needs to be set manually
aldente_charge_limit=80
aldente_sailing_floor=75 # optional - if Aldente Sailing Mode is used

cache_check

# If the cache did not handle the request, proceed with recalculating...

# shellcheck source=/dev/null
source "$CURRENT_DIR"/helpers.sh

# shellcheck source=/dev/null
source "$CURRENT_DIR"/battery_icon_status.sh >/dev/null
# shellcheck source=/dev/null
source "$CURRENT_DIR"/battery_percentage.sh >/dev/null
# shellcheck source=/dev/null
source "$CURRENT_DIR"/battery_color_charge.sh >/dev/null
# shellcheck source=/dev/null
source "$CURRENT_DIR"/battery_remain.sh >/dev/null
#short=false

check_status
cat "$f_cached_result"
