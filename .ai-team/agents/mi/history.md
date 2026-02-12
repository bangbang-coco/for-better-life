# Mi's Project Knowledge

> What I've learned about this project

## Project Context (from import)

**User:** hyomin  
**Project:** Server process monitoring system  
**Stack:** Bash, Python, Salt Stack, Docker  

**Infrastructure:**
- Salt Stack for mass server orchestration
- Docker containerization for API server
- Multiple Linux servers to monitor
- Centralized API endpoint for result collection

**Key Files:**
- `process_monitor/monitor_standalone.sh` — Single server script
- `process_monitor/monitor_salt.sh` — Salt-compatible script with `--json` and `--api-url` flags
- `process_monitor/test_api_server.py` — Python HTTP server
- `process_monitor/Dockerfile` — API server container
- `process_monitor/docker-compose.yml` — Container orchestration
- `process_monitor/salt_state_example/` — Salt state examples

**Deployment Pattern:**
- Scripts deployed via Salt to `/opt/scripts/`
- API server runs in Docker on Salt Master
- Results sent via HTTP POST with JSON payload

## Learnings

_(This section will grow as I work on the project)_
