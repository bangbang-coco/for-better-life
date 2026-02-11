# Salt Master Setup Guide

## 🏗️ Architecture Overview

```
Salt Master Server (API Server: Port 8080)
    ↑  ↑  ↑
    │  │  │  HTTP POST (JSON)
    │  │  │
    ├──┼──┴─── Minion 1, 2, 3... N
    │  │        (monitor_salt.sh)
    │  │
```

## ✅ Implementation Checklist

### Completed Features

1. **monitor_salt.sh**
   - JSON output support  
   - `--api-url` option for API transmission
   - Salt command compatible
   - Error handling

2. **test_api_server.py**
   - HTTP POST endpoint
   - JSON parsing
   - Console output
   - Health check endpoint
   - File save feature

3. **Docker Container**
   - Dockerfile
   - docker-compose.yml  
   - Quick start script
   - Health check

### Salt Master Considerations

#### 1. Network Configuration
```bash
# Get Salt master IP
hostname -I
```

**Solution**: Open port 8080 in firewall or use host network mode

#### 2. Docker Port Binding
```yaml
ports:
  - "0.0.0.0:8080:8080"  # All interfaces
```

#### 3. Firewall Setup
```bash
# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload

# Ubuntu/Debian
sudo ufw allow 8080/tcp
```

## 🚀 Quick Setup Guide

### Step 1: Run API Server on Salt Master

```bash
cd /opt/process_monitor
./start_api_server.sh
```

### Step 2: Deploy Scripts to Minions

```bash
# Using Salt State
salt '*' state.apply monitor

# Or manually
salt '*' cp.get_file salt://scripts/monitor_salt.sh /opt/scripts/monitor_salt.sh
salt '*' cmd.run 'chmod +x /opt/scripts/monitor_salt.sh'
```

### Step 3: Complete Workflow

```bash
# Before reboot
salt '*' cmd.run '/opt/scripts/monitor_salt.sh snapshot'

# Reboot (batch)
salt --batch-size 10 '*' system.reboot

# After reboot (wait 5 min)
sleep 300
MASTER_IP=$(hostname -I | awk '{print $1}')
salt '*' cmd.run "/opt/scripts/monitor_salt.sh compare --json --api-url http://${MASTER_IP}:8080/"

# Check results
docker compose logs -f
```

## 📊 Result Storage

Results are saved in:
- **Real-time console**: `docker compose logs -f`
- **JSON files**: `./logs/hostname_timestamp.json`
- **Web interface**: `http://salt-master:8080/`

## 🔧 Advanced Configuration

### Auto-detect Salt Master

**`/srv/salt/monitor/config.sls`**:
```yaml
monitor_config:
  file.managed:
    - name: /etc/monitor_config
    - contents: |
        MONITOR_API_URL=http://{{ grains['master'] }}:8080/
```

### Salt Reactor Integration

**`/etc/salt/master.d/reactor.conf`**:
```yaml
reactor:
  - 'salt/minion/*/start':
    - /srv/reactor/minion_start.sls
```

**`/srv/reactor/minion_start.sls`**:
```yaml
check_services:
  local.cmd.run:
    - tgt: {{ data['id'] }}
    - arg:
      - /opt/scripts/monitor_salt.sh compare --json --api-url http://salt-master:8080/
```

## ✅ Validation Tests

### 1. API Server Access
```bash
# From Salt master
curl http://localhost:8080/health

# From Minion
curl http://<salt-master-ip>:8080/health
```

### 2. Full Flow Test
```bash
# Test with one minion
salt 'test-minion' cmd.run '/opt/scripts/monitor_salt.sh snapshot'
salt 'test-minion' cmd.run '/opt/scripts/monitor_salt.sh compare --json --api-url http://salt-master:8080/'

# Check API logs
docker compose logs -f
```

## 💡 Production Recommendations

### Salt Master Server Structure
```
/opt/process_monitor/
├── docker-compose.yml
├── Dockerfile
├── test_api_server.py
└── logs/              # Results directory
```

### Salt Minion Structure
```
/opt/scripts/
└── monitor_salt.sh
```

### Salt State Tree
```
/srv/salt/
└── monitor/
    ├── init.sls
    ├── monitor_salt.sh
    └── config.sls
```

## 🎯 Summary

**Current implementation works perfectly with Salt Master!**

Key requirements:
1. ✅ Run API server on Salt master with Docker
2. ✅ Deploy scripts to minions
3. ✅ Use `--api-url` with Salt master IP
4. ✅ Configure network/firewall

Future improvements:
- Web dashboard
- Slack/Discord notifications  
- Database integration
- Grafana visualization
