# Process Monitor

Scripts for comparing server process and service states before and after reboot.

## 📁 File Structure

- **monitor_standalone.sh** - Standalone server script (colored output, human-readable)
- **monitor_salt.sh** - Salt environment script (JSON output support)

## 🚀 Usage

### 1️⃣ Standalone Mode (Single Server)

```bash
# Before reboot - Create snapshot
./monitor_standalone.sh snapshot

# After reboot - Compare
./monitor_standalone.sh compare

# Check snapshot status
./monitor_standalone.sh status
```

### 2️⃣ Salt Environment (Multiple Servers)

#### Step 1: Create Snapshot (Before Reboot)
```bash
# Create snapshot on all servers
salt '*' cmd.run '/opt/scripts/monitor_salt.sh snapshot'
```

#### Step 2: Compare and Collect Results (After Reboot)
```bash
# Collect results in JSON format
salt '*' cmd.run '/opt/scripts/monitor_salt.sh compare --json' --out=json > /tmp/monitor_results.json

# Or in YAML format
salt '*' cmd.run '/opt/scripts/monitor_salt.sh compare --json' --out=yaml > /tmp/monitor_results.yaml
```

#### Step 3: Analyze Results
```bash
# Filter failed servers only
jq 'to_entries[] | select(.value.retcode != 0) | {hostname: .key, result: .value}' /tmp/monitor_results.json

# List stopped services
jq 'to_entries[] | select(.value.has_issues == true) | {hostname: .key, stopped_services: .value.services.stopped}' /tmp/monitor_results.json

# Summary report
jq 'to_entries[] | {hostname: .key, status: .value.status, issues: .value.has_issues}' /tmp/monitor_results.json
```

## 📊 JSON Output Format

```json
{
  "hostname": "server01",
  "timestamp": "2026-02-09 15:30:00",
  "status": "failure",
  "has_issues": true,
  "snapshot_time": "2026-02-09 14:00:00",
  "services": {
    "stopped": ["nginx.service", "mysql.service"],
    "new": ["temp-debug.service"]
  },
  "processes": {
    "stopped": ["nginx", "mysqld"]
  },
  "ports": {
    "missing": [":80", ":3306"]
  }
}
```

## 🎯 Salt State File Example

### monitor.sls
```yaml
# Deploy script
/opt/scripts/monitor_salt.sh:
  file.managed:
    - source: salt://scripts/monitor_salt.sh
    - mode: 755
    - makedirs: True

# Create snapshot before reboot
pre_reboot_snapshot:
  cmd.run:
    - name: /opt/scripts/monitor_salt.sh snapshot
    - require:
      - file: /opt/scripts/monitor_salt.sh
```

## 💡 Practical Workflow

### Mass Server Reboot Scenario

```bash
# 1. Deploy script
salt '*' cp.get_file salt://scripts/monitor_salt.sh /opt/scripts/monitor_salt.sh
salt '*' cmd.run 'chmod +x /opt/scripts/monitor_salt.sh'

# 2. Create snapshot before reboot
salt '*' cmd.run '/opt/scripts/monitor_salt.sh snapshot'

# 3. Reboot servers
salt '*' system.reboot

# 4. Compare after reboot (wait 5 minutes)
sleep 300
salt '*' cmd.run '/opt/scripts/monitor_salt.sh compare --json' --out=json > results_$(date +%Y%m%d_%H%M%S).json

# 5. Analyze results
cat results_*.json | jq 'to_entries[] | select(.value.has_issues == true)'
```

## 🔧 Advanced Configuration

### Execute specific group only
```bash
# Web group only
salt -G 'role:web' cmd.run '/opt/scripts/monitor_salt.sh compare --json'

# Specific datacenter
salt -G 'datacenter:seoul' cmd.run '/opt/scripts/monitor_salt.sh compare --json'
```

### Batch execution (load balancing)
```bash
# Execute 10 servers at a time
salt --batch-size 10 '*' cmd.run '/opt/scripts/monitor_salt.sh compare --json'

# Execute 25% ratio
salt --batch-size 25% '*' cmd.run '/opt/scripts/monitor_salt.sh compare --json'
```

## 📝 Snapshot Storage Location

- Default path: `/var/tmp/process_snapshot/`
- Snapshot files:
  - `services_running.txt` - Running services
  - `services_enabled.txt` - Enabled services
  - `processes.txt` - Running processes
  - `ports.txt` - Listening ports
  - `metadata.txt` - Metadata

## 🌐 HTTP API Integration

### Auto-send Results to API

```bash
# Send to API from single server
./monitor_salt.sh compare --json --api-url https://api.example.com/monitor

# Mass execution + API transmission with Salt
salt '*' cmd.run '/opt/scripts/monitor_salt.sh compare --json --api-url https://api.company.com/monitor'
```

### Run Test API Server

#### Method 1: Run with Docker (Recommended)

```bash
# Use quick start script
./start_api_server.sh

# Or run docker-compose directly
docker compose up -d --build

# Check logs
docker compose logs -f

# Stop
docker compose down
```

#### Method 2: Run Python Directly

```bash
# Start API server
python3 test_api_server.py 8080

# Test from another terminal
./monitor_salt.sh compare --json --api-url http://localhost:8080/
```

#### Deploy to Remote Server

```bash
# 1. Copy files
scp -r process_monitor/ user@remote-server:/opt/

# 2. Run on remote server
ssh user@remote-server
cd /opt/process_monitor
./start_api_server.sh

# 3. Test
./monitor_salt.sh compare --json --api-url http://remote-server:8080/
```

### API Request Format

**Endpoint**: `POST {API_URL}`

**Headers**:
```
Content-Type: application/json
```

**Body**:
```json
{
  "hostname": "server01",
  "timestamp": "2026-02-09 15:30:00",
  "status": "failure",
  "has_issues": true,
  "snapshot_time": "2026-02-09 14:00:00",
  "services": {
    "stopped": ["nginx.service"],
    "new": []
  },
  "processes": {
    "stopped": ["nginx"]
  },
  "ports": {
    "missing": [":80"]
  }
}
```

### API Server Implementation Example

```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/monitor', methods=['POST'])
def receive_monitor_result():
    data = request.json
    
    # Save to database
    # save_to_database(data)
    
    # Send Slack/Discord notification
    if data.get('has_issues'):
        send_alert(f"⚠️ {data['hostname']} has issues!")
    
    return jsonify({"status": "success"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

## 🚨 Troubleshooting

### Error: Snapshot not found
```bash
# Check snapshot status
./monitor_salt.sh status

# Recreate snapshot
./monitor_salt.sh snapshot
```

### Permission error
```bash
chmod +x monitor_salt.sh
```

---
**Note**: Kernel processes (kworker, kswapd, etc.) are automatically excluded from comparison.
