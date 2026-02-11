# Salt Master에서 API 서버 운영 가이드

## 🏗️ 아키텍처 개요

```
┌─────────────────────────────────────────────────────────────┐
│                    Salt Master 서버                          │
│                                                              │
│  ┌──────────────────────────────────────────┐               │
│  │  Monitor API Server (Docker)             │               │
│  │  http://salt-master:8080                 │               │
│  │  - 결과 수집                              │               │
│  │  - 실시간 모니터링                         │               │
│  │  - 웹 대시보드                            │               │
│  └──────────────────────────────────────────┘               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                         ▲  ▲  ▲
                         │  │  │ HTTP POST (JSON)
                         │  │  │
         ┌───────────────┘  │  └───────────────┐
         │                  │                  │
    ┌────┴─────┐      ┌────┴─────┐      ┌────┴─────┐
    │ Minion 1 │      │ Minion 2 │      │ Minion N │
    │          │      │          │      │          │
    │ monitor_ │      │ monitor_ │      │ monitor_ │
    │ salt.sh  │      │ salt.sh  │      │ salt.sh  │
    └──────────┘      └──────────┘      └──────────┘
```

## 📋 구현 체크리스트

### ✅ 현재 구현 완료 사항

1. **monitor_salt.sh**
   - [x] JSON 출력 지원
   - [x] `--api-url` 옵션으로 API 전송
   - [x] Salt 명령으로 실행 가능
   - [x] 에러 처리 및 재시도 로직

2. **test_api_server.py**
   - [x] HTTP POST 엔드포인트
   - [x] JSON 파싱 및 처리
   - [x] 콘솔에 예쁜 출력
   - [x] 헬스체크 엔드포인트

3. **Docker 컨테이너화**
   - [x] Dockerfile 작성
   - [x] docker-compose.yml 설정
   - [x] 빠른 시작 스크립트
   - [x] 헬스체크 설정

### ⚠️ Salt Master 환경 고려사항

#### 1. 네트워크 설정
```bash
# Salt master의 IP 주소 확인
hostname -I

# 또는 특정 인터페이스
ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1
```

**문제점**: Minion이 Salt master의 API에 접근할 수 있어야 함
**해결책**: 
- Docker를 호스트 네트워크 모드로 실행
- 또는 방화벽에서 8080 포트 오픈

#### 2. Docker 포트 바인딩
현재 docker-compose.yml:
```yaml
ports:
  - "8080:8080"  # 모든 인터페이스에 바인딩
```

**권장 설정**:
```yaml
ports:
  - "0.0.0.0:8080:8080"  # 명시적으로 모든 인터페이스
```

#### 3. Salt Master의 호스트명/IP 사용
Minion이 알아야 할 정보:
- Salt master의 IP: `10.0.1.100` (예시)
- API 엔드포인트: `http://10.0.1.100:8080/`

## 🚀 Salt Master 설정 가이드

### Step 1: Salt Master에서 API 서버 실행

```bash
# Salt master 서버에 로그인
ssh salt-master

# process_monitor 디렉토리로 이동
cd /opt/process_monitor

# API 서버 시작
./start_api_server.sh

# 또는 백그라운드 실행
docker compose up -d --build
```

### Step 2: 방화벽 설정 (필요시)

```bash
# firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload

# ufw (Ubuntu/Debian)
sudo ufw allow 8080/tcp
sudo ufw reload

# iptables
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
sudo iptables-save
```

### Step 3: Salt State 파일로 스크립트 배포

**파일: `/srv/salt/monitor/init.sls`**
```yaml
# 스크립트 배포
/opt/scripts/monitor_salt.sh:
  file.managed:
    - source: salt://monitor/monitor_salt.sh
    - mode: 755
    - makedirs: True

# Salt master 정보를 환경변수로 제공
/etc/profile.d/salt_master.sh:
  file.managed:
    - contents: |
        export SALT_MASTER_IP="{{ salt['network.interface_ip']('eth0') }}"
        export MONITOR_API_URL="http://{{ grains['master'] }}:8080/"
    - mode: 644
```

### Step 4: 전체 워크플로우

#### 재부팅 전
```bash
# 1. 스크립트 배포 (최초 1회)
salt '*' state.apply monitor

# 2. 스냅샷 생성
salt '*' cmd.run '/opt/scripts/monitor_salt.sh snapshot'
```

#### 재부팅
```bash
# 배치로 재부팅 (10대씩)
salt --batch-size 10 '*' system.reboot
```

