from http.server import BaseHTTPRequestHandler, HTTPServer
import json

HOST = "0.0.0.0"
PORT = 8000


class TestHandler(BaseHTTPRequestHandler):

    def do_GET(self):
        response = {
            "message": "Hello from PC HTTP server",
            "method": "GET",
            "status": "success"
        }

        body = json.dumps(response).encode("utf-8")

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()

        self.wfile.write(body)

    def do_POST(self):
        content_length = int(
            self.headers.get("Content-Length", 0)
        )

        received = self.rfile.read(content_length)

        print(
            "Received:",
            received.decode("utf-8", errors="replace")
        )

        response = {
            "message": "POST received",
            "received": received.decode(
                "utf-8",
                errors="replace"
            )
        }

        body = json.dumps(response).encode("utf-8")

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()

        self.wfile.write(body)


server = HTTPServer((HOST, PORT), TestHandler)

print(f"HTTP server running on port {PORT}")

server.serve_forever()