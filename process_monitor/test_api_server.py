#!/usr/bin/env python3
"""
간단한 테스트용 HTTP API 서버
monitor_salt.sh의 --api-url 옵션 테스트용

사용법:
    python3 test_api_server.py [port]
    
기본 포트: 8080
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import sys
import os
from datetime import datetime
from pathlib import Path

clas# 로그 디렉토리 설정
    LOG_DIR = os.getenv('MONITOR_LOG_DIR', '/var/log/monitor')
    
    def log_message(self, format, *args):
        """로그 메시지를 예쁘게 출력"""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        sys.stderr.write(f"[{timestamp}] {format % args}\n")
    
    def save_result_to_file(self, data):
        """결과를 JSON 파일로 저장"""
        try:
            Path(self.LOG_DIR).mkdir(parents=True, exist_ok=True)
            
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            hostname = data.get('hostname', 'unknown')
            filename = f"{self.LOG_DIR}/{hostname}_{timestamp}.json"
            
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            
            print(f"💾 결과 저장: {filename}")
            return filename
        except Exception as e:
            print(f"⚠️  파일 저장 실패: {e}")
            return None
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        sys.stderr.write(f"[{timestamp}] {format % args}\n")
    
    def do_POST(self):
        """POST 요청 처리"""
        content_length = int(self.headers.get('Content-Length', 0))
        
        if content_length == 0:
            self.send_error(400, "Empty request body")
            return
        
        try:
            # JSON 데이터 읽기
            body = self.rfile.read(content_length)
            data = json.loads(body.decode('utf-8'))
            
            # 콘솔에 예쁘게 출력
            print("\n" + "="*80)
            print(f"📡 수신한 모니터링 결과")
            print("="*80)
            print(f"호스트명:     {data.get('hostname', 'N/A')}")
            print(f"수신 시간:    {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"스냅샷 시간:  {data.get('snapshot_time', 'N/A')}")
            print(f"상태:         {data.get('status', 'N/A')}")
            print(f"문제 여부:    {'⚠️  있음' if data.get('has_issues') else '✅ 없음'}")
            
            # 중지된 서비스
            stopped_services = data.get('services', {}).get('stopped', [])
            if stopped_services:
                print(f"\n❌ 중지된 서비스 ({len(stopped_services)}개):")
                for svc in stopped_services:
                    print(f"   - {svc}")
            
            # 파일로 저장
            saved_file = self.save_result_to_file(data)
            
            # 성공 응답
            response = {
                "status": "success",
                "message": "모니터링 결과가 성공적으로 수신되었습니다",
                "received_at": datetime.now().isoformat(),
                "hostname": data.get('hostname'),
                "saved_to": saved_file
            
            # 중지된 프로세스
            stopped_procs = data.get('processes', {}).get('stopped', [])
            if stopped_procs:
                print(f"\n❌ 중지된 프로세스 ({len(stopped_procs)}개):")
                for proc in stopped_procs:
                    print(f"   - {proc}")
            
            # 닫힌 포트
            missing_ports = data.get('ports', {}).get('missing', [])
            if missing_ports:
                print(f"\n❌ 리스닝하지 않는 포트 ({len(missing_ports)}개):")
                for port in missing_ports:
                    print(f"   - {port}")
            
            print("="*80 + "\n")
            
            # 성공 응답
            response = {
                "status": "success",
                "message": "모니터링 결과가 성공적으로 수신되었습니다",
                "received_at": datetime.now().isoformat(),
                "hostname": data.get('hostname')
            }
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response, ensure_ascii=False, indent=2).encode('utf-8'))
            
        except json.JSONDecodeError as e:
            print(f"❌ JSON 파싱 오류: {e}")
            self.send_error(400, f"Invalid JSON: {e}")
        except Exception as e:
            print(f"❌ 처리 오류: {e}")
            self.send_error(500, f"Internal error: {e}")
    
    def do_GET(self):
        """GET 요청 처리 (헬스체크)"""
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            response = {
                "status": "healthy",
                "service": "Monitor API Server",
                "timestamp": datetime.now().isoformat()
            }
            self.wfile.write(json.dumps(response, indent=2).encode('utf-8'))
        else:
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            html = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <title>Monitor API Server</title>
                <style>
                    body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
                    h1 { color: #333; }
                    pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
                    .endpoint { background: #e8f4f8; padding: 10px; margin: 10px 0; border-left: 4px solid #007acc; }
                </style>
            </head>
            <body>
                <h1>🚀 Monitor API Server</h1>
                <p>서버가 정상적으로 실행 중입니다.</p>
                
                <h2>📡 API 엔드포인트</h2>
                
                <div class="endpoint">
                    <strong>POST /</strong> - 모니터링 결과 수신
                    <pre>curl -X POST http://localhost:{PORT}/ \\
  -H "Content-Type: application/json" \\
  -d '{{"hostname": "test", "status": "success"}}'</pre>
                </div>
                
                <div class="endpoint">
                    <strong>GET /health</strong> - 헬스체크
                    <pre>curl http://localhost:{PORT}/health</pre>
                </div>
                
                <h2>🔧 사용 예시</h2>
                <pre>./monitor_salt.sh compare --json --api-url http://localhost:{PORT}/</pre>
                
                <p><small>테스트용 API 서버 | Port: {PORT}</small></p>
            </body>
            </html>
            """.replace("{PORT}", str(self.server.server_port))
            self.wfile.write(html.encode('utf-8'))

def run_server(port=8080):
    """API 서버 실행"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, MonitorAPIHandler)
    
    print("="*80)
    print("🚀 Monitor API 테스트 서버 시작")
    print("="*80)
    print(f"📍 주소: http://localhost:{port}/")
    print(f"📍 헬스체크: http://localhost:{port}/health")
    print(f"📍 API 엔드포인트: http://localhost:{port}/")
    print()
    print("테스트 명령:")
    print(f"  ./monitor_salt.sh compare --json --api-url http://localhost:{port}/")
    print()
    print("종료하려면 Ctrl+C를 누르세요")
    print("="*80 + "\n")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n\n서버를 종료합니다...")
        httpd.shutdown()

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    run_server(port)
