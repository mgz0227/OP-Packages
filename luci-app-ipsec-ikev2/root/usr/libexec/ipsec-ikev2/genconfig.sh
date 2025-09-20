#!/bin/sh
    set -e

    . /lib/functions.sh

    CFG="luci-app-ipsec-ikev2"

    enabled=0
    listen="%any"
    leftid="vpn.example.com"
    mode="full"
    ikep="aes256-sha256-prfsha256-modp2048,aes256gcm16-prfsha256-modp2048"
    espp="aes256-sha256-modp2048,aes256gcm16-modp2048"
    mobike=1
    frag=1
    dpd=30
    pool="pool0"
    rekey="3600"
    action="trap"
    global_psk=""
    ensure_masq=1

    dns_list=""
    split_list=""
    pools_conf=""
    secrets_conf=""

    append_dns() { [ -n "$1" ] || return 0; dns_list="${dns_list:+$dns_list }$1"; }
    append_split(){ [ -n "$1" ] || return 0; split_list="${split_list:+$split_list }$1"; }

    load_global() {
        local s="$1"
        config_get_bool enabled "$s" enabled 0
        [ "$enabled" = "1" ] || exit 0
        config_get listen "$s" listen "%any"
        config_get leftid "$s" leftid "vpn.example.com"
        config_get mode "$s" mode "full"
        config_get ikep "$s" ike_proposals "$ikep"
        config_get espp "$s" esp_proposals "$espp"
        config_get_bool mobike "$s" mobike 1
        config_get_bool frag "$s" fragmentation 1
        config_get dpd "$s" dpd_delay "30"
        config_get pool "$s" pool "pool0"
        config_list_foreach "$s" dns append_dns
        config_list_foreach "$s" split_subnets append_split
        config_get rekey "$s" rekey_time "3600"
        config_get action "$s" start_action "trap"
        config_get global_psk "$s" global_psk ""
        config_get_bool ensure_masq "$s" ensure_wan_masq 1
    }

    _dns_collect() { echo "$1"; }

    build_pool() {
        local s="$1"
        local addrs
        config_get addrs "$s" addrs ""
        [ -n "$addrs" ] || return 0
        local pdns=""
        local _dns_list=""
        config_list_foreach "$s" dns _dns_collect | while read d; do
            _dns_list="${_dns_list:+$_dns_list, }$d"
        done
        if [ -z "$_dns_list" ] && [ -n "$dns_list" ]; then
            for d in $dns_list; do pdns="${pdns:+$pdns, }$d"; done
        else
            pdns="$_dns_list"
        fi
        pools_conf="$pools_conf
  $s {
    addrs = $addrs"
        [ -n "$pdns" ] && pools_conf="$pools_conf
    dns = $pdns"
        pools_conf="$pools_conf
  }"
    }

    build_psk() {
        local s="$1"
        local rid psk
        config_get rid "$s" id ""
        config_get psk "$s" psk ""
        [ -n "$rid" ] || return 0
        secrets_conf="$secrets_conf
  ike-$rid {
    id = $rid
    secret = \"$psk\"
  }"
    }

    calc_local_ts() {
        case "$mode" in
            full) echo "0.0.0.0/0, ::/0" ;;
            lan)
                local lan_ip lan_mask net prefix
                lan_ip="$(uci -q get network.lan.ipaddr)"
                lan_mask="$(uci -q get network.lan.netmask)"
                if [ -n "$lan_ip" ] && [ -n "$lan_mask" ]; then
                    IPC=$(ipcalc.sh "$lan_ip" "$lan_mask")
                    net="$(echo "$IPC" | sed -n 's/NETWORK=\(.*\)/\1/p')"
                    prefix="$(echo "$IPC" | sed -n 's/PREFIX=\(.*\)/\1/p')"
                    [ -n "$net" ] && [ -n "$prefix" ] && echo "$net/$prefix" && return 0
                fi
                echo "192.168.0.0/16"
            ;;
            custom|*)
                if [ -n "$split_list" ]; then
                    echo "$split_list" | sed 's/ /, /g'
                else
                    echo "0.0.0.0/0, ::/0"
                fi
            ;;
        esac
    }

    config_load "$CFG"
    config_foreach load_global "config"
    config_foreach build_pool  "pool"
    config_foreach build_psk   "psk_user"

    if [ -n "$global_psk" ]; then
        secrets_conf="$secrets_conf
  ike-any {
    id = %any
    secret = \"$global_psk\"
  }"
    fi

    local_ts="$(calc_local_ts)"

    mkdir -p /etc/swanctl
    cat > /etc/swanctl/swanctl.conf <<EOF
connections {
  ikev2-psk {
    version = 2
    proposals = ${ikep}
    unique = replace
    mobike = $( [ "$mobike" = "1" ] && echo yes || echo no )
    fragmentation = $( [ "$frag" = "1" ] && echo yes || echo no )
    dpd_delay = ${dpd}s
    local_addrs = ${listen}
    local {
      auth = psk
      id = ${leftid}
    }
    remote {
      auth = psk
      id = %any
    }
    children {
      net {
        local_ts = ${local_ts}
        start_action = ${action}
        rekey_time = ${rekey}s
        esp_proposals = ${espp}
        policies = yes
      }
    }
    pools = ${pool}
  }
}

pools {${pools_conf}
}

secrets {${secrets_conf}
}
EOF

    echo "swanctl.conf generated (mode=$mode)"

    # Ensure WAN MASQUERADE if requested
    if [ "$ensure_masq" = "1" ]; then
      ZI="$(uci -q show firewall | sed -n 's/^firewall\.\(.*\)=zone.*/\1/p' | while read z; do n="$(uci -q get firewall.$z.name)"; [ "$n" = "wan" ] && echo "$z"; done | head -n1)"
      if [ -n "$ZI" ]; then
        MASQ="$(uci -q get firewall.$ZI.masq)"
        if [ "$MASQ" != "1" ]; then
          uci -q set firewall.$ZI.masq='1'
          uci -q commit firewall
          /etc/init.d/firewall reload >/dev/null 2>&1 || true
          echo "WAN zone masq enabled to allow Internet egress for VPN clients."
        fi
      fi
    fi
