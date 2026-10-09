import socket
import time

ANDROID_IP = "192.168.1.2"
PORT = 5000

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

messages = [
    b"Hello Android",
    b"Temperature: 25 C",
    b"Machine Status: RUNNING",
    b"Packet Sender Test",
]

for message in messages:
    sock.sendto(message, (ANDROID_IP, PORT))
    print("Sent:", message.decode())
    time.sleep(1)

sock.close()