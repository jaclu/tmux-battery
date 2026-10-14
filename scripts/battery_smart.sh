#!/usr/bin/env bash
#  shellcheck disable=SC1091
#  Directives for shellcheck directly after bang path are global
#
#   Copyright (c) 2021,2022,2024: Jacob.Lundqvist@gmail.com
#   License: MIT
#
#   Part of https://github.com/jaclu/tmux-battery
#
#   Version: 1.2.0 2024-09-04
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
    if [[ -z "$log_file" ]]; then
        return
    fi
    printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$@" >>"$log_file"
}

is_aldente() {
    # ensures the charge limit is defined and AlDente is running
    [[ -n $aldente_charge_limit ]] && pgrep AlDente >/dev/null
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
        cat "$f_cached_result"
        exit 0
    else
        # cache miss
        rm -f "$f_cached_result"
    fi
}

clear_battery_status() {
    log_it "><> clear_battery_status()"
    echo "" >"$f_cached_result"
}

check_status() {
    local status
    local percentage
    local aldente_ok_level
    local icon_status
    local color_bg
    local remain

    status=$(battery_status)
    icon_status=$(print_icon_status "$status")
    percentage="$("$CURRENT_DIR"/battery_percentage.sh | sed -e 's/%//')"

    is_aldente && {
        aldente_ok_level="${aldente_sailing_floor:-aldente_charge_limit}"
        if [[ $percentage -gt $aldente_charge_limit ]]; then
            case $status in
                charging*) icon_status+='🔺' ;;
                *attached*) icon_status='🔌🔻' ;;
                *) icon_status+='🔻' ;;
            esac
        elif [[ $percentage -ge $aldente_ok_level && $status != discharging ]]; then
            clear_battery_status
            return
        fi
    }

    log_it "><> status[$status] percentage[$percentage] icon_status[$icon_status]"

    if [[ $status != discharging && $percentage -ge 98 ]]; then
        # If almost full or better and plugged in, we do not need to see
        # details about battery state.
        clear_battery_status
    else
        log_it "><> will display smart status"
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

CURRENT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
PLUGIN_DIR=$(dirname "$CURRENT_DIR")

# This script may be triggered frequently, potentially every 5 seconds or less.
# On slower systems, this frequent execution can lead to noticeable delays
# due to the script’s substantial processing requirements.
# To improve responsiveness and reduce system load, a cached result is used
# to limit full processing to once every 30 seconds.
# This approach roughly reduces the runtime by a factor of twenty on a cache hit.

f_cached_result="$PLUGIN_DIR"/smart_status.cache
cache_max_age=30 # seconds

aldente_charge_limit=80
aldente_sailing_floor=75 # optional - if Aldente Sailing Mode is used...

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
