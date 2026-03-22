#!/bin/bash

# health-check.sh - System health monitor for Rheo
# Returns exit code 0 if all checks pass, non-zero if issues found

# CPU usage threshold (%) - alert if sustained high usage
CPU_THRESHOLD=99

# Memory usage threshold (%)
MEM_THRESHOLD=90

# Disk usage threshold (%)
DISK_THRESHOLD=90

# Process count threshold
PROC_THRESHOLD=500

# Check CPU usage (1 minute average)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
if (( $(echo "$CPU_USAGE > $CPU_THRESHOLD" | bc -l) )); then
    echo "HIGH CPU: ${CPU_USAGE}% (threshold: ${CPU_THRESHOLD}%)"
    exit 1
fi

# Check memory usage
MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
if (( $(echo "$MEM_USAGE > $MEM_THRESHOLD" | bc -l 2>/dev/null) )); then
    echo "HIGH MEMORY: ${MEM_USAGE}% (threshold: ${MEM_THRESHOLD}%)"
    exit 1
fi

# Check disk usage on root filesystem
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
    echo "HIGH DISK: ${DISK_USAGE}% (threshold: ${DISK_THRESHOLD}%)"
    exit 1
fi

# Check for too many processes
PROC_COUNT=$(ps aux | wc -l)
if [ "$PROC_COUNT" -gt "$PROC_THRESHOLD" ]; then
    echo "HIGH PROCESS COUNT: $PROC_COUNT (threshold: $PROC_THRESHOLD)"
    exit 1
fi

# Check for zombie processes
ZOMBIE_COUNT=$(ps aux | awk '$8 ~ /^Z/ { count++ } END { print count+0 }')
if [ "$ZOMBIE_COUNT" -gt 10 ]; then
    echo "ZOMBIE PROCESSES: $ZOMBIE_COUNT found"
    exit 1
fi

# Check for stuck Rheo processes (running >24h without progress)
STUCK_RHEO=$(ps -eo pid,etime,cmd | grep -E "(rheo|orchestrator)" | grep -v grep | awk '$2 ~ /^[2-9][0-9]-/ || $2 ~ /^[1-9][0-9][0-9]-/ { print $1, $2, $3 }')
if [ -n "$STUCK_RHEO" ]; then
    echo "STUCK RHEO PROCESSES (>24h):"
    echo "$STUCK_RHEO"
    exit 1
fi

# Check load average
LOAD_AVG=$(uptime | awk '{print $10}' | sed 's/,//')
CORE_COUNT=$(nproc)
if (( $(echo "$LOAD_AVG > $CORE_COUNT * 2" | bc -l 2>/dev/null) )); then
    echo "HIGH LOAD AVERAGE: $LOAD_AVG (cores: $CORE_COUNT)"
    exit 1
fi

# All checks passed
exit 0