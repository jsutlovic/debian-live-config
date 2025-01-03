#!/usr/bin/bash

# This script is intended to wrap a build script and run a task at intervals
# (default: check filesystem sizes) until the build script stops.

usage=<< EOF
Usage: [INTERVAL=2] [TRACK_OUTPUT=fs_tacking.json] [BUILD_UPDATE=] $0 task

task:         Any valid command to track filesystem use for
INTERVAL:     How often (in seconds) to re-run BUILD_UPDATE
TRACK_OUTPUT: File to redirect BUILD_UPDATE output to
BUILD_UPDATE: Command to produce tracking output
EOF

AWK=${AWK:-/usr/bin/awk}
interval=${INTERVAL:-2}
track_output=${TRACK_OUTPUT:-fs_tracking.json}
build_update=${BUILD_UPDATE:-_chkfs}
app="$*"

# Default filesystem check script

_chkfs() {
  # awk script to process the output of df -P -k
  read -r -d '' freespace_json <<'EOF'
BEGIN {
  printf "{"
  printf "\"server\": \"" machine "\","
  printf "\"timestamp\": \"" timestamp "\","
  if (app) {
    printf "\"app\": \"" app "\","
  }
  printf "\"filesystems\":["
}
{
  if ($1 != "Filesystem") {
    if (i) {
      printf ","
    }
    printf "{\"mount\":\"" $6 "\",\"size\":\"" $2 "\",\"used\":\"" $3 \
            "\",\"avail\":\"" $4 "\",\"used_pct\":\"" $5 "\", \"fs\":\"" $1 "\"}"
    i++
  }
}
END {
  print "]}"
}
EOF

  df -P -k | grep -vE "(/snap/core|^//)" | sed 's/%//g' | $AWK -v app="${app}" -v machine="$(hostname)" -v timestamp="$(date +%s)" -f <(echo "$freespace_json")
}

_background() {
  while true; do
    "$build_update" >> "$track_output"
    sleep $interval
  done
}

if [[ -z "$interval" || -z "$track_output" || -z "$build_update" ]]; then
  echo $usage
  exit 1
else
  echo "Running $build_update piped to $track_output every $interval seconds"
fi

# Background the output task
_background &

trap 'kill $(jobs -p) 2>/dev/null' EXIT

bash -c "$app"

kill $(jobs -p)
