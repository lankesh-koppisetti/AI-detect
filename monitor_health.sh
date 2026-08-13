#!/usr/bin/env bash
# monitor_health.sh
# Alerts when CPU or Memory usage >= threshold (default 60%).
# Usage: ./monitor_health.sh [--threshold N] [--explain]

set -euo pipefail

THRESHOLD=60
EXPLAIN=0
DETAILS=0

print_explain() {
  cat <<'EOF'
This script checks system CPU and memory usage on Linux.
- CPU: sampled from /proc/stat over 1s to compute percent busy.
- Memory: uses MemTotal and MemAvailable from /proc/meminfo.
If either CPU or Memory usage is >= threshold, the script reports UNHEALTHY and exits with code 1.
Otherwise it reports HEALTHY and exits with code 0.
Use --threshold N to change the percent threshold (integer).
Use --details (or -d) to print CPU and memory percentages in the output.
EOF
}

# simple arg parser
while [[ $# -gt 0 ]]; do
  case "$1" in
    --explain|-e)
      EXPLAIN=1; shift ;;
    --details|-d|--verbose|-v)
      DETAILS=1; shift ;;
    --threshold|-t)
      if [[ -n ${2-} ]]; then THRESHOLD="$2"; shift 2; else echo "Missing value for --threshold" >&2; exit 2; fi ;;
    --help|-h)
      echo "Usage: $0 [--threshold N] [--explain] [--details]"; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2; echo "Usage: $0 [--threshold N] [--explain] [--details]"; exit 2 ;;
  esac
done

if [[ "$EXPLAIN" -eq 1 ]]; then
  print_explain
  exit 0
fi

# validate threshold is integer
if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]]; then
  echo "Threshold must be an integer percentage (e.g. 60)." >&2
  exit 2
fi

# CPU usage calculation using /proc/stat (two samples)
get_cpu_usage() {
  # read first sample
  read -r _ user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
  prev_idle=$((idle + iowait))
  prev_non_idle=$((user + nice + system + irq + softirq + steal))
  prev_total=$((prev_idle + prev_non_idle))

  sleep 1

  read -r _ user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
  idle=$((idle + iowait))
  non_idle=$((user + nice + system + irq + softirq + steal))
  total=$((idle + non_idle))

  totald=$((total - prev_total))
  idled=$((idle - prev_idle))

  if [[ $totald -le 0 ]]; then
    echo "0.0"
    return
  fi

  # compute busy percentage
  busy=$(awk -v t="$totald" -v i="$idled" 'BEGIN { printf "%.1f", (1 - i/t) * 100 }')
  echo "$busy"
}

# Memory usage from /proc/meminfo
get_mem_usage() {
  local mem_total mem_avail used pct
  mem_total_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  mem_avail_kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
  if [[ -z "$mem_total_kb" || -z "$mem_avail_kb" ]]; then
    echo "0.0"
    return
  fi
  used_kb=$((mem_total_kb - mem_avail_kb))
  pct=$(awk -v u="$used_kb" -v t="$mem_total_kb" 'BEGIN { printf "%.1f", (u / t) * 100 }')
  echo "$pct"
}

cpu=$(get_cpu_usage)
mem=$(get_mem_usage)

# convert threshold to float compare
threshold_f="$THRESHOLD.0"

# function to compare floats via awk; returns 0 if a >= b
ge() { awk -v a="$1" -v b="$2" 'BEGIN { exit (a >= b) ? 0 : 1 }' ; }

unhealthy=0
msg=""

if ge "$cpu" "$threshold_f"; then
  unhealthy=1
  msg+="CPU usage ${cpu}% >= ${THRESHOLD}% -> ALERT\n"
fi

if ge "$mem" "$threshold_f"; then
  unhealthy=1
  msg+="Memory usage ${mem}% >= ${THRESHOLD}% -> ALERT\n"
fi

if [[ $unhealthy -eq 1 ]]; then
  echo "SYSTEM STATUS: UNHEALTHY"
  if [[ "$DETAILS" -eq 1 ]]; then
    echo -e "$msg"
  fi
  exit 1
else
  echo "SYSTEM STATUS: HEALTHY"
  if [[ "$DETAILS" -eq 1 ]]; then
    printf "CPU: %s%%, Memory: %s%% (threshold: %s%%)\n" "$cpu" "$mem" "$THRESHOLD"
  fi
  exit 0
fi
