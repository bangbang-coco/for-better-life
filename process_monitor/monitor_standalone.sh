#!/bin/bash
#
# 서버 재부팅 전후 프로세스 모니터링 스크립트
# 사용법:
#   재부팅 전: ./process_monitor.sh snapshot
#   재부팅 후: ./process_monitor.sh compare
#

set -euo pipefail

# 설정
SNAPSHOT_DIR="/var/tmp/process_snapshot"
HOSTNAME=$(hostname)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 비교에서 제외할 커널 프로세스 패턴
EXCLUDE_PROCS="kworker|kswapd|ksoftirqd|migration|rcu_|watchdog|cpuhp|idle_inject|irq/|scsi_|md_|edac-|devfreq_"

# 구분선 (가로 80자)
LINE="════════════════════════════════════════════════════════════════════════════════"
THIN_LINE="────────────────────────────────────────────────────────────────────────────────"

# 스냅샷 디렉토리 생성
mkdir -p "$SNAPSHOT_DIR"

# 도움말 출력
show_help() {
    echo "사용법: $0 {snapshot|compare|status}"
    echo ""
    echo "명령어:"
    echo "  snapshot  - 현재 프로세스 상태를 스냅샷으로 저장 (재부팅 전 실행)"
    echo "  compare   - 스냅샷과 현재 상태 비교 (재부팅 후 실행)"
    echo "  status    - 현재 스냅샷 정보 확인"
    echo ""
    echo "스냅샷 저장 위치: $SNAPSHOT_DIR"
}

# systemd 서비스 목록 수집
get_systemd_services() {
    systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | \
        awk '{print $1}' | sort
}

# 활성화된(enabled) 서비스 목록 수집
get_enabled_services() {
    systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend 2>/dev/null | \
        awk '{print $1}' | sort
}

# 실행 중인 프로세스 목록 수집 (중요 프로세스만)
get_running_processes() {
    # 커널 스레드 및 커널 워커 프로세스 제외
    ps -eo comm,user --no-headers 2>/dev/null | \
        grep -v '^\[' | \
        awk '{print $1}' | \
        grep -Ev "^($EXCLUDE_PROCS)" | \
        sort -u
}

# 상세 프로세스 정보 수집
get_process_details() {
    ps -eo pid,ppid,user,comm,args --no-headers 2>/dev/null | \
        grep -v '^\s*[0-9]*\s*[0-9]*\s*\S*\s*\[' | \
        sort -k4
}

# 리스닝 포트 수집
get_listening_ports() {
    if command -v ss &> /dev/null; then
        ss -tulnp 2>/dev/null | tail -n +2 | sort
    elif command -v netstat &> /dev/null; then
        netstat -tulnp 2>/dev/null | tail -n +2 | sort
    else
        echo "포트 확인 도구 없음"
    fi
}

