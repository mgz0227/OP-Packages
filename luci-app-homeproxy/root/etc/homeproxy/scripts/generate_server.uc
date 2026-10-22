#!/usr/bin/ucode
/*
 * SPDX-License-Identifier: GPL-2.0-only
 *
 * Copyright (C) 2023 ImmortalWrt.org
 */

'use strict';

import { writefile } from 'fs';
import { cursor } from 'uci';

import {
	strToBool, strToInt, strToTime,
	removeBlankAttrs, buildTLSObject, buildTransportObject, HP_DIR, RUN_DIR
} from 'homeproxy';

const uci = cursor();

const uciconfig = 'homeproxy';
uci.load(uciconfig);

const uciserver = 'server';

const log_level = uci.get(uciconfig, uciserver, 'log_level') || 'warn';

const config = {};

config.log = {
	disabled: false,
	level: log_level,
	output: RUN_DIR + '/sing-box-s.log',
	timestamp: true
};

config.inbounds = [];

uci.foreach(uciconfig, uciserver, (cfg) => {
	if (cfg.enabled !== '1')
		return;

	if (cfg.type === 'snell') {
		push(config.inbounds, {
			type: 'snell',
			tag: 'cfg-' + cfg['.name'] + '-in',

			listen: cfg.address || '::',
			listen_port: strToInt(cfg.port),
			bind_interface: cfg.bind_interface,
			reuse_addr: strToBool(cfg.reuse_addr),
			tcp_fast_open: strToBool(cfg.tcp_fast_open),
			tcp_multi_path: strToBool(cfg.tcp_multi_path),
			version: strToInt(cfg.snell_version) || 5,
			psk: cfg.password,
			obfs_mode: cfg.snell_obfs_mode,
			mode: cfg.snell_mode
		});
		return;
	}

	push(config.inbounds, {
		type: cfg.type,
		tag: 'cfg-' + cfg['.name'] + '-in',

		listen: cfg.address || '::',
		listen_port: strToInt(cfg.port),
		bind_interface: cfg.bind_interface,
		reuse_addr: strToBool(cfg.reuse_addr),
		tcp_fast_open: strToBool(cfg.tcp_fast_open),
		tcp_multi_path: strToBool(cfg.tcp_multi_path),
		udp_fragment: strToBool(cfg.udp_fragment),
		udp_timeout: strToTime(cfg.udp_timeout),
		network: cfg.network,

		padding_scheme: cfg.anytls_padding_scheme,

		up_mbps: strToInt(cfg.hysteria_up_mbps),
		down_mbps: strToInt(cfg.hysteria_down_mbps),
		obfs: cfg.hysteria_obfs_type ? {
			type: cfg.hysteria_obfs_type,
			password: cfg.hysteria_obfs_password,
			min_packet_size: strToInt(cfg.hysteria_obfs_min_packet_size),
			max_packet_size: strToInt(cfg.hysteria_obfs_max_packet_size)
		} : cfg.hysteria_obfs_password,
		ignore_client_bandwidth: strToBool(cfg.hysteria_ignore_client_bandwidth),
		masquerade: cfg.hysteria_masquerade,

		method: (cfg.type === 'shadowsocks') ? cfg.shadowsocks_encrypt_method : null,
		password: (cfg.type in ['shadowsocks', 'shadowtls']) ? cfg.password : null,

		congestion_control: cfg.tuic_congestion_control,
		auth_timeout: strToTime(cfg.tuic_auth_timeout),
		zero_rtt_handshake: strToBool(cfg.tuic_enable_zero_rtt),
		heartbeat: strToTime(cfg.tuic_heartbeat),

		users: (cfg.type !== 'shadowsocks') ? [
			{
				name: !(cfg.type in ['http', 'mixed', 'naive', 'socks']) ? 'cfg-' + cfg['.name'] + '-server' : null,
				username: cfg.username,
				password: cfg.password,

				auth: (cfg.hysteria_auth_type === 'base64') ? cfg.hysteria_auth_payload : null,
				auth_str: (cfg.hysteria_auth_type === 'string') ? cfg.hysteria_auth_payload : null,

				uuid: cfg.uuid,

				flow: cfg.vless_flow,
				alterId: strToInt(cfg.vmess_alterid)
			}
		] : null,

		multiplex: (cfg.multiplex === '1') ? {
			enabled: true,
			padding: strToBool(cfg.multiplex_padding),
			brutal: (cfg.multiplex_brutal === '1') ? {
				enabled: true,
				up_mbps: strToInt(cfg.multiplex_brutal_up),
				down_mbps: strToInt(cfg.multiplex_brutal_down)
			} : null
		} : null,

		tls: buildTLSObject(cfg, true),

		transport: buildTransportObject(cfg, true)
	});
});

if (length(config.inbounds) === 0)
	exit(1);

config['$schema'] = 'https://sing-box.sagernet.org/schema.json';

system('mkdir -p ' + RUN_DIR);
const server_tmp = RUN_DIR + '/sing-box-s.json.tmp';
writefile(server_tmp, sprintf('%.J\n', removeBlankAttrs(config)));
if (system('/usr/bin/sing-box check --config ' + server_tmp) !== 0) {
	system('rm -f ' + server_tmp);
	exit(1);
}
system('mv -f ' + server_tmp + ' ' + RUN_DIR + '/sing-box-s.json');
system('chmod 600 ' + RUN_DIR + '/sing-box-s.json');
