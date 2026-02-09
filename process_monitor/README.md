# Process Monitor

서버 재부팅 전후 프로세스 및 서비스 상태를 비교하는 모니터링 스크립트입니다.

## 📁 파일 구성

- **monitor_standalone.sh** - 단일 서버용 스크립트 (색상 출력, 사람이 읽기 좋음)
- **monitor_salt.sh** - Salt 환경용 스크립트 (JSON 출력 지원)

## 🚀 사용 방법

### 1️⃣ Standalone 모드 (단일 서버)

```bash
# 재부팅 전 - 스냅샷 생성
./monitor_standalone.sh snapshot

# 재부팅 후 - 비교
./monitor_standalone.sh compare

# 스냅샷 상태 확인
./monitor_standalone.sh status
```

### 2️⃣ Salt 환경 (대량 서버)

#### Step 1: 스냅샷 생성 (재부팅 전)
```bash
# 모든 서버에서 스냅샷 생성
salt '*' cmd.run '/opt/scripts/monitor_salt.sh snapshot'
```

#### Step 2: 비교 및 결과 수집 (재부팅 후)
```bash
# JSON 형식으로 결과 수집
salt '*' cmd.run '/opt/scripts/monitor_salt.sh compare --json' --out=json > /tmp/monitor_results.json

# 또는 YAML 형식으로
salt '*' cmd.run '/opt/scripts/monitor_salt.sh compare --json' --out=yaml > /tmp/monitor_results.yaml
```

#### Step 3: 결과 분석
```bash
# 실패한 서버만 필터링
jq 'to_entries[] | select(.value.retcode != 0) | {hostname: .key, result: .value}' /tmp/monitor_results.json

# 문제가 있는 서비스 목록
jq 'to_entries[] | select(.value.has_issues == true) | {hostname: .key, stopped_services: .value.services.stopped}' /tmp/monitor_results.json

# 요약 리포트
jq 'to_entries[] | {hostname: .key, status: .value.status, issues: .value.has_issues}' /tmp/monitor_results.json
```

## 📊 JSON 출력 형식

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

## 🎯 Salt State 파일 예시

### monitor.sls
```yaml
# 스크립트 배포
/opt/scripts/monitor_salt.sh:
  file.managed:
    - source: salt://scripts/monitor_salt.sh
    - mode: 755
    - makedirs: True

# 재부팅 전 스냅샷 생성
pre_reboot_snapshot:
  cmd.run:
    - name: /opt/scripts/monitor_salt.sh snapshot
    - require:
      - file: /opt/scripts/monitor_salt.sh
```

## 💡 실전 워크플로우

### 대량 서버 재부팅 시나리오

```bash
# 1. 스크립트 배포
salt '*' cp.get_file salt://scripts/monitor_salt.sh /opt/scripts/monitor_salt.sh
salt '*' cmd.run 'chmod +x /opt/scripts/monitor_salt.sh'

# 2. 재부팅 전 스냅샷 생성
salt '*' cmd.run '/opt/scripts/monitor_salt.sh snapshot'

# 3. 서버 재부팅
salt '*' system.reboot

# 4. 재부팅 후 비교 (5분 대기 후)
sleep 300
salt '*' cmd.run '/opt/scripts/monitor_salt.sh compare --json' --out=json > results_$(date +%Y%m%d_%H%M%S).json

# 5. 결과 분석
cat results_*.json | jq 'to_entries[] | select(.value.has_issues == true)'
```

## 🔧 고급 설정

### 특정 그룹만 실행
```bash
# web 그룹만
salt -G 'role:web' cmd.run '/opt/scripts/monitor_salt.sh compare --json'

# 특정 데이터센터
salt -G 'datacenter:seoul' cmd.run '/opt/scripts/monitor_salt.sh compare --json'
```

### 배치 실행 (네트워크 부하 분산)
```bash
# 10대씩 순차 실행
salt --batch-size 10 '*' cmd.run '/opt/scripts/monitor_salt.sh compare --json'

# 25% 비율로 실행
salt --batch-size 25% '*' cmd.run '/opt/scripts/monitor_salt.sh compare --json'
```

## 📝 스냅샷 저장 위치

- 기본 경로: `/var/tmp/process_snapshot/`
- 스냅샷 파일:
  - `services_running.txt` - 실행 중인 서비스
  - `services_enabled.txt` - 활성화된 서비스
  - `processes.txt` - 실행 중인 프로세스
  - `ports.txt` - 리스닝 포트
  - `metadata.txt` - 메타데이터

## 🚨 문제 해결

### 스냅샷이 없다는 에러
```bash
# 스냅샷 상태 확인
./monitor_salt.sh status

# 스냅샷 재생성
./monitor_salt.sh snapshot
```

### 권한 에러
```bash
chmod +x monitor_salt.sh
```

## 🌐 HTTP API 연동

### API로 결과 자동 전송

```bash
# 단일 서버에서 API로 전송
./monitor_salt.sh compare --json --api-url https://api.example.com/monitor

# Salt로 대량 실행 + API 전송
salt '*' cmd.run '/opt/scripts/monitor_salt.sh compare --json --api-url https://api.company.com/monitor'
```

### 테스트용 API 서버 실행

#### 방법 1: Docker로 실행 (권장)

```bash
# 빠른 시작 스크립트 사용
./start_api_server.sh

# 또는 docker-compose 직접 실행
docker compose up -d --build

# 로그 확인
docker compose logs -f

# 종료
docker compose down
```

#### 방법 2: Python 직접 실행

```bash
# API 서버 시작
python3 test_api_server.py 8080

# 다른 터미널에서 테스트
./monitor_salt.sh compare --json --api-url http://localhost:8080/
```

#### 원격 서버에 배포

```bash
# 1. 파일 복사
scp -r process_monitor/ user@remote-server:/opt/

# 2. 원격 서버에서 실행
ssh user@remote-server
cd /opt/process_monitor
./start_api_server.sh

# 3. 테스트
./monitor_salt.sh compare --json --api-url http://remote-server:8080/
```

### API 요청 형식

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

### API 서버 구현 예시

```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/monitor', methods=['POST'])
def receive_monitor_result():
    data = request.json
    
    # 데이터베이스에 저장
    # save_to_database(data)
    
    # Slack/Discord 알림
    if data.get('has_issues'):
        send_alert(f"⚠️ {data['hostname']} has issues!")
    
    return jsonify({"status": "success"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

---
**참고**: 커널 프로세스(kworker, kswapd 등)는 자동으로 비교에서 제외됩니다.
