#!/usr/bin/env bash

set -u

cmd="${1:-}"

have() { command -v "$1" >/dev/null 2>&1; }

clamp_int() {
  local v="${1:-0}" lo="${2:-0}" hi="${3:-100}"
  if ! [[ "$v" =~ ^-?[0-9]+$ ]]; then v="$lo"; fi
  if [ "$v" -lt "$lo" ]; then v="$lo"; fi
  if [ "$v" -gt "$hi" ]; then v="$hi"; fi
  printf '%s' "$v"
}

status_brightness() {
  if ! have brightnessctl; then
    echo "BRIGHT_AVAIL|0"
    exit 0
  fi

  local line
  line="$(brightnessctl -m 2>/dev/null | head -n1 | tr -d $'\r')"

  if [ -z "${line:-}" ]; then
    echo "BRIGHT_AVAIL|0"
    exit 0
  fi

  local pct_field pct
  pct_field="$(printf '%s' "$line" | awk -F, '{print $5}')"
  pct="$(printf '%s' "$pct_field" | tr -d ' %' 2>/dev/null || true)"

  if ! [[ "${pct:-}" =~ ^[0-9]+$ ]]; then
    echo "BRIGHT_AVAIL|1"
    exit 0
  fi

  pct="$(clamp_int "$pct" 0 100)"
  echo "BRIGHT_AVAIL|1"
  echo "BRIGHT_PCT|$pct"
  exit 0
}

set_brightness() {
  local pct="${1:-100}"
  if ! have brightnessctl; then
    exit 0
  fi
  pct="$(clamp_int "$pct" 1 100)" # avoid full black; QML also clamps
  brightnessctl set "${pct}%" >/dev/null 2>&1 || true
  exit 0
}

status_bluelight() {
  if ! have hyprsunset; then
    echo "BLUELIGHT|0"
    exit 0
  fi

  if pgrep -x hyprsunset >/dev/null 2>&1; then
    echo "BLUELIGHT|1"
  else
    echo "BLUELIGHT|0"
  fi
  exit 0
}

blue_on() {
  local temp="${1:-3600}"

  have hyprsunset || exit 0

  if pgrep -x hyprsunset >/dev/null 2>&1; then
    exit 0
  fi

  temp="$(clamp_int "$temp" 1000 10000)"

  hyprsunset -t "$temp" >/dev/null 2>&1 & disown || true

  if ! pgrep -x hyprsunset >/dev/null 2>&1; then
    hyprsunset --temperature "$temp" >/dev/null 2>&1 & disown || true
  fi

  exit 0
}

blue_off() {
  pkill -x hyprsunset >/dev/null 2>&1 || true
  exit 0
}

case "$cmd" in
  status_brightness)
    status_brightness
    ;;
  set)
    key="${2:-}"
    case "$key" in
      brightness) set_brightness "${3:-100}" ;;
      *) exit 0 ;;
    esac
    ;;
  status_bluelight)
    status_bluelight
    ;;
  blue)
    action="${2:-}"
    case "$action" in
      on)  blue_on "${3:-3600}" ;;
      off) blue_off ;;
      *)   exit 0 ;;
    esac
    ;;
  *)
    exit 0
    ;;
esac