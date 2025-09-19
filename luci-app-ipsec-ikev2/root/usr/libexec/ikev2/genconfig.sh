#!/bin/sh
    set -e

    cfg() { uci -q get ikev2.config."$1"; }
    listvals() { uci -q get ikev2.config."$1"; }

    ENABLED="$(cfg enabled)"
    [ "$ENABLED" = "1" ] || exit 0

    LISTEN="$(cfg listen)"
    LEFTID="$(cfg leftid)"
    MODE="$(cfg mode)"
    IKEP="$(cfg ike_proposals)"
    ESPP="$(cfg esp_proposals)"
    MOBIKE="$(cfg mobike)"
    FRAG="$(cfg fragmentation)"
    DPD="$(cfg dpd_delay)"
    POOL="$(cfg pool)"
    DNS_G="$(listvals dns)"
    SPLIT="$(listvals split_subnets)"
    REKEY="$(cfg rekey_time)"
    SACTION="$(cfg start_action)"
    GLOBAL_PSK="$(cfg global_psk)"
    ENSURE_MASQ="$(cfg ensure_wan_masq)"

    [ -z "$LISTEN" ] && LISTEN="%any"
    [ -z "$MODE" ] && MODE="full"

    mkdir -p /etc/swanctl

    # Compute local_ts based on MODE
    calc_local_ts() {
      case "$MODE" in
        full)
          echo "0.0.0.0/0, ::/0"
        ;;
        lan)
          # IPv4
          LAN_IP="$(uci -q get network.lan.ipaddr)"
          LAN_MASK="$(uci -q get network.lan.netmask)"
          TS4=""
          if [ -n "$LAN_IP" ] && [ -n "$LAN_MASK" ]; then
            IPC=$(ipcalc.sh "$LAN_IP" "$LAN_MASK")
            NET="$(echo "$IPC" | sed -n 's/NETWORK=\(.*\)/\1/p')"
            PREFIX="$(echo "$IPC" | sed -n 's/PREFIX=\(.*\)/\1/p')"
            [ -n "$NET" ] && [ -n "$PREFIX" ] && TS4="$NET/$PREFIX"
          fi
          # IPv6 简化处理：如需要可在“自定义”模式下补充
          if [ -n "$TS4" ]; then
            echo "$TS4"
          else
            echo "192.168.0.0/16"
          fi
        ;;
        custom|*)
          if [ -n "$SPLIT" ]; then
            echo "$SPLIT" | sed 's/ /, /g'
          else
            echo "0.0.0.0/0, ::/0"
          fi
        ;;
      esac
    }

    local_ts="$(calc_local_ts)"

    # Build pools{} from pool sections
    pools_conf=""
    for s in $(uci -q show ikev2 | sed -n 's/^ikev2\.\(.*\)=pool$/\1/p'); do
        name="$(echo "$s")"
        addrs="$(uci -q get ikev2.$name.addrs)"
        pdns="$(uci -q get ikev2.$name.dns)"
        [ -n "$addrs" ] || continue
        pools_conf="$pools_conf
  $name {
    addrs = $addrs"
        if [ -n "$pdns" ]; then
            pdns_line="$(echo "$pdns" | sed 's/ /, /g')"
            pools_conf="$pools_conf
    dns = $pdns_line"
        elif [ -n "$DNS_G" ]; then
            pdns_line="$(echo "$DNS_G" | sed 's/ /, /g')"
            pools_conf="$pools_conf
    dns = $pdns_line"
        fi
        pools_conf="$pools_conf
  }"
    done

    # Secrets for PSK users
    secrets_conf=""
    for u in $(uci -q show ikev2 | sed -n 's/^ikev2\.\(.*\)=psk_user$/\1/p'); do
        rid="$(uci -q get ikev2.$u.id)"
        psk="$(uci -q get ikev2.$u.psk)"
        [ -n "$rid" ] || continue
        secrets_conf="$secrets_conf
  ike-$rid {
    id = $rid
    secret = \"$psk\"
  }"
    done

    # Global PSK (optional)
    if [ -n "$GLOBAL_PSK" ]; then
        secrets_conf="$secrets_conf
  ike-any {
    id = %any
    secret = \"$GLOBAL_PSK\"
  }"
    fi

    # swanctl.conf (PSK)
    cat > /etc/swanctl/swanctl.conf <<EOF
connections {
  ikev2-psk {
    version = 2
    proposals = ${IKEP}
    unique = replace
    mobike = $( [ "$MOBIKE" = "1" ] && echo yes || echo no )
    fragmentation = $( [ "$FRAG" = "1" ] && echo yes || echo no )
    dpd_delay = ${DPD}s
    local_addrs = ${LISTEN}
    local {
      auth = psk
      id = ${LEFTID}
    }
    remote {
      auth = psk
      id = %any
    }
    children {
      net {
        local_ts = ${local_ts}
        start_action = ${SACTION:-trap}
        rekey_time = ${REKEY:-3600}s
        esp_proposals = ${ESPP}
        policies = yes
      }
    }
    pools = ${POOL}
  }
}

pools {${pools_conf}
}

secrets {${secrets_conf}
}
EOF

    echo "swanctl.conf generated for PSK (mode: $MODE)."

    # Ensure WAN MASQUERADE if requested
    if [ "$ENSURE_MASQ" = "1" ]; then
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
