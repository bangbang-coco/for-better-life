# Lisa's Project Knowledge

> What I've learned about this project

## Project Context (from import)

**User:** hyomin  
**Project:** Server process monitoring system  
**Documentation Focus:** User guides, examples, and operational documentation

**Existing Documentation:**
- `README.md` (root) — Project overview
- `process_monitor/README.md` — Detailed usage guide (Korean)
- `process_monitor/SALT_MASTER_SETUP.md` — Salt Master architecture and setup
- `process_monitor/salt_state_example/README.md` — Salt state examples

**Documentation Status:**
- Documentation is in Korean (per project policy: docs in Korean, code comments in English)
- Comprehensive coverage of standalone mode, Salt mode, API integration
- Includes examples, workflows, and troubleshooting

**Key Scripts:**
- `monitor_standalone.sh` — Single server monitoring
- `monitor_salt.sh` — Salt-compatible with JSON output
- `test_api_server.py` — API server for centralized results
- `start_api_server.sh` — Quick start script

**User Workflows:**
1. Standalone: snapshot → reboot → compare
2. Salt batch: deploy scripts → snapshot all → reboot all → compare + collect results
3. API integration: compare with `--api-url` flag for automated result submission

## Learnings

_(This section will grow as I work on the project)_
