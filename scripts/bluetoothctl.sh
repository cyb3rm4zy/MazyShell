#!/usr/bin/env bash
set -euo pipefail

bt="${BLUETOOTHCTL_BIN:-bluetoothctl}"

fail() { echo "$*" >&2; exit 1; }
have_bt() { command -v "$bt" >/dev/null 2>&1; }


get_powered() {
  "$bt" show 2>/dev/null | awk -F': ' '/Powered:/{gsub(/[ \t]+/,"",$2); print $2; exit}'
}

get_connected() {
  local mac="$1"
  "$bt" info "$mac" 2>/dev/null | awk -F': ' '/Connected:/{gsub(/[ \t]+/,"",$2); print $2; exit}'
}

get_paired() {
  local mac="$1"
  "$bt" info "$mac" 2>/dev/null | awk -F': ' '/Paired:/{gsub(/[ \t]+/,"",$2); print $2; exit}'
}

get_name_info() {
  local mac="$1"
  "$bt" info "$mac" 2>/dev/null | awk -F': ' '/Name:/{sub(/^[ \t]+/,"",$2); print $2; exit}'
}


cmd_bar_status() {
  if ! have_bt; then
    printf 'no|\n'
    exit 0
  fi

  local p name line
  p="$(get_powered || true)"
  [[ -z "${p:-}" ]] && p="no"

  name=""
  if [[ "$p" == "yes" ]]; then
    line="$("$bt" devices Connected 2>/dev/null | head -n1 || true)"
    name="$(printf '%s' "$line" | awk '{ $1=""; $2=""; sub(/^  */,""); print }')"
  fi

  printf '%s|%s\n' "$p" "${name:-}"
}

cmd_status() {
  if ! have_bt; then
    printf 'POWER|no\n'
    exit 0
  fi

  local p
  p="$(get_powered || true)"
  [[ -z "${p:-}" ]] && p="no"
  printf 'POWER|%s\n' "$p"

  "$bt" devices Paired 2>/dev/null | while read -r _ mac rest; do
    [[ -z "${mac:-}" ]] && continue
    local conn name
    conn="$(get_connected "$mac" || true)"
    [[ -z "${conn:-}" ]] && conn="no"

    name="${rest:-}"
    if [[ -z "${name:-}" ]]; then
      name="$(get_name_info "$mac" || true)"
    fi
    [[ -z "${name:-}" ]] && name="$mac"

    printf 'PAIRED|%s|%s|%s\n' "$mac" "$conn" "$name"
  done

  "$bt" devices 2>/dev/null | while read -r _ mac rest; do
    [[ -z "${mac:-}" ]] && continue
    local paired name
    paired="$(get_paired "$mac" || true)"
    [[ "${paired:-no}" == "yes" ]] && continue

    name="${rest:-}"
    if [[ -z "${name:-}" ]]; then
      name="$(get_name_info "$mac" || true)"
    fi
    [[ -z "${name:-}" ]] && name="$mac"

    printf 'FOUND|%s|%s\n' "$mac" "$name"
  done
}

cmd_power() {
  [[ $# -eq 1 ]] || fail "usage: $0 power on|off"
  if ! have_bt; then exit 0; fi
  "$bt" power "$1"
}

cmd_scan() {
  [[ $# -eq 1 ]] || fail "usage: $0 scan on|off"
  if ! have_bt; then exit 0; fi
  if [[ "$1" == "on" ]]; then
    exec "$bt" --timeout 3600 scan on
  else
    "$bt" scan off
  fi
}

cmd_connect() {
  [[ $# -eq 1 ]] || fail "usage: $0 connect <MAC>"
  if ! have_bt; then exit 1; fi
  "$bt" connect "$1"
}

cmd_disconnect() {
  [[ $# -eq 1 ]] || fail "usage: $0 disconnect <MAC>"
  if ! have_bt; then exit 1; fi
  "$bt" disconnect "$1"
}

cmd_pair_connect() {
  [[ $# -eq 1 ]] || fail "usage: $0 pair-connect <MAC>"
  if ! have_bt; then exit 1; fi
  local mac="$1"
  "$bt" pair "$mac" >/dev/null 2>&1 || true
  "$bt" trust "$mac" >/dev/null 2>&1 || true
  "$bt" connect "$mac"
}

case "${1:-}" in
  bar_status)    shift; cmd_bar_status "$@" ;;
  status)        shift; cmd_status "$@" ;;
  power)         shift; cmd_power "$@" ;;
  scan)          shift; cmd_scan "$@" ;;
  connect)       shift; cmd_connect "$@" ;;
  disconnect)    shift; cmd_disconnect "$@" ;;
  pair-connect)  shift; cmd_pair_connect "$@" ;;
  *) fail "usage: $0 bar_status | status | power on|off | scan on|off | connect <MAC> | disconnect <MAC> | pair-connect <MAC>" ;;
esac