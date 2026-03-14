#!/bin/bash
# ⚡ Lightning Tools — Command Rewrite Benchmark
# Measures the actual time difference between slow Unix tools and their
# fast alternatives across realistic workloads.
#
# Usage: ./benchmark/benchmark-rewrites.sh [target-directory]
#        Defaults to current directory.

set -euo pipefail

TARGET_DIR="${1:-.}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
ITERATIONS=5
WARMUP=1

# ── Portable nanosecond timer ─────────────────────────────────────
get_time_ns() {
  if date +%s%N | grep -q N; then
    # macOS: date doesn't support %N, fall back to perl
    perl -MTime::HiRes -e 'printf "%.0f\n", Time::HiRes::time()*1e9'
  else
    date +%s%N
  fi
}

# ── Time a command (returns milliseconds) ─────────────────────────
time_cmd() {
  local cmd="$1"
  local start end
  start=$(get_time_ns)
  eval "$cmd" > /dev/null 2>&1 || true
  end=$(get_time_ns)
  echo $(( (end - start) / 1000000 ))
}

# ── Compute median of space-separated values ──────────────────────
median() {
  echo "$@" | tr ' ' '\n' | sort -n | awk '{a[NR]=$1} END{print a[int((NR+1)/2)]}'
}

# ── Run a single benchmark ────────────────────────────────────────
# Args: label, slow_cmd, fast_cmd, fast_tool_binary
RESULTS=""
TOTAL_SLOW=0
TOTAL_FAST=0
TESTS_RUN=0

run_benchmark() {
  local label="$1"
  local slow_cmd="$2"
  local fast_cmd="$3"
  local fast_bin="$4"

  # Check if fast tool is available
  if ! command -v "$fast_bin" &>/dev/null; then
    printf "  %-14s %10s %10s %10s    %s → %s (not installed)\n" \
      "$label" "-" "-" "SKIP" "$fast_bin" "$fast_bin"
    return
  fi

  # Warm-up runs (prime filesystem cache)
  for ((i=0; i<WARMUP; i++)); do
    eval "$slow_cmd" > /dev/null 2>&1 || true
    eval "$fast_cmd" > /dev/null 2>&1 || true
  done

  # Timed runs
  local slow_times=()
  local fast_times=()
  for ((i=0; i<ITERATIONS; i++)); do
    slow_times+=("$(time_cmd "$slow_cmd")")
    fast_times+=("$(time_cmd "$fast_cmd")")
  done

  local slow_median fast_median speedup
  slow_median=$(median "${slow_times[@]}")
  fast_median=$(median "${fast_times[@]}")

  if [[ "$fast_median" -gt 0 ]]; then
    speedup=$(awk "BEGIN{printf \"%.1f\", $slow_median / $fast_median}")
  else
    speedup="∞"
  fi

  local saved=$((slow_median - fast_median))

  printf "  %-14s %8d ms %8d ms %8sx %8d ms\n" \
    "$label" "$slow_median" "$fast_median" "$speedup" "$saved"

  TOTAL_SLOW=$((TOTAL_SLOW + slow_median))
  TOTAL_FAST=$((TOTAL_FAST + fast_median))
  TESTS_RUN=$((TESTS_RUN + 1))
}

# ── Count files in target ─────────────────────────────────────────
FILE_COUNT=$(find "$TARGET_DIR" -type f -not -path '*/.git/*' 2>/dev/null | wc -l)

# ── Header ────────────────────────────────────────────────────────
echo ""
echo "⚡ Lightning Tools — Rewrite Benchmark"
echo "  Target:     $TARGET_DIR"
echo "  Files:      $FILE_COUNT"
echo "  Iterations: $ITERATIONS (median of $ITERATIONS runs, $WARMUP warmup)"
echo ""
printf "  %-14s %11s %11s %10s %10s\n" "Test" "Slow" "Fast" "Speedup" "Saved"
echo "  ──────────────────────────────────────────────────────────────────"

# ── Benchmarks ────────────────────────────────────────────────────

# grep → rg: recursive text search
run_benchmark "grep-search" \
  "grep -rn 'import' '$TARGET_DIR'" \
  "rg -n 'import' '$TARGET_DIR'" \
  "rg"

# grep → rg: files-only match
run_benchmark "grep-files" \
  "grep -rl 'function\|def\|class' '$TARGET_DIR'" \
  "rg -l 'function|def|class' '$TARGET_DIR'" \
  "rg"

# grep → rg: case-insensitive
run_benchmark "grep-nocase" \
  "grep -rni 'error' '$TARGET_DIR'" \
  "rg -ni 'error' '$TARGET_DIR'" \
  "rg"

# find → fd: find by extension
run_benchmark "find-ext" \
  "find '$TARGET_DIR' -name '*.sh' -type f" \
  "fd --type f '\.sh$' '$TARGET_DIR'" \
  "fd"

# find → fd: find by name pattern
run_benchmark "find-name" \
  "find '$TARGET_DIR' -name '*.json' -type f" \
  "fd --type f '\.json$' '$TARGET_DIR'" \
  "fd"

# cat → bat: read a file
LARGEST_FILE=$(find "$TARGET_DIR" -type f -not -path '*/.git/*' -printf '%s %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
if [[ -n "$LARGEST_FILE" ]]; then
  run_benchmark "cat-read" \
    "cat '$LARGEST_FILE'" \
    "bat --plain --paging=never '$LARGEST_FILE'" \
    "bat"
fi

# du → dust: disk usage
run_benchmark "du-usage" \
  "du -sh '$TARGET_DIR'" \
  "dust '$TARGET_DIR'" \
  "dust"

# sed → sd: substitution (read-only via pipe, no file modification)
if [[ -n "$LARGEST_FILE" ]]; then
  run_benchmark "sed-replace" \
    "sed 's/the/THE/g' '$LARGEST_FILE'" \
    "sd 'the' 'THE' '$LARGEST_FILE'" \
    "sd"
fi

# ── Summary ───────────────────────────────────────────────────────
echo "  ──────────────────────────────────────────────────────────────────"

if [[ "$TESTS_RUN" -gt 0 ]]; then
  AVG_SPEEDUP=$(awk "BEGIN{printf \"%.1f\", $TOTAL_SLOW / ($TOTAL_FAST > 0 ? $TOTAL_FAST : 1)}")
  TOTAL_SAVED=$((TOTAL_SLOW - TOTAL_FAST))

  printf "  %-14s %8d ms %8d ms %8sx %8d ms\n" \
    "TOTAL" "$TOTAL_SLOW" "$TOTAL_FAST" "$AVG_SPEEDUP" "$TOTAL_SAVED"
  echo ""
  echo "  Estimated savings per 100 Bash commands: ~$((TOTAL_SAVED * 100 / TESTS_RUN / 1000))s"
fi

if [[ "$FILE_COUNT" -lt 100 ]]; then
  echo ""
  echo "  Note: Target has only $FILE_COUNT files. For more meaningful results,"
  echo "  run against a larger codebase: ./benchmark/benchmark-rewrites.sh /path/to/large/project"
fi
echo ""
