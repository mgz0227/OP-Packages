#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2023 ImmortalWrt.org

SCRIPTS_DIR="/etc/homeproxy/scripts"

changed=0
for i in "china_ip4" "china_ip6" "gfw_list" "china_list" "geoip_cn" "geosite_cn"; do
	"$SCRIPTS_DIR"/update_resources.sh "$i"
	[ "$?" -eq 0 ] && changed=1
done

[ "$changed" -eq 0 ] || /etc/init.d/homeproxy refresh_lists

"$SCRIPTS_DIR"/update_subscriptions.uc
