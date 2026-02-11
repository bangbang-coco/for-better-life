# Compare after reboot and send results to API
#
# Usage:
#   salt '*' state.apply monitor.compare

include:
  - monitor

# Compare and send to API
compare_and_send_to_api:
  cmd.run:
    - name: /opt/scripts/monitor_salt.sh compare --json --api-url "http://{{ grains['master'] }}:8080/"
    - require:
      - file: monitor_salt_script
    - onlyif: test -f /var/tmp/process_snapshot/services_running.txt
    # Only execute when snapshot exists