# 스냅샷 저장
do_snapshot() {
    echo -e "${BLUE}[INFO]${NC} 프로세스 스냅샷 생성 중... (호스트: $HOSTNAME)"

    # 기존 스냅샷 백업
    if [[ -f "$SNAPSHOT_DIR/services_running.txt" ]]; then
        echo -e "${YELLOW}[WARN]${NC} 기존 스냅샷이 있습니다. 백업 중..."
        backup_dir="$SNAPSHOT_DIR/backup_$TIMESTAMP"
        mkdir -p "$backup_dir"
        mv "$SNAPSHOT_DIR"/*.txt "$backup_dir/" 2>/dev/null || true
    fi

    # 1. 실행 중인 systemd 서비스
    echo -e "${BLUE}[INFO]${NC} 실행 중인 systemd 서비스 수집..."
    get_systemd_services > "$SNAPSHOT_DIR/services_running.txt"
    running_count=$(wc -l < "$SNAPSHOT_DIR/services_running.txt")
    echo -e "       └─ $running_count 개 서비스 저장됨"

    # 2. 활성화된 서비스 (부팅 시 자동 시작)
    echo -e "${BLUE}[INFO]${NC} 활성화된(enabled) 서비스 수집..."
    get_enabled_services > "$SNAPSHOT_DIR/services_enabled.txt"
    enabled_count=$(wc -l < "$SNAPSHOT_DIR/services_enabled.txt")
    echo -e "       └─ $enabled_count 개 서비스 저장됨"

    # 3. 실행 중인 프로세스 (이름만)
    echo -e "${BLUE}[INFO]${NC} 실행 중인 프로세스 목록 수집..."
    get_running_processes > "$SNAPSHOT_DIR/processes.txt"
    proc_count=$(wc -l < "$SNAPSHOT_DIR/processes.txt")
    echo -e "       └─ $proc_count 개 프로세스 저장됨"

    # 4. 상세 프로세스 정보
    echo -e "${BLUE}[INFO]${NC} 상세 프로세스 정보 수집..."
    get_process_details > "$SNAPSHOT_DIR/processes_detail.txt"

    # 5. 리스닝 포트
    echo -e "${BLUE}[INFO]${NC} 리스닝 포트 수집..."
    get_listening_ports > "$SNAPSHOT_DIR/ports.txt"
    port_count=$(grep -c "LISTEN\|tcp\|udp" "$SNAPSHOT_DIR/ports.txt" 2>/dev/null || echo "0")
    echo -e "       └─ $port_count 개 포트 저장됨"

    # 메타데이터 저장
    cat > "$SNAPSHOT_DIR/metadata.txt" << EOF
호스트명: $HOSTNAME
스냅샷 시간: $(date '+%Y-%m-%d %H:%M:%S')
커널 버전: $(uname -r)
업타임: $(uptime -p 2>/dev/null || uptime)
EOF

    echo ""
    echo -e "${GREEN}[SUCCESS]${NC} 스냅샷 저장 완료!"
    echo -e "          저장 위치: $SNAPSHOT_DIR"
    echo ""
    echo -e "${YELLOW}[NOTE]${NC} 재부팅 후 다음 명령어로 비교하세요:"
    echo -e "       $0 compare"
}

# 스냅샷과 현재 상태 비교
do_compare() {
    if [[ ! -f "$SNAPSHOT_DIR/services_running.txt" ]]; then
        echo -e "${RED}[ERROR]${NC} 스냅샷이 없습니다. 먼저 'snapshot' 명령을 실행하세요."
        exit 1
    fi

    echo -e "${BLUE}${LINE}${NC}"
    echo -e "${BLUE}  서버 재부팅 후 프로세스 비교 리포트${NC}"
    echo -e "${BLUE}  호스트: $HOSTNAME${NC}"
    echo -e "${BLUE}  비교 시간: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${BLUE}${LINE}${NC}"
    echo ""

    # 스냅샷 메타데이터 출력
    if [[ -f "$SNAPSHOT_DIR/metadata.txt" ]]; then
        echo -e "${YELLOW}[스냅샷 정보]${NC}"
        cat "$SNAPSHOT_DIR/metadata.txt"
        echo ""
    fi

    local has_issue=0

    # 1. systemd 서비스 비교
    echo -e "${YELLOW}[1] Systemd 서비스 비교${NC}"
    echo -e "${THIN_LINE}"

    current_services=$(mktemp)
    get_systemd_services > "$current_services"

    # 중지된 서비스 찾기
    stopped_services=$(comm -23 "$SNAPSHOT_DIR/services_running.txt" "$current_services")
    if [[ -n "$stopped_services" ]]; then
        echo -e "${RED}[!] 실행되지 않는 서비스:${NC}"
        while IFS= read -r svc; do
#            status=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
            status=$(systemctl is-active "$svc" 2>/dev/null || true)
            [[ -z "$status" ]] && status="unknown"
            echo -e "    ${RED}✗${NC} $svc (상태: $status)"
        done <<< "$stopped_services"
        has_issue=1
    else
        echo -e "${GREEN}[✓] 모든 서비스가 정상 실행 중${NC}"
    fi

    # 새로 시작된 서비스
    new_services=$(comm -13 "$SNAPSHOT_DIR/services_running.txt" "$current_services")
    if [[ -n "$new_services" ]]; then
        echo -e "${BLUE}[i] 새로 시작된 서비스:${NC}"
        while IFS= read -r svc; do
            echo -e "    ${BLUE}+${NC} $svc"
        done <<< "$new_services"
    fi

    rm -f "$current_services"
    echo ""

    # 2. 프로세스 비교
    echo -e "${YELLOW}[2] 프로세스 비교${NC}"
    echo -e "${THIN_LINE}"

    current_procs=$(mktemp)
    get_running_processes > "$current_procs"

    # 중지된 프로세스 찾기 (커널 프로세스 제외)
    stopped_procs=$(comm -23 "$SNAPSHOT_DIR/processes.txt" "$current_procs" | grep -Ev "^($EXCLUDE_PROCS)" || true)
    if [[ -n "$stopped_procs" ]]; then
        echo -e "${RED}[!] 실행되지 않는 프로세스:${NC}"
        while IFS= read -r proc; do
            echo -e "    ${RED}✗${NC} $proc"
        done <<< "$stopped_procs"
        has_issue=1
    else
        echo -e "${GREEN}[✓] 주요 프로세스 모두 실행 중${NC}"
    fi

    rm -f "$current_procs"
    echo ""

    # 3. 포트 비교
    echo -e "${YELLOW}[3] 리스닝 포트 비교${NC}"
    echo -e "${THIN_LINE}"

    if [[ -f "$SNAPSHOT_DIR/ports.txt" ]]; then
        current_ports=$(mktemp)
        get_listening_ports > "$current_ports"

        # 간단한 포트 비교 (포트 번호만 추출)
        old_ports=$(grep -oE ':[0-9]+' "$SNAPSHOT_DIR/ports.txt" 2>/dev/null | sort -u || true)
        new_ports=$(grep -oE ':[0-9]+' "$current_ports" 2>/dev/null | sort -u || true)

        missing_ports=$(comm -23 <(echo "$old_ports") <(echo "$new_ports") 2>/dev/null || true)
        if [[ -n "$missing_ports" ]]; then
            echo -e "${RED}[!] 리스닝하지 않는 포트:${NC}"
            echo "$missing_ports" | while read -r port; do
                echo -e "    ${RED}✗${NC} $port"
            done
            has_issue=1
        else
            echo -e "${GREEN}[✓] 모든 포트 정상 리스닝 중${NC}"
        fi

        rm -f "$current_ports"
    fi
    echo ""

    # 결과 요약
    echo -e "${YELLOW}${LINE}${NC}"
    if [[ $has_issue -eq 1 ]]; then
        echo -e "${RED}[결과] 일부 서비스/프로세스가 실행되지 않고 있습니다!${NC}"
        echo -e "${YELLOW}       위 목록을 확인하고 필요시 수동으로 시작하세요.${NC}"
        exit 1
    else
        echo -e "${GREEN}[결과] 모든 서비스와 프로세스가 정상입니다!${NC}"
        exit 0
    fi
}

# 스냅샷 상태 확인
do_status() {
    echo -e "${BLUE}[스냅샷 상태]${NC}"
    echo -e "${THIN_LINE}"

    if [[ -d "$SNAPSHOT_DIR" && -f "$SNAPSHOT_DIR/metadata.txt" ]]; then
        echo -e "${GREEN}스냅샷 존재함${NC}"
        echo ""
        cat "$SNAPSHOT_DIR/metadata.txt"
        echo ""
        echo "저장된 파일:"
        ls -la "$SNAPSHOT_DIR"/*.txt 2>/dev/null || echo "  (없음)"
    else
        echo -e "${YELLOW}스냅샷 없음${NC}"
        echo "먼저 '$0 snapshot' 명령을 실행하세요."
    fi
}

# 메인 로직
case "${1:-}" in
    snapshot)
        do_snapshot
        ;;
    compare)
        do_compare
        ;;
    status)
        do_status
        ;;
    -h|--help|help)
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac
