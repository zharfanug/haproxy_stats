#!/usr/bin/env bash

SCRIPT_NAME="$(basename "$0")"

sec_to_htime() {
  local total_sec=$1
  local years=$(( total_sec / 31536000 ))
  local days=$(( (total_sec % 31536000) / 86400 ))
  local hours=$(( (total_sec % 86400) / 3600 ))
  local minutes=$(( (total_sec % 3600) / 60 ))
  local seconds=$(( total_sec % 60 ))

  local htime=""
  (( years > 0 )) && htime+="${years}y "
  (( days > 0 )) && htime+="${days}d "
  (( hours > 0 )) && htime+="${hours}h "
  (( minutes > 0 )) && htime+="${minutes}m "
  htime+="${seconds}s"

  echo "$htime"
}

haproxy_stats_init() {
  local sock="/run/haproxy/admin.sock"

  # Validation: check if socat is installed
  if ! command -v socat >/dev/null 2>&1; then
    echo "Error: socat command not found. Please install socat."
    return 1
  fi

  # Validation: check if HAProxy socket exists
  if [ ! -S "$sock" ]; then
    echo "Error: HAProxy socket not found at $sock"
    return 1
  fi

  # Capture HAProxy stats
  local haproxy_stats
  haproxy_stats=$(echo "show stat" | socat unix-connect:"$sock" stdio)
  # Arrays and max column widths
  local down_lines=()

  # Header names
  local header_backend="BACKEND POOL"
  local header_server="SERVER NAME"
  local header_node="NODE"
  local header_status="STATUS"
  local header_proto="MODE"
  # local header_lastchg="LAST_CHG"
  local header_downtime="DOWNTIME"
  local header_reason="REASON"
  # local header_check="CHECK_DESC"

  # Initialize max column lengths to header lengths
  local max_backend_len=${#header_backend}
  local max_server_len=${#header_server}
  local max_node_len=${#header_node}
  local max_status_len=${#header_status}
  local max_proto_len=${#header_proto}
  # local max_lastchg_len=${#header_lastchg}
  local max_downtime_len=${#header_downtime}
  local max_reason_last_chk_len=${#header_reason}
  # local max_check_desc_len=${#header_check}

  # Process each line
  while IFS= read -r line; do
    [[ "$line" =~ ^# ]] && continue
    PRINT_LINE=0
    # Check if SHOW_UP is 1 and line contains ",UP,"
    if [[ $SHOW_UP -eq 1 && "$line" == *",UP,"* ]]; then
      PRINT_LINE=1
    fi

    # Check if SHOW_DOWN is 1 and line contains ",DOWN,"
    if [[ $SHOW_DOWN -eq 1 && "$line" == *",DOWN,"* ]]; then
      PRINT_LINE=1
    fi

    # Skip line if PRINT_LINE is still 0
    if [[ $PRINT_LINE -eq 0 ]]; then
      continue
    fi

    # [[ "$line" != *DOWN* ]] && continue

    IFS=',' read -r -a arr <<< "$line"

    local backend="${arr[0]}"
    local server="${arr[1]}"
    local node="${arr[73]}"
    local status="${arr[17]}"
    local proto="${arr[75]}"
    # local lastchg="${arr[23]}"
    local downtime="$(sec_to_htime ${arr[24]})"
    local reason_last_chk="${arr[56]}"
    # local check_desc="${arr[65]}"

    # Skip if any key field is empty
    if [[ -z "$backend" || -z "$server" || -z "$node" || -z "$status" || -z "$proto" ]]; then
      continue
    fi

    down_lines+=("${backend},${server},${node},${status},${proto},${downtime},${reason_last_chk}")

    # Update max lengths if row is longer than header
    (( ${#backend} > max_backend_len )) && max_backend_len=${#backend}
    (( ${#server} > max_server_len )) && max_server_len=${#server}
    (( ${#node} > max_node_len )) && max_node_len=${#node}
    (( ${#status} > max_status_len )) && max_status_len=${#status}
    (( ${#proto} > max_proto_len )) && max_proto_len=${#proto}
    # (( ${#lastchg} > max_lastchg_len )) && max_lastchg_len=${#lastchg}
    (( ${#downtime} > max_downtime_len )) && max_downtime_len=${#downtime}
    (( ${#reason_last_chk} > max_reason_last_chk_len )) && max_reason_last_chk_len=${#reason_last_chk}

  done <<< "$haproxy_stats"

  # Print header
  printf "%-${max_backend_len}s | %-${max_server_len}s | %-${max_node_len}s | %-${max_status_len}s | %-${max_proto_len}s | %-${max_downtime_len}s | %-${max_reason_last_chk_len}s\n" \
    "$header_backend" "$header_server" "$header_node" "$header_status" "$header_proto" "$header_downtime" "$header_reason"

  # Separator line
  printf -- "%s\n" "$(printf '%*s' $((max_backend_len + max_server_len + max_node_len + max_status_len + max_proto_len + max_downtime_len + max_reason_last_chk_len + 24)) '' | tr ' ' '-')"

  # Print servers
  for line in "${down_lines[@]}"; do
    IFS=',' read -r -a arr <<< "$line"

    # Set color based on status
    if [[ "${arr[3]}" == "DOWN" ]]; then
      color="\e[31m"   # Red
    elif [[ "${arr[3]}" == "UP" ]]; then
      color="\e[92m"   # Light Green
    else
      color="\e[0m"    # Default
    fi

    # Reset color at the end
    reset="\e[0m"

    printf "%-${max_backend_len}s | %-${max_server_len}s | %-${max_node_len}s | ${color}%-${max_status_len}s${reset} | %-${max_proto_len}s | %-${max_downtime_len}s | %-${max_reason_last_chk_len}s\n" \
      "${arr[0]}" "${arr[1]}" "${arr[2]}" "${arr[3]}" "${arr[4]}" "${arr[5]}" "${arr[6]}"
  done
}

haproxy_stats_usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTION]

Options:
  -h, --help      Show this help message
  -d, --down      Show HAProxy servers that are DOWN
  -u, --up        Show HAProxy servers that are UP

Examples:
  ${SCRIPT_NAME} --down
  ${SCRIPT_NAME} --up
EOF
}

main() {
  # Main CLI logic
  SHOW_UP=0
  SHOW_DOWN=0

  if [ $# -eq 0 ]; then
    SHOW_UP=1
    SHOW_DOWN=1
  fi

  case "$1" in
    -h|--help)
      haproxy_stats_usage
      ;;
    -d|--down)
      SHOW_DOWN=1
      ;;
    -u|--up)
      SHOW_UP=1
      ;;
    *)
      SHOW_UP=1
      SHOW_DOWN=1
      ;;
  esac
  if [[ $SHOW_UP -eq 1 || $SHOW_DOWN -eq 1 ]]; then
    haproxy_stats_init
  fi
}

main "$@"