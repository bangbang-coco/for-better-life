#!/usr/bin/env python3
"""
Simple Test HTTP API Server
For testing monitor_salt.sh --api-url option

Usage:
    python3 test_api_server.py [port]
    
Default port: 8080
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import sys
import os
from datetime import datetime
from pathlib import Path

class MonitorAPIHandler(BaseHTTPRequestHandler):
    
    # Log directory setting
    LOG_DIR = os.getenv('MONITOR_LOG_DIR', '/var/log/monitor')
    
    def log_message(self, format, *args):
        """Pretty print log messages"""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        sys.stderr.write(f"[{timestamp}] {format % args}\n")
    
    def save_result_to_file(self, data):
        """Save result as JSON file"""
        try:
            Path(self.LOG_DIR).mkdir(parents=True, exist_ok=True)
            
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            hostname = data.get('hostname', 'unknown')
            filename = f"{self.LOG_DIR}/{hostname}_{timestamp}.json"
            
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            
            print(f"💾 Result saved: {filename}")
            return filename
        except Exception as e:
            print(f"⚠️  File save failed: {e}")
            return None
    
    def do_POST(self):
        """Handle POST requests"""
        content_length = int(self.headers.get('Content-Length', 0))
        
        if content_length == 0:
            self.send_error(400, "Empty request body")
            return
        
        try:
            # Read JSON data
            body = self.rfile.read(content_length)
            data = json.loads(body.decode('utf-8'))
            
            # Pretty print to console
            print("\n" + "="*80)
            print(f"📡 Received Monitoring Result")
            print("="*80)
            print(f"Hostname:     {data.get('hostname', 'N/A')}")
            print(f"Received:     {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"Snapshot:     {data.get('snapshot_time', 'N/A')}")
            print(f"Status:       {data.get('status', 'N/A')}")
            print(f"Has Issues:   {'⚠️  Yes' if data.get('has_issues') else '✅ No'}")
            
            # Stopped services
            stopped_services = data.get('services', {}).get('stopped', [])
            if stopped_services:
                print(f"\n❌ Stopped Services ({len(stopped_services)}):")
                for svc in stopped_services:
                    print(f"   - {svc}")
            
            # Newly started services
            new_services = data.get('services', {}).get('new', [])
            if new_services:
                print(f"\n➕ New Services ({len(new_services)}):")
                for svc in new_services:
                    print(f"   - {svc}")
            
            # Stopped processes
            stopped_procs = data.get('processes', {}).get('stopped', [])
            if stopped_procs:
                print(f"\n❌ Stopped Processes ({len(stopped_procs)}):")
                for proc in stopped_procs:
                    print(f"   - {proc}")
            
            # Missing ports
            missing_ports = data.get('ports', {}).get('missing', [])
            if missing_ports:
                print(f"\n❌ Ports Not Listening ({len(missing_ports)}):")
                for port in missing_ports:
                    print(f"   - {port}")
            
            print("="*80 + "\n")
            
            # Save to file
            saved_file = self.save_result_to_file(data)
            
            # Success response
            response = {
                "status": "success",
                "message": "Monitoring result received successfully",
                "received_at": datetime.now().isoformat(),
                "hostname": data.get('hostname'),
                "saved_to": saved_file
            }
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response, ensure_ascii=False, indent=2).encode('utf-8'))
            
        except json.JSONDecodeError as e:
            print(f"❌ JSON parse error: {e}")
            self.send_error(400, f"Invalid JSON: {e}")
        except Exception as e:
            print(f"❌ Processing error: {e}")
            self.send_error(500, f"Internal error: {e}")
    
    def do_GET(self):
        """Handle GET requests (health check)"""
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
                <p>Server is running successfully.</p>
                
                <h2>📡 API Endpoints</h2>
                
                <div class="endpoint">
                    <strong>POST /</strong> - Receive monitoring results
                    <pre>curl -X POST http://localhost:{PORT}/ \\
  -H "Content-Type: application/json" \\
  -d '{{"hostname": "test", "status": "success"}}'</pre>
                </div>
                
                <div class="endpoint">
                    <strong>GET /health</strong> - Health check
                    <pre>curl http://localhost:{PORT}/health</pre>
                </div>
                
                <h2>🔧 Usage Example</h2>
                <pre>./monitor_salt.sh compare --json --api-url http://localhost:{PORT}/</pre>
                
                <p><small>Test API Server | Port: {PORT}</small></p>
            </body>
            </html>
            """.replace("{PORT}", str(self.server.server_port))
            self.wfile.write(html.encode('utf-8'))

def run_server(port=8080):
    """Run API server"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, MonitorAPIHandler)
    
    print("="*80)
    print("🚀 Monitor API Test Server Started")
    print("="*80)
    print(f"📍 Address: http://localhost:{port}/")
    print(f"📍 Health check: http://localhost:{port}/health")
    print(f"📍 API endpoint: http://localhost:{port}/")
    print()
    print("Test command:")
    print(f"  ./monitor_salt.sh compare --json --api-url http://localhost:{port}/")
    print()
    print("Press Ctrl+C to stop")
    print("="*80 + "\n")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n\nShutting down server...")
        httpd.shutdown()

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    run_server(port)
