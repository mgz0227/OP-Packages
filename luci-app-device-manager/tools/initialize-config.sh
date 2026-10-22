#!/bin/sh
# SPDX-License-Identifier: MIT
set -e

# Existing configuration, including an intentionally empty file, is authoritative.
# Development deployment only; packages ship /etc/config/device_manager directly.
[ -e /etc/config/device_manager ] && exit 0

touch /etc/config/device_manager
trap 'uci -q revert device_manager || :; rm -f /etc/config/device_manager' EXIT
uci -q batch <<'EOF'
set device_manager.smart_home=group
set device_manager.smart_home.name='Smart home'
set device_manager.phone=group
set device_manager.phone.name='Phones'
set device_manager.computer=group
set device_manager.computer.name='Computers'
set device_manager.network=group
set device_manager.network.name='Network devices'
set device_manager.other=group
set device_manager.other.name='Other devices'
commit device_manager
EOF
trap - EXIT
