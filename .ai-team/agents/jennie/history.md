# Jennie's Project Knowledge

> What I've learned about this project

## Project Context (from import)

**User:** hyomin  
**Project:** Server process monitoring system  
**Testing Focus:** Validate monitoring accuracy, edge cases, and failure handling

**System Under Test:**
- Bash monitoring scripts (snapshot + compare logic)
- Python HTTP API server
- Salt Stack orchestration (batch execution, result collection)

**Test Scenarios to Consider:**
- Snapshot creation and storage
- Comparison accuracy (services stopped, new services, process changes)
- Port tracking and missing port detection
- JSON output format validation
- API server request/response handling
- Failure cases: missing snapshot, permission errors, network failures
- Salt batch execution and result aggregation

**Key Files:**
- `process_monitor/monitor_standalone.sh`
- `process_monitor/monitor_salt.sh`
- `process_monitor/test_api_server.py`

## Learnings

_(This section will grow as I work on the project)_
