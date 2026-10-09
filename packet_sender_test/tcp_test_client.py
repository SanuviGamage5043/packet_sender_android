import socket
import time

ANDROID_IP = "192.168.1.2"
PORT = 5000

client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

print("Connecting...")
client.connect((ANDROID_IP, PORT))

print("Connected!")

messages = [
    b"Hello Android",
    b"Temperature: 25 C",
    b"Machine Status: RUNNING",
    b"Packet Sender TCP Test",
]

for message in messages:
    print("Sending:", message.decode())

    client.sendall(message)

    response = client.recv(4096)

    print(
        "Response:",
        response.decode(errors="replace")
    )

    time.sleep(1)

client.close()

print("Connection closed.")