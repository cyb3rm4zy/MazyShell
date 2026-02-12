#!/usr/bin/env bash

set -u

cmd="${1:-}"

have_nmcli() { command -v nmcli >/dev/null 2>&1; }
have() { command -v "$1" >/dev/null 2>&1; }

wifi_power() {
  local onoff="${1:-off}"
  nmcli radio wifi "$onoff" >/dev/null 2>&1 || true
}

wifi_scan() {
  local ifname="${1:-}"
  [ -n "$ifname" ] || exit 0
  nmcli radio wifi on >/dev/null 2>&1 || true
  sleep 0.2
  nmcli dev wifi rescan ifname "$ifname" >/dev/null 2>&1 || true
}

wifi_disconnect() {
  local ifname="${1:-}"
  [ -n "$ifname" ] || exit 0
  nmcli dev disconnect "$ifname" >/dev/null 2>&1 || true
}

bar_status() {
  pick_default_iface() {
    ip route show default 2>/dev/null |
      awk '{
        dev=""; metric=0;
        for(i=1;i<=NF;i++){
          if($i=="dev") dev=$(i+1);
          if($i=="metric") metric=$(i+1);
        }
        if(dev!="") print metric "\t" dev;
      }' |
      while IFS=$'\t' read -r metric dev; do
        weight=1
        case "$dev" in
          usb*|rndis*|wwan*) weight=0 ;;
          *)
            if [ -d "/sys/class/net/$dev/wireless" ]; then
              weight=2
            else
              devpath="$(readlink -f "/sys/class/net/$dev/device" 2>/dev/null || true)"
              if printf '%s' "$devpath" | grep -qi "/usb"; then
                weight=0
              else
                driver="$(basename "$(readlink -f "/sys/class/net/$dev/device/driver" 2>/dev/null || true)" 2>/dev/null || true)"
                case "$driver" in
                  rndis_host|cdc_ether|cdc_ncm|ipheth|r8152|asix|ax88179_178a) weight=0 ;;
                esac
              fi
            fi
            ;;
        esac
        printf "%s\t%s\t%s\n" "$metric" "$weight" "$dev"
      done |
      sort -n -k1,1 -k2,2 |
      head -n1 |
      cut -f3
  }

  iface="$(pick_default_iface || true)"
  if [ -z "${iface:-}" ]; then
    iface="$(ip -o route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}' || true)"
  fi

  if [ -z "${iface:-}" ] || [ ! -e "/sys/class/net/$iface" ]; then
    printf "none\t\t0\t0\n\n"
    exit 0
  fi

  rx="$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)"
  tx="$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)"

  kind="ethernet"
  ssid=""

  if [ -d "/sys/class/net/$iface/wireless" ]; then
    kind="wifi"
  fi

  if [ "$kind" = "ethernet" ]; then
    case "$iface" in
      usb*|rndis*|wwan*) kind="tether" ;;
      *)
        devpath="$(readlink -f "/sys/class/net/$iface/device" 2>/dev/null || true)"
        if printf '%s' "$devpath" | grep -qi "/usb"; then
          kind="tether"
        else
          driver="$(basename "$(readlink -f "/sys/class/net/$iface/device/driver" 2>/dev/null || true)" 2>/dev/null || true)"
          case "$driver" in
            rndis_host|cdc_ether|cdc_ncm|ipheth|r8152|asix|ax88179_178a) kind="tether" ;;
          esac
        fi
        ;;
    esac
  fi

  if [ "$kind" = "wifi" ]; then
    if have iw; then
      ssid="$(timeout 0.25 iw dev "$iface" link 2>/dev/null | awk -F": " '/SSID:/{print $2; exit}' || true)"
    fi
    if [ -z "${ssid:-}" ] && have_nmcli; then
      ssid="$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}' || true)"
    fi
  fi

  ssid="${ssid//$'\t'/ }"

  printf "%s\t%s\t%s\t%s\n" "$kind" "$iface" "$rx" "$tx"
  printf "%s\n" "$ssid"
}

