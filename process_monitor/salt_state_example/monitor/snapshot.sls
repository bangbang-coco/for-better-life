# Create snapshot before reboot State
#
# Usage:
#   salt '*' state.apply monitor.snapshot

include:
  - monitor

# Execute snapshot creation
create_monitor_snapshot:
  cmd.run:
    - name: /opt/scripts/monitor_salt.sh snapshot
    - require:
      - file: monitor_salt_script
    - unless: test -f /var/tmp/process_snapshot/metadata.txt && test $(( $(date +%s) - $(stat -c %Y /var/tmp/process_snapshot/metadata.txt) )) -lt 3600
    # Skip if snapshot was created within 1 hour
