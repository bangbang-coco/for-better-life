#!/bin/bash
#
# Monitor API Server 빠른 시작 스크립트
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Monitor API Server 시작 중..."
echo ""

# Docker 설치 확인
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker가 설치되어 있지 않습니다."
    echo "   Docker 설치: https://docs.docker.com/get-docker/"
    exit 1
fi

# Docker Compose 확인
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
    echo "❌ Error: Docker Compose가 설치되어 있지 않습니다."
    exit 1
fi

# Docker 실행 여부 확인
if ! docker info &> /dev/null; then
    echo "❌ Error: Docker가 실행되고 있지 않습니다."
    echo "   Docker를 시작해주세요."
    exit 1
fi

# 포트 사용 확인
if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  Warning: 포트 8080이 이미 사용 중입니다."
    echo "   다른 포트를 사용하려면 docker-compose.yml을 수정하세요."
    read -p "계속하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Docker Compose 실행
echo "📦 Docker 이미지 빌드 및 컨테이너 시작..."
if docker compose version &> /dev/null 2>&1; then
    docker compose up -d --build
else
    docker-compose up -d --build
fi

echo ""
echo "✅ Monitor API Server가 성공적으로 시작되었습니다!"
echo ""
echo "📍 API 엔드포인트: http://localhost:8080/"
echo "📍 웹 인터페이스:  http://localhost:8080/"
echo "📍 헬스체크:       http://localhost:8080/health"
echo ""
echo "📊 로그 확인:"
if docker compose version &> /dev/null 2>&1; then
    echo "   docker compose logs -f"
else
    echo "   docker-compose logs -f"
fi
echo ""
echo "🛑 서버 종료:"
if docker compose version &> /dev/null 2>&1; then
    echo "   docker compose down"
else
    echo "   docker-compose down"
fi
echo ""
echo "🧪 테스트 명령:"
echo "   ./monitor_salt.sh compare --json --api-url http://localhost:8080/"
echo ""
