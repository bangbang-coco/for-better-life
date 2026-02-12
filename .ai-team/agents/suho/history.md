# Suho's Project Knowledge

> What I've learned about this project

## Project Context (from import)

**User:** hyomin  
**Project:** Server process monitoring system  
**Stack:** Bash, Python, Salt Stack, Docker  
**Purpose:** Track systemd services and processes before/after server reboots across multiple Linux servers  
**Key Components:**
- `monitor_standalone.sh` — Single server monitoring with color output
- `monitor_salt.sh` — Salt-compatible version with JSON output
- `test_api_server.py` — HTTP API server for centralized result collection
- Docker containerization for API server deployment

**Architecture:**
- Distributed monitoring across multiple servers via Salt Stack
- Centralized result collection via HTTP API
- Snapshot-based comparison (before/after reboot)
- JSON output format for programmatic processing

## Learnings

_(This section will grow as I work on the project)_
