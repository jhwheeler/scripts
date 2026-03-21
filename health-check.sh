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

# Check for any process using >CPU_THRESHOLD% CPU
# Exclude this script, its ancestors (openclaw invoking us), and short-lived transient processes
# Build exclusion list: self + all ancestor PIDs up to init
_exclude_pids="$$"
_p=$$
while [ "$_p" -gt 1 ] 2>/dev/null; do
    _p=$(awk '{print $4}' /proc/$_p/stat 2>/dev/null) || break
    _exclude_pids="${_exclude_pids}|${_p}"
done
# Use ps with cumulative CPU time; skip processes with <10s total CPU (transient spikes)
high_cpu=$(ps -eo pid,user,%cpu,%mem,cputime,args --sort=-%cpu | awk -v thresh="$CPU_THRESHOLD" -v excl="$_exclude_pids" '
    BEGIN { split(excl, ep, "|"); for (i in ep) expids[ep[i]]=1 }
    NR>1 && $3>thresh && !($1 in expids) && $6!="ps" && $6!="awk" {
        # Skip legitimate high-CPU tasks
        if ($0 ~ /WhisperModel|whisper|transcribe/) next  # Audio transcription
        if ($0 ~ /ffmpeg/) next  # Video/audio processing
        if ($0 ~ /cargo build|rustc|gcc|g\+\+|make/) next  # Compilation
        if ($0 ~ /npm install|yarn|pip install/) next  # Package installation
        
        # Parse cputime HH:MM:SS or MM:SS into total seconds
        n=split($5, t, ":")
        if (n==3) secs=t[1]*3600+t[2]*60+t[3]
        else if (n==2) secs=t[1]*60+t[2]
        else secs=$5
        if (secs < 10) next  # skip transient startup spikes
        
        # Extract command name from args for display
        cmd = $6; sub(/^.*\//, "", cmd)  # strip path
        printf "  PID %s (%s) user=%s CPU=%.1f%% MEM=%.1f%% cputime=%s\n", $1, cmd, $2, $3, $4, $5
    }')
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
