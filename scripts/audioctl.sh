#!/usr/bin/env bash
set -euo pipefail

wpctl_bin="${WPCTL_BIN:-wpctl}"

fail() { echo "$*" >&2; exit 1; }

inspect() {
  "$wpctl_bin" inspect -a "$1" 2>/dev/null || true
}

field_quoted() {
  local insp="$1" key="$2"
  printf '%s\n' "$insp" | sed -n "s/.*${key}[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n1
}

media_class() {
  field_quoted "$1" "media\.class"
}

display_name() {
  local insp="$1" n
  n="$(field_quoted "$insp" "node\.description")"
  [[ -z "$n" ]] && n="$(field_quoted "$insp" "node\.nick")"
  [[ -z "$n" ]] && n="$(field_quoted "$insp" "node\.name")"
  printf '%s' "${n:-}"
}

candidates_from_status() {
  "$wpctl_bin" status --name | awk '
    function clean(s) {
      gsub(/[│├└─]/, " ", s)
      sub(/^[ \t]+/, "", s)
      return s
    }

    BEGIN { in_audio=0; sec="" }

    { line = clean($0) }

    line == "Audio" { in_audio=1; next }
    in_audio && line == "Video" { exit }

    in_audio && line == "Sinks:"   { sec="SINKS"; next }
    in_audio && line == "Sources:" { sec="SOURCES"; next }
    in_audio && line == "Filters:" { sec="FILTERS"; next }

    in_audio && sec != "" && line ~ /^[A-Z][A-Za-z ]*:/ && line != "Sinks:" && line != "Sources:" && line != "Filters:" {
      sec=""
      next
    }

    (sec=="SINKS" || sec=="SOURCES") && match(line, /^(\*)?[[:space:]]*([0-9]+)\.[[:space:]]+(.+)$/, m) {
      def = (m[1] == "*" ? 1 : 0)
      id  = m[2]
      raw = m[3]

      sub(/[[:space:]]+\[vol:[^]]+\][[:space:]]*$/, "", raw)

      kind = (sec=="SINKS" ? "SINK" : "SOURCE")
      printf "%s\t%d\t%s\t%s\n", kind, def, id, raw
      next
    }

    sec=="FILTERS" && match(line, /^(\*)?[[:space:]]*([0-9]+)\.[[:space:]]+([^[]+)[[:space:]]+\[([^]]+)\][[:space:]]*$/, f) {
      def = (f[1] == "*" ? 1 : 0)
      id  = f[2]
      raw = f[3]
      cls = f[4]

      if (cls == "Audio/Sink")   printf "SINK\t%d\t%s\t%s\n", def, id, raw
      if (cls == "Audio/Source") printf "SOURCE\t%d\t%s\t%s\n", def, id, raw
      next
    }
  '
}

list() {
  local line kind def id raw
  local any=0

  while IFS=$'\t' read -r kind def id raw; do
    [[ -z "${id:-}" ]] && continue

    local insp cls name
    insp="$(inspect "$id")"
    [[ -z "$insp" ]] && continue

    cls="$(media_class "$insp")"
    if [[ "$kind" == "SINK" ]]; then
      [[ "$cls" == "Audio/Sink" ]] || continue
    else
      [[ "$cls" == "Audio/Source" ]] || continue
    fi

    name="$(display_name "$insp")"
    [[ -z "$name" ]] && name="$raw"
    [[ -z "$name" ]] && name="Node $id"

    printf "%s\t%s\t%s\t%s\n" "$kind" "$def" "$id" "$name"
    any=1
  done < <(candidates_from_status)

  if [[ "$any" -eq 0 ]]; then
    echo "No audio nodes returned by audioctl" >&2
    exit 0
  fi
}

case "${1:-}" in
  list)
    list
    ;;

  set-default)
    [[ $# -eq 3 ]] || fail "usage: $0 set-default sink|source <id>"
    "$wpctl_bin" set-default "$3"
    ;;

  volume)
    [[ $# -eq 2 ]] || fail "usage: $0 volume sink|source"
    if [[ "$2" == "sink" ]]; then
      "$wpctl_bin" get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true
    else
      "$wpctl_bin" get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || true
    fi
    ;;

  *)
    fail "usage: $0 list | set-default sink|source <id> | volume sink|source"
    ;;
esac