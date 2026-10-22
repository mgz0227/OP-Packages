# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2025 ImmortalWrt.org

HP_FW4_CHAINS="
	homeproxy_output_redir
	homeproxy_redirect
	homeproxy_redirect_proxy
	homeproxy_redirect_proxy_port
	homeproxy_redirect_lanac
	homeproxy_mangle_prerouting
	homeproxy_mangle_output
	homeproxy_mangle_tproxy
	homeproxy_mangle_tproxy_port
	homeproxy_mangle_lanac
	homeproxy_mangle_mark
	homeproxy_mangle_tun
	homeproxy_mangle_tun_mark
"

HP_FW4_SETS="
	homeproxy_local_addr_v4
	homeproxy_local_addr_v6
	homeproxy_gfw_list_v4
	homeproxy_gfw_list_v6
	homeproxy_mainland_addr_v4
	homeproxy_mainland_addr_v6
	homeproxy_wan_proxy_addr_v4
	homeproxy_wan_proxy_addr_v6
	homeproxy_wan_direct_addr_v4
	homeproxy_wan_direct_addr_v6
	homeproxy_routing_port
"
