# Process Monitor 스크립트 배포 및 설정
#
# 사용법:
#   salt '*' state.apply monitor

# 스크립트 디렉토리 생성
monitor_script_dir:
  file.directory:
    - name: /opt/scripts
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

# monitor_salt.sh 배포
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

# Salt Master 정보를 환경변수로 설정
monitor_config:
  file.managed:
    - name: /etc/profile.d/monitor_config.sh
    - user: root
    - group: root
    - mode: 644
    - contents: |
        # Process Monitor 설정
        export MONITOR_API_URL="http://{{ grains['master'] }}:8080/"
        export SALT_MASTER_HOST="{{ grains['master'] }}"

# 스냅샷 디렉토리 생성 (선택사항)
monitor_snapshot_dir:
  file.directory:
    - name: /var/tmp/process_snapshot
    - user: root
    - group: root
    - mode: 755
    - makedirs: True
