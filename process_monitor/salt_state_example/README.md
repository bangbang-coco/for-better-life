# Salt State File Usage Guide

## 📁 File Placement

Place in `/srv/salt/` on Salt master:

```
/srv/salt/
└── monitor/
    ├── init.sls        # Config and deployment
    ├── snapshot.sls    # Create snapshot
    ├── compare.sls     # Compare and send to API
    └── files/
        └── monitor_salt.sh
```

## 🚀 Quick Start

```bash
# Deploy scripts
salt '*' state.apply monitor

# Create snapshot
salt '*' state.apply monitor.snapshot

# Reboot
salt --batch-size 10 '*' system.reboot

# Compare after reboot
salt '*' state.apply monitor.compare
```

## 💡 Complete Workflow

```bash
# 1. Start API server on Salt master
cd /opt/process_monitor
./start_api_server.sh

# 2. Deploy scripts to minions
salt '*' state.apply monitor

# 3. Create snapshot before reboot
salt '*' state.apply monitor.snapshot

# 4. Reboot servers (batch 10)
salt --batch-size 10 '*' system.reboot

# 5. Wait and compare
sleep 300
salt '*' state.apply monitor.compare

# 6. Check results
docker compose logs -f
ls -lh /opt/process_monitor/logs/
```

## 🔧 Customization

### Use explicit IP
```yaml
# In init.sls
export MONITOR_API_URL="http://10.0.1.100:8080/"
```

### Change snapshot validity (7200s = 2 hours)
```yaml
# In snapshot.sls
unless: test $(( $(date +%s) - $(stat -c %Y /var/tmp/process_snapshot/metadata.txt) )) -lt 7200
```

## 🎯 Reactor Automation

**`/etc/salt/master.d/reactor.conf`**:
```yaml
reactor:
  - 'salt/minion/*/start':
    - /srv/reactor/monitor_check.sls
```

**`/srv/reactor/monitor_check.sls`**:
```yaml
monitor_auto_check:
  local.state.apply:
    - tgt: {{ data['id'] }}
    - arg:
      - monitor.compare
```

## 🔍 Troubleshooting

```bash
# Check script
salt '*' cmd.run 'ls -l /opt/scripts/monitor_salt.sh'

# Test API
salt '*' cmd.run 'curl -s http://salt-master:8080/health'

# Check master
salt '*' grains.get master
```