status() {
  if ! have_nmcli; then
    echo 'NONMCLI|1'
    exit 0
  fi

  local wifi
  wifi="$(nmcli -t -f WIFI general status 2>/dev/null | head -n1 | tr -d $'\r')"
  case "$wifi" in
    enabled|*enabled*) echo 'WIFIPWR|1' ;;
    *)                echo 'WIFIPWR|0' ;;
  esac

  local wifidev
  wifidev="$(nmcli -t -f DEVICE,TYPE dev status 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')"
  echo "WIFIDEV|${wifidev:-}"

  local act adev atype
  act="$(nmcli -t -f DEVICE,TYPE,STATE dev status 2>/dev/null | awk -F: '$3=="connected"{print $1":"$2; exit}')"
  adev="$(printf '%s' "$act" | awk -F: '{print $1}')"
  atype="$(printf '%s' "$act" | awk -F: '{print $2}')"

  if [ "$atype" = "wifi" ] && [ -n "${adev:-}" ]; then
    local assid
    assid="$(nmcli -t -f ACTIVE,SSID dev wifi list ifname "$adev" 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')"
    if [ -z "${assid:-}" ]; then
      assid="$(nmcli -t -f GENERAL.CONNECTION dev show "$adev" 2>/dev/null | awk -F: '{print $2; exit}')"
    fi
    echo "ACTIVE|wifi|${adev}|${assid:-}"
  elif [ "$atype" = "ethernet" ]; then
    case "$adev" in
      usb*|enx*) echo 'ACTIVE|tether||Tether' ;;
      *)        echo 'ACTIVE|ethernet||Ethernet' ;;
    esac
  elif [ "$atype" = "gsm" ] || [ "$atype" = "wwan" ]; then
    echo 'ACTIVE|tether||Tether'
  elif [ -n "${atype:-}" ]; then
    echo "ACTIVE|other||${atype}"
  else
    echo 'ACTIVE|none||'
  fi

  if [ -n "${wifidev:-}" ]; then
    nmcli -t -f IN-USE,SSID,SECURITY,SIGNAL dev wifi list ifname "$wifidev" 2>/dev/null |
      while IFS=: read -r inuse ssid2 sec sig; do
        [ -n "${ssid2:-}" ] || continue
        echo "AP|${inuse:-}|${ssid2:-}|${sec:---}|${sig:-0}"
      done
  fi

  true
}

