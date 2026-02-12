# Jisoo's Project Knowledge

> What I've learned about this project

## Project Context (from import)

**User:** hyomin  
**Project:** Server process monitoring system  
**Stack:** Bash (monitoring scripts), Python (API server)  

**Monitoring Scripts:**
- `process_monitor/monitor_standalone.sh` — Human-readable output with colors
- `process_monitor/monitor_salt.sh` — JSON output, Salt-compatible

**Script Functionality:**
- Snapshot mode: Capture current state (services, processes, ports)
- Compare mode: Compare current state against snapshot
- Tracks: systemd services (running/enabled), processes, listening ports
- Excludes: kernel processes (kworker, kswapd, etc.)
- Storage: `/var/tmp/process_snapshot/`

**API Server:**
- `process_monitor/test_api_server.py` — Python HTTP server
- Receives POST requests with JSON monitoring results
- Stores results to `/var/log/monitor/`
- Port: 8080 (configurable)

**Data Format:**
JSON output includes: hostname, timestamp, status, has_issues, services (stopped/new), processes (stopped), ports (missing)

## Learnings

_(This section will grow as I work on the project)_
