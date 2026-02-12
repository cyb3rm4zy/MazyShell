#!/usr/bin/env bash

set -euo pipefail

cmd="${1:-}"

icd_path="/usr/share/vulkan/icd.d/nvidia_icd.json"

have_supergfxctl() {
  command -v supergfxctl >/dev/null 2>&1
}

do_logout() {
  sleep 1
  pkill -KILL -u "${USER}"
}

case "$cmd" in
  status)
    if ! have_supergfxctl; then
      echo "NOSUPER|1"
      exit 0
    fi

    mode="$(supergfxctl -g 2>/dev/null | tr -d '\r' | head -n1 | awk '{print $1}')"
    echo "MODE|${mode:-}"

    if [[ -f "$icd_path" ]]; then
      echo "ICD|$icd_path"
    else
      echo "ICD|"
    fi
    ;;

  set_logout)
    if ! have_supergfxctl; then
      exit 1
    fi

    target="${2:-}"
    case "$target" in
      integrated|Integrated)
        supergfxctl -m Integrated
        ;;
      hybrid|Hybrid|dgpu|dGPU)
        supergfxctl -m Hybrid
        ;;
      *)
        echo "ERR|bad-target"
        exit 2
        ;;
    esac

    do_logout
    ;;

  app)
    NVIDIA_ICD="$icd_path"

    exec rofi -show drun \
      -run-command "env \
        VK_ICD_FILENAMES=$NVIDIA_ICD \
        __NV_PRIME_RENDER_OFFLOAD=1 \
        __GLX_VENDOR_LIBRARY_NAME=nvidia \
        {cmd}"
    ;;

  *)
    echo "Usage:"
    echo "  $0 status"
    echo "  $0 set_logout integrated|hybrid"
    echo "  $0 app"
    exit 1
    ;;
esac