import socket

HOST = "0.0.0.0"
PORT = 5000

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

sock.bind((HOST, PORT))

print(f"UDP server running on port {PORT}")

while True:
    data, address = sock.recvfrom(4096)

    print(
        f"Received from {address}: "
        f"{data.decode(errors='replace')}"
    )

    response = b"Hello from UDP server"

    sock.sendto(response, address)