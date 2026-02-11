#!/bin/bash
#
# Server Process Monitoring Script for Salt Environment
# JSON output support for easy result collection from Salt master
#
# Usage:
#   Before reboot: ./monitor_salt.sh snapshot
#   After reboot: ./monitor_salt.sh compare [--json] [--api-url URL]
#

set -euo pipefail

# Configuration
SNAPSHOT_DIR="/var/tmp/process_snapshot"
HOSTNAME=$(hostname)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# JSON output mode
JSON_MODE=false
API_URL=""

# Kernel process patterns to exclude from comparison
EXCLUDE_PROCS="kworker|kswapd|ksoftirqd|migration|rcu_|watchdog|cpuhp|idle_inject|irq/|scsi_|md_|edac-|devfreq_"

# Divider lines (80 characters)
LINE="════════════════════════════════════════════════════════════════════════════════"
THIN_LINE="────────────────────────────────────────────────────────────────────────────────"

# Create snapshot directory
mkdir -p "$SNAPSHOT_DIR"

# JSON escape function
json_escape() {
    echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | sed ':a;N;$!ba;s/\n/\\n/g'
}

# Show help
show_help() {
    echo "Usage: $0 {snapshot|compare|status} [--json] [--api-url URL]"
    echo ""
    echo "Commands:"
    echo "  snapshot  - Save current process state as snapshot (run before reboot)"
    echo "  compare   - Compare snapshot with current state (run after reboot)"
    echo "  status    - Check current snapshot information"
    echo ""
    echo "Options:"
    echo "  --json         - Output results in JSON format (for Salt environment)"
    echo "  --api-url URL  - Send results to HTTP API (use with JSON mode)"
    echo ""
    echo "Snapshot storage location: $SNAPSHOT_DIR"
    echo ""
    echo "Salt usage example:"
    echo "  salt '*' cmd.run '/path/to/monitor_salt.sh compare --json' --out=json > results.json"
    echo ""
    echo "API transmission example:"
    echo "  ./monitor_salt.sh compare --json --api-url https://api.example.com/monitor"
}

# Collect systemd service list
get_systemd_services() {
    systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | \
        awk '{print $1}' | sort
}

# Collect enabled service list
get_enabled_services() {
    systemctl list-unit-files --type=service --state=enabled --no-pager --no-legend 2>/dev/null | \
        awk '{print $1}' | sort
}

# Collect running process list (important processes only)
get_running_processes() {
    ps -eo comm,user --no-headers 2>/dev/null | \
        grep -v '^\[' | \
        awk '{print $1}' | \
        grep -Ev "^($EXCLUDE_PROCS)" | \
        sort -u
}

# Collect detailed process information
get_process_details() {
    ps -eo pid,ppid,user,comm,args --no-headers 2>/dev/null | \
        grep -v '^\s*[0-9]*\s*[0-9]*\s*\S*\s*\[' | \
        sort -k4
}

# Collect listening ports
get_listening_ports() {
    if command -v ss &> /dev/null; then
        ss -tulnp 2>/dev/null | tail -n +2 | sort
    elif command -v netstat &> /dev/null; then
        netstat -tulnp 2>/dev/null | tail -n +2 | sort
    else
        echo "Port check tool unavailable"
    fi
}

