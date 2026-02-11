# Process Monitor Script Deployment and Configuration
#
# Usage:
#   salt '*' state.apply monitor

# Create script directory
monitor_script_dir:
  file.directory:
    - name: /opt/scripts
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

# Deploy monitor_salt.sh
monitor_salt_script:
  file.managed:
    - name: /opt/scripts/monitor_salt.sh
    - source: salt://monitor/files/monitor_salt.sh
    - user: root
    - group: root
    - mode: 755
    - makedirs: True
    - require:
      - file: monitor_script_dir

# Set Salt Master information as environment variable
monitor_config:
  file.managed:
    - name: /etc/profile.d/monitor_config.sh
    - user: root
    - group: root
    - mode: 644
    - contents: |
        # Process Monitor Configuration
        export MONITOR_API_URL="http://{{ grains['master'] }}:8080/"
        export SALT_MASTER_HOST="{{ grains['master'] }}"

# Create snapshot directory (optional)
monitor_snapshot_dir:
  file.directory:
    - name: /var/tmp/process_snapshot
    - user: root
    - group: root
    - mode: 755
    - makedirs: True
