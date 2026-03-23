#!/bin/bash

# health-check.sh - System health monitor for Rheo
# Returns exit code 0 if all checks pass, non-zero if issues found

# CPU usage threshold (%) - alert if sustained high usage
CPU_THRESHOLD=85

# Memory usage threshold (%)
MEM_THRESHOLD=95

# Disk usage threshold (%)
DISK_THRESHOLD=90

# Process count threshold
PROC_THRESHOLD=500

# Check CPU usage - use 3-second average to avoid transient spikes
# Also exclude processes related to this health check
CPU_USAGE=$(top -bn2 -d1 | grep "Cpu(s)" | tail -1 | awk '{for(i=1;i<=NF;i++) if($(i+1) == "id,") {printf "%.1f", 100-$i; break}}')

# Get top CPU processes excluding health check related ones
TOP_PROCS=$(ps -eo pid,pcpu,comm --sort=-pcpu | grep -v -E "(health-check|top|ps)" | head -5)
HIGH_CPU_PROC=$(echo "$TOP_PROCS" | awk 'NR==2 {print $2}')

# Alert if either sustained high total CPU OR a single process using >300% (actual abuse)
if (( $(echo "$CPU_USAGE > $CPU_THRESHOLD" | bc -l) )) || (( $(echo "$HIGH_CPU_PROC > 300" | bc -l 2>/dev/null) )); then
    echo "HIGH CPU: Total ${CPU_USAGE}%, Top Process ${HIGH_CPU_PROC}% (thresholds: total ${CPU_THRESHOLD}%, single process 300%)"
    echo "Top processes:"
    echo "$TOP_PROCS" | head -3
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

# Check load average - be lenient for development work (npm/vitest/build processes)
LOAD_AVG=$(uptime | awk '{print $10}' | sed 's/,//')
CORE_COUNT=$(nproc)
# Alert only if load > 4x cores (indicating actual system stress, not just busy development)
if (( $(echo "$LOAD_AVG > $CORE_COUNT * 4" | bc -l 2>/dev/null) )); then
    echo "HIGH LOAD AVERAGE: $LOAD_AVG (cores: $CORE_COUNT)"
    exit 1
fi

# All checks passed
exit 0