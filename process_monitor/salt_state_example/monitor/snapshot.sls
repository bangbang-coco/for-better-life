# 재부팅 전 스냅샷 생성 State
#
# 사용법:
#   salt '*' state.apply monitor.snapshot

include:
  - monitor

# 스냅샷 생성 실행
create_monitor_snapshot:
  cmd.run:
    - name: /opt/scripts/monitor_salt.sh snapshot
    - require:
      - file: monitor_salt_script
    - unless: test -f /var/tmp/process_snapshot/metadata.txt && test $(( $(date +%s) - $(stat -c %Y /var/tmp/process_snapshot/metadata.txt) )) -lt 3600
    # 1시간 이내에 생성된 스냅샷이 있으면 스킵