#### 재부팅 후 (5-10분 대기)
```bash
# Salt master의 IP 가져오기
SALT_MASTER_IP=$(hostname -I | awk '{print $1}')

# 옵션 1: API로 자동 전송
salt '*' cmd.run "/opt/scripts/monitor_salt.sh compare --json --api-url http://${SALT_MASTER_IP}:8080/"

# 옵션 2: Salt로 수집 후 파일 저장
salt '*' cmd.run '/opt/scripts/monitor_salt.sh compare --json' --out=json > /var/log/monitor_results_$(date +%Y%m%d_%H%M%S).json
```

#### 결과 확인
```bash
# API 서버 로그 확인 (실시간)
docker compose logs -f

# 또는 파일로 저장된 결과 분석
jq 'to_entries[] | select(.value.has_issues == true)' /var/log/monitor_results_*.json
```

## 🔧 고급 설정

### 1. Salt Master 호스트명 자동 감지

**파일: `/srv/salt/monitor/config.sls`**
```yaml
monitor_config:
  file.managed:
    - name: /etc/monitor_config
    - contents: |
        MONITOR_API_URL=http://{{ grains['master'] }}:8080/
```

그리고 스크립트에서:
```bash
# /etc/monitor_config 읽기
if [ -f /etc/monitor_config ]; then
    source /etc/monitor_config
fi

# API URL이 설정되어 있으면 자동 전송
./monitor_salt.sh compare --json ${MONITOR_API_URL:+--api-url $MONITOR_API_URL}
```

### 2. Salt Reactor를 이용한 자동 처리

**파일: `/etc/salt/master.d/reactor.conf`**
```yaml
reactor:
  - 'salt/minion/*/start':
    - /srv/reactor/minion_start.sls
```

**파일: `/srv/reactor/minion_start.sls`**
```yaml
check_services:
  local.cmd.run:
    - tgt: {{ data['id'] }}
    - arg:
      - /opt/scripts/monitor_salt.sh compare --json --api-url http://salt-master:8080/
```

### 3. 결과를 파일로도 저장

API 서버 수정하여 결과를 파일로 저장:
```python
# test_api_server.py에 추가
import json
from datetime import datetime

def save_result_to_file(data):
    """결과를 파일로 저장"""
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f"/var/log/monitor/{data['hostname']}_{timestamp}.json"
    
    os.makedirs('/var/log/monitor', exist_ok=True)
    with open(filename, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
```

docker-compose.yml에 볼륨 추가:
```yaml
volumes:
  - ./logs:/var/log/monitor
```

## 📊 모니터링 대시보드 (향후 개선)

현재는 콘솔 출력이지만, 향후 개선 가능:
1. **Grafana + InfluxDB**: 시계열 데이터 저장 및 시각화
2. **Elasticsearch + Kibana**: 로그 검색 및 분석
3. **Slack/Discord 알림**: 문제 발생 시 즉시 알림

## ✅ 검증 테스트

### 1. API 서버 접근 테스트
```bash
# Salt master에서
curl http://localhost:8080/health

# Minion에서
curl http://<salt-master-ip>:8080/health
```

### 2. 전체 플로우 테스트
```bash
# 테스트용 minion 1대로 테스트
salt 'test-minion' cmd.run '/opt/scripts/monitor_salt.sh snapshot'
salt 'test-minion' cmd.run '/opt/scripts/monitor_salt.sh compare --json --api-url http://salt-master:8080/'

# API 서버 로그 확인
docker compose logs -f
```

## 🎯 최종 권장 구성

### Salt Master 서버
```bash
# /opt/process_monitor/
├── docker-compose.yml
├── Dockerfile
├── test_api_server.py
└── logs/  # 결과 저장 디렉토리
```

### Salt Minion 서버
```bash
# /opt/scripts/
└── monitor_salt.sh
```

### Salt State 트리
```bash
# /srv/salt/
└── monitor/
    ├── init.sls
    ├── monitor_salt.sh
    └── config.sls
```

## 💡 결론

**현재 구현은 Salt Master에서 사용 가능합니다!** 

필요한 것:
1. ✅ API 서버를 Salt master에서 Docker로 실행
2. ✅ Minion에 스크립트 배포
3. ✅ `--api-url`에 Salt master IP 지정
4. ✅ 네트워크/방화벽 설정

추가 개선 사항:
- Salt grain에서 master IP 자동 감지
- 볼륨 마운트로 결과 파일 영구 저장
- Slack/Discord 알림 연동
- 웹 대시보드 추가
