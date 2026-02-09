FROM python:3.11-slim

LABEL maintainer="bangco"
LABEL description="Process Monitor Test API Server"

# 작업 디렉토리 설정
WORKDIR /app

# 필요한 파일 복사
COPY test_api_server.py .

# 포트 노출
EXPOSE 8080

# 헬스체크
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

# 서버 실행
CMD ["python3", "test_api_server.py", "8080"]
