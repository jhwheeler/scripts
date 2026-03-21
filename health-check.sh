#!/bin/bash

# System Health Check Script
# Exit 0 if all checks pass, non-zero if issues detected

EXIT_CODE=0

# Check CPU usage (warn if >90%)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
if (( $(echo "$CPU_USAGE > 90" | bc -l) )); then
    echo "HIGH CPU: ${CPU_USAGE}%"
    EXIT_CODE=1
fi

# Check memory usage (warn if >90%)
MEM_USAGE=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
if (( $(echo "$MEM_USAGE > 90" | bc -l) )); then
    echo "HIGH MEMORY: ${MEM_USAGE}%"
    EXIT_CODE=1
fi

# Check disk usage (warn if >85%)
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 85 ]; then
    echo "HIGH DISK: ${DISK_USAGE}%"
    EXIT_CODE=1
fi

# Check if Rheo processes are consuming excessive resources
RHEO_PROCS=$(pgrep -f "rheo" | wc -l)
if [ "$RHEO_PROCS" -gt 20 ]; then
    echo "TOO MANY RHEO PROCESSES: $RHEO_PROCS"
    EXIT_CODE=1
fi

# Check for zombie processes
ZOMBIES=$(ps aux | awk '$8 ~ /^Z/ { count++ } END { print count+0 }')
if [ "$ZOMBIES" -gt 5 ]; then
    echo "ZOMBIE PROCESSES: $ZOMBIES"
    EXIT_CODE=1
fi

# Check system load (warn if 1-min load > 2x CPU cores)
CORES=$(nproc)
LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | awk '{ print $1 }' | sed 's/,//')
THRESHOLD=$(echo "$CORES * 2" | bc)
if (( $(echo "$LOAD > $THRESHOLD" | bc -l) )); then
    echo "HIGH LOAD: $LOAD (threshold: $THRESHOLD)"
    EXIT_CODE=1
fi

exit $EXIT_CODE