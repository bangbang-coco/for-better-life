# 재부팅 후 비교 및 결과를 API로 전송
#
# 사용법:
#   salt '*' state.apply monitor.compare

include:
  - monitor

# 결과 비교 및 API 전송
compare_and_send_to_api:
  cmd.run:
    - name: /opt/scripts/monitor_salt.sh compare --json --api-url "http://{{ grains['master'] }}:8080/"
    - require:
      - file: monitor_salt_script
    - onlyif: test -f /var/tmp/process_snapshot/services_running.txt
    # 스냅샷이 있을 때만 실행
