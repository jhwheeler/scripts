#!/usr/bin/env bash
# rheo-operator.sh — Deterministic pipeline operator for Rheo tasks
# Applies the response matrix from HEARTBEAT.md to all rheo/ tasks.
# Usage: rheo-operator.sh [--dry-run]

set -o pipefail
export PATH="$HOME/go/bin:$PATH"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

declare -a ACTIONS
declare -a ERRORS

run_cmd() {
  if $DRY_RUN; then
    ACTIONS+=("DRY-RUN: $1")
    return 0
  fi
  local result
  result=$(eval "$1" 2>&1) || true
  echo "$result"
}

# Get status
STATUS=$(rheo status 2>&1) || true

# Parse into per-session blocks
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Split status into session files
current_file=""
while IFS= read -r line; do
  if [[ "$line" =~ ^Session:\ (rheo/[^ ]+) ]]; then
    session="${BASH_REMATCH[1]}"
    current_file="$TMPDIR/$(echo "$session" | tr '/' '_')"
    echo "$line" > "$current_file"
  elif [[ -n "$current_file" && "$line" =~ ^Session: ]]; then
    current_file=""
  elif [[ -n "$current_file" ]]; then
    echo "$line" >> "$current_file"
  fi
done <<< "$STATUS"

# Process each rheo session
for session_file in "$TMPDIR"/rheo_*; do
  [[ -f "$session_file" ]] || continue

  header=$(head -1 "$session_file")
  session=$(echo "$header" | grep -oP 'Session: \K[^ ]+')
  phase=$(echo "$header" | grep -oP '\(phase: \K[^)]+')
  pr_num=$(echo "$header" | grep -oP 'PR: #\K\d+' || true)
  block=$(cat "$session_file")

  # 1. PAUSED → resume
  if echo "$block" | grep -q "PAUSED"; then
    result=$(run_cmd "rheo resume '$session'")
    if echo "$result" | grep -q "Launched\|launched"; then
      ACTIONS+=("Resumed $session: $(echo "$result" | grep -i launch)")
    elif echo "$result" | grep -q "No resumable"; then
      ACTIONS+=("No resumable runs for $session")
    elif $DRY_RUN; then
      : # already logged
    else
      ERRORS+=("Resume failed for $session: $result")
    fi
    continue
  fi

  # 2. Ready for PR → review
  if [[ "$phase" == "ready for PR" ]]; then
    result=$(run_cmd "rheo review '$session'")
    if echo "$result" | grep -q "Code review started"; then
      ACTIONS+=("Started review: $session")
    elif $DRY_RUN; then
      :
    else
      ERRORS+=("Review failed for $session: $result")
    fi
    continue
  fi

  # 3. Reviewer done → check verdict
  if echo "$phase" | grep -qi "review"; then
    if echo "$block" | grep -q "reviewer.*done"; then
      # Find latest review file
      worktree="$HOME/.rheo/worktrees/$session"
      review_file=$(ls "$worktree/.rheo/"review-*.md 2>/dev/null | sort -V | tail -1 || true)
      verdict="unknown"
      [[ -n "$review_file" ]] && verdict=$(grep -oP 'Verdict: \K\S+' "$review_file" 2>/dev/null || echo "unknown")

      if [[ "$verdict" == "NO_CHANGES_NEEDED" && -n "$pr_num" ]]; then
        ACTIONS+=("MERGE_CANDIDATE: $session PR #$pr_num (NO_CHANGES_NEEDED)")
      elif [[ "$verdict" == "NO_CHANGES_NEEDED" ]]; then
        result=$(run_cmd "rheo approve '$session'")
        ACTIONS+=("Approved $session (clean review): $result")
      elif [[ "$verdict" == "CHANGES_RECOMMENDED" ]]; then
        result=$(run_cmd "rheo approve '$session'")
        ACTIONS+=("Approved $session (changes recommended → fix cycle): $result")
      fi
    fi
    continue
  fi

  # 4. Evaluator done PASS → approve
  if echo "$phase" | grep -qi "evaluator"; then
    if echo "$block" | grep -q "evaluator.*done.*PASS"; then
      result=$(run_cmd "rheo approve '$session'")
      ACTIONS+=("Approved evaluator: $session: $result")
    elif echo "$block" | grep -q "FAIL_PLAN_MISMATCH"; then
      result=$(run_cmd "rheo iterate '$session' 'Address plan mismatch'")
      ACTIONS+=("Iterated $session (plan mismatch): $result")
    fi
    continue
  fi

  # 5. Running — no action
done

# Output JSON
action_count=${#ACTIONS[@]}
error_count=${#ERRORS[@]}
merge_count=0
for a in "${ACTIONS[@]+"${ACTIONS[@]}"}"; do
  [[ "$a" == *MERGE_CANDIDATE* ]] && ((merge_count++)) || true
done

{
  echo "{"
  echo "  \"status\": \"completed\","
  echo "  \"actions_taken\": $action_count,"
  echo "  \"merge_candidates\": $merge_count,"
  echo "  \"errors_count\": $error_count,"
  echo "  \"actions\": ["
  first=true
  for a in "${ACTIONS[@]+"${ACTIONS[@]}"}"; do
    $first || echo ","
    printf '    "%s"' "$(echo "$a" | sed 's/"/\\"/g' | tr '\n' ' ')"
    first=false
  done
  echo ""
  echo "  ],"
  echo "  \"errors\": ["
  first=true
  for e in "${ERRORS[@]+"${ERRORS[@]}"}"; do
    $first || echo ","
    printf '    "%s"' "$(echo "$e" | sed 's/"/\\"/g' | tr '\n' ' ')"
    first=false
  done
  echo ""
  echo "  ]"
  echo "}"
}
