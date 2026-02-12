#!/usr/bin/env bash

set -u

cmd="${1:-}"

have_ppctl() { command -v powerprofilesctl >/dev/null 2>&1; }
have_asusctl() { command -v asusctl >/dev/null 2>&1; }

ppd_to_asus_profile() {
  case "${1:-}" in
    power-saver) echo "Quiet" ;;
    balanced)    echo "Balanced" ;;
    performance) echo "Performance" ;;
    *)           echo "" ;;
  esac
}

asus_profile_available() {
  local want="${1:-}"
  [ -n "$want" ] || return 1
  asusctl profile list 2>/dev/null | tr -d $'\r' | grep -Fx "$want" >/dev/null 2>&1
}

apply_asus_profile_best_effort() {
  have_asusctl || return 0

  local ppd="${1:-}"
  local ap
  ap="$(ppd_to_asus_profile "$ppd")"
  [ -n "$ap" ] || return 0

  if asus_profile_available "$ap"; then
    asusctl profile set "$ap" >/dev/null 2>&1 || true
  fi

  return 0
}

status() {
  if ! have_ppctl; then
    echo "NOPPD|1"
    exit 0
  fi

  local p
  p="$(powerprofilesctl get 2>/dev/null | tr -d $'\r' | head -n1)"
  if [ -z "${p:-}" ]; then
    echo "NOPPD|1"
    exit 0
  fi

  echo "PROFILE|$p"
  exit 0
}

set_profile() {
  local p="${1:-}"
  [ -n "$p" ] || exit 0

  if ! have_ppctl; then
    echo "NOPPD|1"
    exit 0
  fi

  powerprofilesctl set "$p" >/dev/null 2>&1 || true

  apply_asus_profile_best_effort "$p"

  exit 0
}

case "$cmd" in
  status) status ;;
  set) shift; set_profile "${1:-}" ;;
  *)
    echo "NOPPD|1"
    exit 0
    ;;
esac