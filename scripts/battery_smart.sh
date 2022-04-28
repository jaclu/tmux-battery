#!/usr/bin/env bash
#  shellcheck disable=SC1091
#  Directives for shellcheck directly after bang path are global
#
#   Copyright (c) 2021,2022: Jacob.Lundqvist@gmail.com
#   License: MIT
#
#   Part of https://github.com/jaclu/tmux-battery
#
#   Version: 1.1.0 2022-04-13
#

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# shellcheck disable=SC1091
source "$CURRENT_DIR/helpers.sh"
source "$CURRENT_DIR/battery_icon_status.sh"  > /dev/null
source "$CURRENT_DIR/battery_percentage.sh"  > /dev/null
source "$CURRENT_DIR/battery_color_charge.sh" > /dev/null
source "$CURRENT_DIR/battery_remain.sh" > /dev/null
#short=false


main() {
	#get_icon_status_settings
	local color_bg
	local percentage
	local status
	local icon_status
	local remain

	status=$(battery_status)
	percentage="$("$CURRENT_DIR"/battery_percentage.sh | sed -e 's/%//')"
	icon_status=$(print_icon_status "$status")

	if [ "$status" != "discharging" ] && [ "$percentage" -ge 98 ]; then
		# If almost full or better and plugged in, we do not need to see
		# details about battery. An icon indicating power is plugged in,
		# should be enough
		printf "%s" "$icon_status"
	else
		#  Variables only retrieved when needed, in order to cut down overhead
		color_bg="$(print_color_charge bg)"
		remain=$(print_battery_remain)
		printf "%s" "${color_bg}$icon_status ${percentage} ${remain}#[default]"
	fi
}

main
