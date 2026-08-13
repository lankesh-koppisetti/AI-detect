Monitor CPU & Memory Health
===========================

Overview
--------
This repository includes a simple Linux Bash script (monitor_health.sh) that checks system CPU and memory usage and alerts when either metric meets or exceeds a configurable threshold (default: 60%). When usage >= threshold the script reports the system as UNHEALTHY (exit code 1). Otherwise it reports HEALTHY (exit code 0).

Files
-----
- monitor_health.sh — Bash monitoring script
- README.md — this file

Requirements
------------
- Linux system with /proc filesystem (most distributions)
- Bash
- awk

Usage
-----
1. Make the script executable:
   chmod +x monitor_health.sh

2. Basic run (default threshold 60%):
   ./monitor_health.sh

3. Set a custom threshold (e.g., 75%):
   ./monitor_health.sh --threshold 75

4. Show explanation about what the script checks and how it works:
   ./monitor_health.sh --explain

Behavior
--------
- CPU: sampled from /proc/stat over a 1-second interval to compute percent busy (more robust than a single instant value).
- Memory: uses MemTotal and MemAvailable from /proc/meminfo to compute used percent.
- If either CPU or memory usage is greater than or equal to the threshold, the script prints an ALERT summary and exits with code 1.
- Otherwise it prints HEALTHY and exits with code 0.

Exit codes
----------
- 0: HEALTHY (both metrics below threshold)
- 1: UNHEALTHY (at least one metric >= threshold)
- 2: Invalid usage or argument error

Examples
--------
- Check with default threshold:
  ./monitor_health.sh

- Check with custom threshold of 50%:
  ./monitor_health.sh --threshold 50

- Show explanation (no checks run):
  ./monitor_health.sh --explain

Notes & Recommendations
-----------------------
- Run periodically via cron or a monitoring system (Prometheus node exporter + alert rules are a more full-featured option).
- The script uses a 1-second sample for CPU; adjust if you need shorter or longer sampling windows.
- For production monitoring, integrate this check into your existing alerting and graphing stack.

License
-------
Use and modify as needed. No warranty.