wifi_connect() {
  local iface="${1:-}"
  local ssid="${2:-}"
  local sec="${3:-}"
  local pass="${4:-}"

  set +e

  local conn out ec
  conn="$(
    nmcli -t -f NAME,TYPE con show 2>/dev/null | awk -F: '$2=="802-11-wireless"{print $1}' |
      while IFS= read -r c; do
        [ -n "$c" ] || continue
        local cs
        cs="$(nmcli -g 802-11-wireless.ssid con show "$c" 2>/dev/null | tr -d $'\r')"
        [ "$cs" = "$ssid" ] && { printf '%s' "$c"; exit 0; }
      done
  )"

  verify() {
    local i=0 cur
    while [ $i -lt 12 ]; do
      cur="$(nmcli -t -f ACTIVE,SSID dev wifi list ifname "$iface" 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}')"
      [ "$cur" = "$ssid" ] && return 0
      sleep 0.3
      i=$((i+1))
    done
    return 1
  }

  if [ "$sec" = "--" ] || [ "$sec" = "OPEN" ] || [ -z "$sec" ]; then
    if [ -n "$conn" ]; then
      out="$(nmcli --wait 25 con up "$conn" 2>&1)"; ec=$?
    else
      out="$(nmcli --wait 25 dev wifi connect "$ssid" ifname "$iface" 2>&1)"; ec=$?
    fi

    if [ $ec -eq 0 ] && verify; then
      printf 'EC|0\nMSG|connected\n'
      exit 0
    fi

    local msg
    msg="$(printf '%s' "$out" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | cut -c1-360)"
    [ -n "$msg" ] || msg="nmcli returned exit code $ec"
    printf 'EC|%s\nMSG|%s\n' "$ec" "$msg"
    exit 0
  fi

  if [ -z "$pass" ]; then
    if [ -n "$conn" ]; then
      out="$(nmcli --wait 25 con up "$conn" 2>&1)"; ec=$?
      if [ $ec -eq 0 ] && verify; then
        printf 'EC|0\nMSG|connected\n'
        exit 0
      fi

      if printf '%s' "$out" | grep -Eqi 'secrets.*required|not provided|No agents were available'; then
        local msg
        msg="$(printf '%s' "$out" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | cut -c1-360)"
        [ -n "$msg" ] || msg='Secrets required.'
        printf 'EC|%s\nMSG|%s\nPROMPT|1\n' "$ec" "$msg"
        exit 0
      fi

      local msg
      msg="$(printf '%s' "$out" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | cut -c1-360)"
      [ -n "$msg" ] || msg="nmcli returned exit code $ec"
      printf 'EC|%s\nMSG|%s\n' "$ec" "$msg"
      exit 0
    else
      printf 'EC|1\nMSG|Password required.\nPROMPT|1\n'
      exit 0
    fi
  fi

  if [ -n "$conn" ]; then
    out="$(printf '%s\n%s\n' "$pass" "$pass" | nmcli --wait 25 --ask con up "$conn" 2>&1)"; ec=$?
    if [ $ec -eq 0 ] && verify; then
      printf 'EC|0\nMSG|connected\n'
      exit 0
    fi
    local msg
    msg="$(printf '%s' "$out" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | cut -c1-360)"
    [ -n "$msg" ] || msg="nmcli returned exit code $ec"
    printf 'EC|%s\nMSG|%s\nPROMPT|1\n' "$ec" "$msg"
    exit 0
  fi

  local key='wpa-psk'
  echo "$sec" | grep -Eqi 'WPA3|SAE' && key='sae'

  nmcli -t -f NAME con show 2>/dev/null | grep -Fx "$ssid" >/dev/null 2>&1 && nmcli con delete "$ssid" >/dev/null 2>&1 || true

  local outa eca outb ecb msg
  outa="$(nmcli con add type wifi ifname "$iface" con-name "$ssid" ssid "$ssid" wifi-sec.key-mgmt "$key" wifi-sec.psk "$pass" 2>&1)"; eca=$?
  if [ $eca -ne 0 ]; then
    msg="$(printf '%s' "$outa" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | cut -c1-360)"
    [ -n "$msg" ] || msg="nmcli returned exit code $eca"
    printf 'EC|%s\nMSG|%s\n' "$eca" "$msg"
    exit 0
  fi

  outb="$(nmcli --wait 25 con up "$ssid" 2>&1)"; ecb=$?
  if [ $ecb -eq 0 ] && verify; then
    printf 'EC|0\nMSG|connected\n'
    exit 0
  fi

  nmcli con delete "$ssid" >/dev/null 2>&1 || true

  msg="$(printf '%s' "$outb" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | cut -c1-360)"
  [ -n "$msg" ] || msg="nmcli returned exit code $ecb"
  printf 'EC|%s\nMSG|%s\nPROMPT|1\n' "$ecb" "$msg"
  exit 0
}

case "$cmd" in
  bar)             bar_status ;;

  status)          status ;;
  wifi_power)      wifi_power "${2:-}" ;;
  wifi_scan)       wifi_scan "${2:-}" ;;
  wifi_disconnect) wifi_disconnect "${2:-}" ;;
  wifi_connect)    shift; wifi_connect "$@" ;;
  *)
    echo "MSG|unknown command"
    exit 0
    ;;
esac