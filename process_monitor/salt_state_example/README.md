# Salt State 파일 사용 가이드

## 📁 파일 배치

Salt master 서버의 `/srv/salt/` 디렉토리에 다음과 같이 배치:

```
/srv/salt/
└── monitor/
    ├── init.sls           # 기본 설정 및 스크립트 배포
    ├── snapshot.sls       # 스냅샷 생성
    ├── compare.sls        # 비교 및 API 전송
    └── files/
        └── monitor_salt.sh # 실제 스크립트 파일
```

## 🚀 사용 방법

### 1. 초기 설정 및 스크립트 배포

```bash
# 모든 minion에 스크립트 배포
salt '*' state.apply monitor

# 특정 그룹만
salt -G 'role:web' state.apply monitor

# 테스트 모드 (변경사항 미리보기)
salt '*' state.apply monitor test=True
```

### 2. 재부팅 전 스냅샷 생성

```bash
# 모든 서버에서 스냅샷 생성
salt '*' state.apply monitor.snapshot

# 배치 실행 (10대씩)
salt --batch-size 10 '*' state.apply monitor.snapshot

# 비동기 실행
salt '*' state.apply monitor.snapshot --async
```

### 3. 재부팅 실행

```bash
# 한 번에 10대씩 재부팅
salt --batch-size 10 '*' system.reboot

# 특정 시간 후 재부팅
salt '*' system.reboot at='23:00'
```

### 4. 재부팅 후 비교 (5-10분 대기)

```bash
# 결과 비교 및 API로 자동 전송
salt '*' state.apply monitor.compare

# 또는 직접 명령 실행
salt '*' cmd.run '/opt/scripts/monitor_salt.sh compare --json --api-url http://salt-master:8080/'
```

## 🔧 커스터마이징

### Salt Master IP/호스트명 변경

`init.sls` 파일에서:
```yaml
# grains['master'] 대신 명시적 IP 사용
export MONITOR_API_URL="http://10.0.1.100:8080/"
```

### 포트 변경

API 서버를 다른 포트로 실행했다면:
```yaml
export MONITOR_API_URL="http://{{ grains['master'] }}:9090/"
```

### 스냅샷 유효 시간 조정

`snapshot.sls`에서:
```yaml
# 3600초(1시간) → 7200초(2시간)으로 변경
unless: test -f /var/tmp/process_snapshot/metadata.txt && test $(( $(date +%s) - $(stat -c %Y /var/tmp/process_snapshot/metadata.txt) )) -lt 7200
```

## 📊 전체 워크플로우 예시

```bash
# ===== 1단계: 초기 설정 =====
# Salt master에서 API 서버 시작
cd /opt/process_monitor
./start_api_server.sh

# 스크립트 배포
salt '*' state.apply monitor

# ===== 2단계: 재부팅 전 =====
# 스냅샷 생성
salt '*' state.apply monitor.snapshot

# 또는
salt '*' cmd.run '/opt/scripts/monitor_salt.sh snapshot'

# ===== 3단계: 재부팅 =====
# 배치로 재부팅 (한 번에 10대씩)
salt --batch-size 10 '*' system.reboot

# ===== 4단계: 재부팅 후 =====
# 5-10분 대기 후
sleep 300

# 결과 비교 및 API 전송
salt '*' state.apply monitor.compare

# 또는 직접 실행
MASTER_IP=$(hostname -I | awk '{print $1}')
salt '*' cmd.run "/opt/scripts/monitor_salt.sh compare --json --api-url http://${MASTER_IP}:8080/"

# ===== 5단계: 결과 확인 =====
# API 서버 로그 실시간 확인
docker compose logs -f

# 저장된 파일 확인
ls -lh /opt/process_monitor/logs/

# JSON 파일 분석
jq '.' /opt/process_monitor/logs/*.json
```

## 🎯 Reactor를 이용한 자동화

### Reactor 설정

**파일: `/etc/salt/master.d/reactor.conf`**
```yaml
reactor:
  # Minion이 시작되면 자동으로 비교 실행
  - 'salt/minion/*/start':
    - /srv/reactor/monitor_check.sls
```

**파일: `/srv/reactor/monitor_check.sls`**
```yaml
# Minion 시작 5분 후 자동 체크
monitor_auto_check:
  local.state.apply:
    - tgt: {{ data['id'] }}
    - arg:
      - monitor.compare
    - kwarg:
        pillar:
          delay: 300  # 5분 대기
```

## 🔍 트러블슈팅

### 스크립트가 실행되지 않음
```bash
# 권한 확인
salt '*' cmd.run 'ls -l /opt/scripts/monitor_salt.sh'

# 수동 실행 테스트
salt 'test-minion' cmd.run '/opt/scripts/monitor_salt.sh --help'
```

### API 서버 접근 불가
```bash
# 네트워크 테스트
salt '*' cmd.run 'curl -s http://salt-master:8080/health'

# 방화벽 확인
salt 'salt-master' cmd.run 'firewall-cmd --list-ports'
```

### Salt Master 호스트명 확인
```bash
# Grains에서 master 정보 확인
salt '*' grains.get master

# 직접 IP 확인
salt '*' cmd.run 'getent hosts salt-master'
```
