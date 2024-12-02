import gzip
import json
import socket
import traceback
import ai_commands
import os

# Create a TCP/IP socket
server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

# Bind the socket to the address and port
server_socket.bind(('127.0.0.1', 9999))  # Use localhost and some port (e.g., 65432)

# Listen for incoming connections
server_socket.listen()

print("Current working directory:", os.getcwd())

print("AI Server is waiting for a connection...")

# Accept a connection
connection, client_address = server_socket.accept()

log_errors = False

try:
    print(f"Connection from {client_address}")
    message_buffer = ""
    
    # Receive and send data in a loop
    while True:
        data = connection.recv(1024)  # Receive data (1024 is buffer size)
        try:
            if data:
                # decompressed_data = gzip.decompress(data)
                message = data.decode('utf-8').strip()  # Strip removes any newlines
                message_buffer += message
                # Parse the received JSON
                json_data = json.loads(message_buffer)
                message_buffer = ""
                # print(json_data["command"])
                json_response = ai_commands.respond_to_command(json_data)
                connection.sendall(json_response.encode('utf-8'))  # Send as utf-8 encoded string
        except json.JSONDecodeError as e:
            if log_errors:
                print("----- JSON ERROR -----")
                print(e)
                print("----------------------")
        except UnicodeDecodeError as e:
            if log_errors:
                print("----- Unicode Decode Error -----")
                print(e)
                print("--------------------------------")
        except Exception as e:
            if log_errors:
                print("--------------------------------")
                print("\nCAUGHT EXCEPTION:")
                print(e)
                traceback.print_exc()
                print("--------------------------------")
    

finally:
    # Clean up the connection
    connection.close()