# Save snapshot
do_snapshot() {
    if [[ "$JSON_MODE" == "true" ]]; then
        echo "JSON mode is not supported for snapshot command" >&2
        exit 1
    fi

    echo -e "${BLUE}[INFO]${NC} Creating process snapshot... (Host: $HOSTNAME)"

    # Backup existing snapshot
    if [[ -f "$SNAPSHOT_DIR/services_running.txt" ]]; then
        echo -e "${YELLOW}[WARN]${NC} Existing snapshot found. Backing up..."
        backup_dir="$SNAPSHOT_DIR/backup_$TIMESTAMP"
        mkdir -p "$backup_dir"
        mv "$SNAPSHOT_DIR"/*.txt "$backup_dir/" 2>/dev/null || true
    fi

    # 1. Running systemd services
    echo -e "${BLUE}[INFO]${NC} Collecting running systemd services..."
    get_systemd_services > "$SNAPSHOT_DIR/services_running.txt"
    running_count=$(wc -l < "$SNAPSHOT_DIR/services_running.txt")
    echo -e "       └─ $running_count services saved"

    # 2. Enabled services
    echo -e "${BLUE}[INFO]${NC} Collecting enabled services..."
    get_enabled_services > "$SNAPSHOT_DIR/services_enabled.txt"
    enabled_count=$(wc -l < "$SNAPSHOT_DIR/services_enabled.txt")
    echo -e "       └─ $enabled_count services saved"

    # 3. Running processes (names only)
    echo -e "${BLUE}[INFO]${NC} Collecting running process list..."
    get_running_processes > "$SNAPSHOT_DIR/processes.txt"
    proc_count=$(wc -l < "$SNAPSHOT_DIR/processes.txt")
    echo -e "       └─ $proc_count processes saved"

    # 4. Detailed process information
    echo -e "${BLUE}[INFO]${NC} Collecting detailed process information..."
    get_process_details > "$SNAPSHOT_DIR/processes_detail.txt"

    # 5. Listening ports
    echo -e "${BLUE}[INFO]${NC} Collecting listening ports..."
    get_listening_ports > "$SNAPSHOT_DIR/ports.txt"
    port_count=$(grep -c "LISTEN\|tcp\|udp" "$SNAPSHOT_DIR/ports.txt" 2>/dev/null || echo "0")
    echo -e "       └─ $port_count ports saved"

    # Save metadata
    cat > "$SNAPSHOT_DIR/metadata.txt" << EOF
Hostname: $HOSTNAME
Snapshot Time: $(date '+%Y-%m-%d %H:%M:%S')
Kernel Version: $(uname -r)
Uptime: $(uptime -p 2>/dev/null || uptime)
EOF

    echo ""
    echo -e "${GREEN}[SUCCESS]${NC} Snapshot saved successfully!"
    echo -e "          Saved at: $SNAPSHOT_DIR"
    echo ""
    echo -e "${YELLOW}[NOTE]${NC} After reboot, compare with this command:"
    echo -e "       $0 compare"
}

# Send results to API
send_to_api() {
    local json_data="$1"
    local api_url="$2"
    
    if [[ -z "$api_url" ]]; then
        return 0
    fi
    
    local response
    local http_code
    
    # POST request with curl
    response=$(curl -s -w "\n%{http_code}" -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -d "$json_data" 2>&1)
    
    http_code=$(echo "$response" | tail -n1)
    
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        echo "[API] Result transmission successful: $api_url (HTTP $http_code)" >&2
        return 0
    else
        echo "[API] Result transmission failed: $api_url (HTTP $http_code)" >&2
        return 1
    fi
}

# JSON array creation function
array_to_json() {
    local items="$1"
    if [[ -z "$items" ]]; then
        echo "[]"
        return
    fi
    
    local first=true
    echo "["
    while IFS= read -r item; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi
        echo -n "      \"$(json_escape "$item")\""
    done <<< "$items"
    echo ""
    echo "    ]"
}

# Compare snapshot with current state (JSON mode)
do_compare_json() {
    if [[ ! -f "$SNAPSHOT_DIR/services_running.txt" ]]; then
        echo '{"error": "No snapshot found. Please run snapshot command first.", "status": "error"}'
        exit 1
    fi

    local has_issue=0
    local current_services=$(mktemp)
    local current_procs=$(mktemp)
    local current_ports=$(mktemp)
    
    get_systemd_services > "$current_services"
    get_running_processes > "$current_procs"
    get_listening_ports > "$current_ports"

    # Stopped services
    local stopped_services=$(comm -23 "$SNAPSHOT_DIR/services_running.txt" "$current_services")
    if [[ -n "$stopped_services" ]]; then
        has_issue=1
    fi

    # Newly started services
    local new_services=$(comm -13 "$SNAPSHOT_DIR/services_running.txt" "$current_services")

    # Stopped processes
    local stopped_procs=$(comm -23 "$SNAPSHOT_DIR/processes.txt" "$current_procs" | grep -Ev "^($EXCLUDE_PROCS)" || true)
    if [[ -n "$stopped_procs" ]]; then
        has_issue=1
    fi

    # Port comparison
    local old_ports=$(grep -oE ':[0-9]+' "$SNAPSHOT_DIR/ports.txt" 2>/dev/null | sort -u || true)
    local new_ports=$(grep -oE ':[0-9]+' "$current_ports" 2>/dev/null | sort -u || true)
    local missing_ports=$(comm -23 <(echo "$old_ports") <(echo "$new_ports") 2>/dev/null || true)
    if [[ -n "$missing_ports" ]]; then
        has_issue=1
    fi

    # Generate JSON
    local json_output
    json_output=$(cat << EOF
{
  "hostname": "$HOSTNAME",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
  "status": "$([ $has_issue -eq 0 ] && echo "success" || echo "failure")",
  "has_issues": $([ $has_issue -eq 1 ] && echo "true" || echo "false"),
  "snapshot_time": "$(grep 'Snapshot Time:' "$SNAPSHOT_DIR/metadata.txt" 2>/dev/null | cut -d: -f2- | xargs || echo "unknown")",
  "services": {
    "stopped": $(array_to_json "$stopped_services"),
    "new": $(array_to_json "$new_services")
  },
  "processes": {
    "stopped": $(array_to_json "$stopped_procs")
  },
  "ports": {
    "missing": $(array_to_json "$missing_ports")
  }
}
EOF
)

    # JSON output
    echo "$json_output"
    
    # Send to API (optional)
    if [[ -n "$API_URL" ]]; then
        send_to_api "$json_output" "$API_URL"
    fi

    rm -f "$current_services" "$current_procs" "$current_ports"
    
    if [[ $has_issue -eq 1 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Compare snapshot with current state (normal mode)
do_compare() {
    if [[ "$JSON_MODE" == "true" ]]; then
        do_compare_json
        return
    fi

    if [[ ! -f "$SNAPSHOT_DIR/services_running.txt" ]]; then
        echo -e "${RED}[ERROR]${NC} No snapshot found. Please run 'snapshot' command first."
        exit 1
    fi

    echo -e "${BLUE}${LINE}${NC}"
    echo -e "${BLUE}  Process Comparison Report After Server Reboot${NC}"
    echo -e "${BLUE}  Host: $HOSTNAME${NC}"
    echo -e "${BLUE}  Comparison Time: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${BLUE}${LINE}${NC}"
    echo ""

    # Output snapshot metadata
    if [[ -f "$SNAPSHOT_DIR/metadata.txt" ]]; then
        echo -e "${YELLOW}[Snapshot Information]${NC}"
        cat "$SNAPSHOT_DIR/metadata.txt"
        echo ""
    fi

    local has_issue=0

    # 1. Compare systemd services
    echo -e "${YELLOW}[1] Systemd Service Comparison${NC}"
    echo -e "${THIN_LINE}"

    current_services=$(mktemp)
    get_systemd_services > "$current_services"

    # Find stopped services
    stopped_services=$(comm -23 "$SNAPSHOT_DIR/services_running.txt" "$current_services")
    if [[ -n "$stopped_services" ]]; then
        echo -e "${RED}[!] Services not running:${NC}"
        while IFS= read -r svc; do
            status=$(systemctl is-active "$svc" 2>/dev/null || true)
            [[ -z "$status" ]] && status="unknown"
            echo -e "    ${RED}✗${NC} $svc (status: $status)"
        done <<< "$stopped_services"
        has_issue=1
    else
        echo -e "${GREEN}[✓] All services running normally${NC}"
    fi

    # Newly started services
    new_services=$(comm -13 "$SNAPSHOT_DIR/services_running.txt" "$current_services")
    if [[ -n "$new_services" ]]; then
        echo -e "${BLUE}[i] Newly started services:${NC}"
        while IFS= read -r svc; do
            echo -e "    ${BLUE}+${NC} $svc"
        done <<< "$new_services"
    fi

    rm -f "$current_services"
    echo ""

    # 2. Compare processes
    echo -e "${YELLOW}[2] Process Comparison${NC}"
    echo -e "${THIN_LINE}"

    current_procs=$(mktemp)
    get_running_processes > "$current_procs"

    # Find stopped processes
    stopped_procs=$(comm -23 "$SNAPSHOT_DIR/processes.txt" "$current_procs" | grep -Ev "^($EXCLUDE_PROCS)" || true)
    if [[ -n "$stopped_procs" ]]; then
        echo -e "${RED}[!] Processes not running:${NC}"
        while IFS= read -r proc; do
            echo -e "    ${RED}✗${NC} $proc"
        done <<< "$stopped_procs"
        has_issue=1
    else
        echo -e "${GREEN}[✓] All major processes running${NC}"
    fi

    rm -f "$current_procs"
    echo ""

    # 3. Compare ports
    echo -e "${YELLOW}[3] Listening Port Comparison${NC}"
    echo -e "${THIN_LINE}"

    if [[ -f "$SNAPSHOT_DIR/ports.txt" ]]; then
        current_ports=$(mktemp)
        get_listening_ports > "$current_ports"

        # Simple port comparison
        old_ports=$(grep -oE ':[0-9]+' "$SNAPSHOT_DIR/ports.txt" 2>/dev/null | sort -u || true)
        new_ports=$(grep -oE ':[0-9]+' "$current_ports" 2>/dev/null | sort -u || true)

        missing_ports=$(comm -23 <(echo "$old_ports") <(echo "$new_ports") 2>/dev/null || true)
        if [[ -n "$missing_ports" ]]; then
            echo -e "${RED}[!] Ports not listening:${NC}"
            echo "$missing_ports" | while read -r port; do
                echo -e "    ${RED}✗${NC} $port"
            done
            has_issue=1
        else
            echo -e "${GREEN}[✓] All ports listening normally${NC}"
        fi

        rm -f "$current_ports"
    fi
    echo ""

    # Result summary
    echo -e "${YELLOW}${LINE}${NC}"
    if [[ $has_issue -eq 1 ]]; then
        echo -e "${RED}[Result] Some services/processes are not running!${NC}"
        echo -e "${YELLOW}       Please check the list above and manually start if needed.${NC}"
        exit 1
    else
        echo -e "${GREEN}[Result] All services and processes are normal!${NC}"
        exit 0
    fi
}

# Check snapshot status
do_status() {
    if [[ "$JSON_MODE" == "true" ]]; then
        if [[ -d "$SNAPSHOT_DIR" && -f "$SNAPSHOT_DIR/metadata.txt" ]]; then
            echo '{"status": "exists", "location": "'"$SNAPSHOT_DIR"'"}'
        else
            echo '{"status": "not_found", "message": "No snapshot found"}'
        fi
        return
    fi

    echo -e "${BLUE}[Snapshot Status]${NC}"
    echo -e "${THIN_LINE}"

    if [[ -d "$SNAPSHOT_DIR" && -f "$SNAPSHOT_DIR/metadata.txt" ]]; then
        echo -e "${GREEN}Snapshot exists${NC}"
        echo ""
        cat "$SNAPSHOT_DIR/metadata.txt"
        echo ""
        echo "Saved files:"
        ls -la "$SNAPSHOT_DIR"/*.txt 2>/dev/null || echo "  (none)"
    else
        echo -e "${YELLOW}No snapshot${NC}"
        echo "Please run '$0 snapshot' command first."
    fi
}

# Main logic - Parameter parsing
COMMAND="${1:-}"
shift || true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_MODE=true
            shift
            ;;
        --api-url)
            API_URL="${2:-}"
            if [[ -z "$API_URL" ]]; then
                echo "Error: --api-url requires a URL argument" >&2
                exit 1
            fi
            shift 2
            ;;
        *)
            if [[ -z "$COMMAND" ]]; then
                COMMAND="$1"
            fi
            shift
            ;;
    esac
done

case "$COMMAND" in
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
