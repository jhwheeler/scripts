#!/bin/bash
# print-queue.sh BOOKLET.pdf... : print several booklets one after another, waiting for each
# to finish (the printer takes one direct job at a time). Stops if a job is aborted or cancelled.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
for pdf in "$@"; do
  echo "$(date +%H:%M:%S) sending $(basename "$pdf")"
  out="$("$here/print-booklet.sh" "$pdf" 2>&1)" || { echo "$out"; echo "FAILED to send $(basename "$pdf")"; exit 1; }
  job="$(echo "$out" | grep -o 'job-id (integer) = [0-9]*' | grep -o '[0-9]*$')"
  [ -n "$job" ] || { echo "$out"; echo "no job id for $(basename "$pdf")"; exit 1; }
  cat > "$tmp/job.test" <<T
{
OPERATION Get-Job-Attributes
GROUP operation-attributes-tag
ATTR charset attributes-charset utf-8
ATTR language attributes-natural-language en
ATTR uri printer-uri \$uri
ATTR integer job-id $job
ATTR name requesting-user-name booklet
STATUS successful-ok
}
T
  prev=""
  while :; do
    a="$(ipptool -tv ipp://localhost:60000/ipp/print "$tmp/job.test" 2>/dev/null | grep -E 'job-state |job-state-reasons|impressions-completed' | sed 's/^ *//' | tr '\n' ';')"
    [ "$a" != "$prev" ] && echo "$(date +%H:%M:%S)   job $job: $a"; prev="$a"
    case "$a" in *"job-state (enum) = completed"*) break;; *"= aborted"*|*"= canceled"*) echo "job $job did not complete; stopping"; exit 1;; esac
    sleep 10
  done
done
echo "$(date +%H:%M:%S) all done"
