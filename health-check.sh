#!/bin/bash

# System Health Check Script
# Exit 0 if all checks pass, non-zero if issues detected

EXIT_CODE=0

# Check CPU usage (warn if >95% for sustained periods)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
# Only alert on sustained high CPU by checking load average too
CORES=$(nproc)
LOAD_1MIN=$(uptime | awk -F'load average:' '{ print $2 }' | awk '{ print $1 }' | sed 's/,//')
LOAD_THRESHOLD=$(echo "$CORES * 3" | bc)
if (( $(echo "$CPU_USAGE > 95" | bc -l) )) && (( $(echo "$LOAD_1MIN > $LOAD_THRESHOLD" | bc -l) )); then
    echo "SUSTAINED HIGH CPU: ${CPU_USAGE}% (load: $LOAD_1MIN)"
    EXIT_CODE=1
fi

# Check memory usage (warn if >90%)
MEM_USAGE=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
if (( $(echo "$MEM_USAGE > 90" | bc -l) )); then
    echo "HIGH MEMORY: ${MEM_USAGE}%"
    EXIT_CODE=1
fi

# Check disk usage (warn if >95%)
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 95 ]; then
    echo "HIGH DISK: ${DISK_USAGE}%"
    EXIT_CODE=1
fi

# Check if Rheo processes are consuming excessive resources (increased threshold)
RHEO_PROCS=$(pgrep -f "rheo" | wc -l)
if [ "$RHEO_PROCS" -gt 50 ]; then
    echo "TOO MANY RHEO PROCESSES: $RHEO_PROCS"
    EXIT_CODE=1
fi

# Check for zombie processes
ZOMBIES=$(ps aux | awk '$8 ~ /^Z/ { count++ } END { print count+0 }')
if [ "$ZOMBIES" -gt 5 ]; then
    echo "ZOMBIE PROCESSES: $ZOMBIES"
    EXIT_CODE=1
fi

# Check system load (warn if 1-min load > 4x CPU cores for extended periods)
# Note: Removed duplicate CORES/LOAD calculation since it's now done in CPU check above
# Only alert if 5-min average is also high, indicating sustained load
LOAD_5MIN=$(uptime | awk -F'load average:' '{ print $2 }' | awk '{ print $2 }' | sed 's/,//')
THRESHOLD=$(echo "$CORES * 4" | bc)
THRESHOLD_5MIN=$(echo "$CORES * 3" | bc)
if (( $(echo "$LOAD_1MIN > $THRESHOLD" | bc -l) )) && (( $(echo "$LOAD_5MIN > $THRESHOLD_5MIN" | bc -l) )); then
    echo "SUSTAINED HIGH LOAD: 1min=$LOAD_1MIN 5min=$LOAD_5MIN (thresholds: $THRESHOLD/$THRESHOLD_5MIN)"
    EXIT_CODE=1
fi

exit $EXIT_CODE