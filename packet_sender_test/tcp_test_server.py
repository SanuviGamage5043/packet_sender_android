import socket

HOST = "0.0.0.0"
PORT = 5000

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

server.bind((HOST, PORT))
server.listen(5)

print(f"TCP server running on port {PORT}")

while True:
    client, address = server.accept()

    print(f"Client connected: {address}")

    try:
        while True:
            data = client.recv(4096)

            if not data:
                break

            print(
                f"Received: "
                f"{data.decode(errors='replace')}"
            )

            response = b"Hello from TCP server"

            client.sendall(response)

    except Exception as e:
        print("Error:", e)

    finally:
        client.close()
        print("Client disconnected")