#!/bin/bash
# System health check — runs periodically via cron
# Only outputs something if there's a problem (non-zero exit = trouble)

LOAD_THRESHOLD=4.0
CPU_THRESHOLD=80
MEM_THRESHOLD=50

problems=""

# Check load average (1-min)
load=$(awk '{print $1}' /proc/loadavg)
if awk "BEGIN {exit !($load > $LOAD_THRESHOLD)}"; then
    # Check if it's sustained (5-min also high) vs transient spike
    load5=$(awk '{print $2}' /proc/loadavg)
    if awk "BEGIN {exit !($load5 > $LOAD_THRESHOLD)}"; then
        problems="${problems}SUSTAINED HIGH LOAD: 1m=${load} 5m=${load5} (threshold: ${LOAD_THRESHOLD})\n"
    fi
fi

# Check for any process using >CPU_THRESHOLD% CPU (exclude this script and ps itself)
high_cpu=$(ps aux --sort=-%cpu | awk -v thresh="$CPU_THRESHOLD" -v mypid="$$" 'NR>1 && $3>thresh && $2!=mypid && $11!="ps" && $11!="awk" {printf "  PID %s (%s) user=%s CPU=%.1f%% MEM=%.1f%%\n", $2, $11, $1, $3, $4}')
if [ -n "$high_cpu" ]; then
    problems="${problems}HIGH CPU PROCESSES:\n${high_cpu}\n"
fi

# Check for any process using >MEM_THRESHOLD% memory
high_mem=$(ps aux --sort=-%mem | awk -v thresh="$MEM_THRESHOLD" 'NR>1 && $4>thresh {printf "  PID %s (%s) user=%s CPU=%.1f%% MEM=%.1f%%\n", $2, $11, $1, $3, $4}')
if [ -n "$high_mem" ]; then
    problems="${problems}HIGH MEMORY PROCESSES:\n${high_mem}\n"
fi

# Check for zombie processes
zombies=$(ps aux | awk '$8 ~ /^Z/ {count++} END {print count+0}')
if [ "$zombies" -gt 0 ]; then
    problems="${problems}ZOMBIE PROCESSES: ${zombies}\n"
fi

# Check disk usage on main partitions
disk_full=$(df -h / /home 2>/dev/null | awk 'NR>1 && int($5)>90 {printf "  %s at %s\n", $6, $5}')
if [ -n "$disk_full" ]; then
    problems="${problems}DISK NEARLY FULL:\n${disk_full}\n"
fi

if [ -n "$problems" ]; then
    echo "=== SYSTEM HEALTH ALERT ==="
    echo ""
    echo -e "$problems"
    echo "--- top snapshot ---"
    top -bn1 | head -15
    echo ""
    echo "--- top processes by CPU ---"
    ps aux --sort=-%cpu | head -10
    exit 1
else
    exit 0
fi
