# Rosé's Project Knowledge

> What I've learned about this project

## Project Context (from import)

**User:** hyomin  
**Project:** Server process monitoring system  
**Frontend Scope:** Monitoring dashboard and visualization

**Current State:**
- Scripts exist: monitoring logic is implemented
- API server exists: HTTP endpoint for receiving results
- No frontend yet — opportunity to create monitoring dashboard

**Potential Dashboard Features:**
- Real-time server status overview
- Service status grid (running/stopped/new)
- Process comparison visualization
- Port monitoring display
- Historical trend charts
- Alert indicators for servers with issues

**Data Source:**
- HTTP API server (`test_api_server.py`) exposes monitoring results
- JSON format with hostname, timestamp, status, has_issues, services/processes/ports details

**Technical Considerations:**
- Need to design API endpoints for frontend consumption (GET operations)
- Real-time updates (WebSocket or polling)
- Multi-server dashboard layout
- Mobile-friendly design for on-call monitoring

## Learnings

_(This section will grow as I work on the project)_
