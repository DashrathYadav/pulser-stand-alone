#!/usr/bin/env python3

import pulsar
import time
import sys
import os

def read_token_from_file(token_file):
    """Read JWT token from file"""
    try:
        # Convert forward slashes to backslashes for Windows compatibility
        windows_path = token_file.replace('/', os.sep)
        with open(windows_path, 'r', encoding='utf-8') as f:
            return f.read().strip()
    except FileNotFoundError:
        print(f"Error: Token file {windows_path} not found!")
        print("Please run setup-pulsar-jwt.bat first to generate the required tokens.")
        sys.exit(1)
    except Exception as e:
        print(f"Error reading token file: {e}")
        sys.exit(1)

def create_producer():
    """Create Pulsar producer with JWT authentication"""
    
    # Read client1 token (producer token)
    token_file = "tokens/client1-token.txt"
    jwt_token = read_token_from_file(token_file)
    
    print("Connecting to Pulsar broker with JWT authentication...")
    print(f"Using token from: {token_file}")
    
    try:
        # Create Pulsar client with JWT authentication
        client = pulsar.Client(
            service_url='pulsar://localhost:6650',
            authentication=pulsar.AuthenticationToken(jwt_token)
        )
        
        # Create producer
        producer = client.create_producer(
            topic='persistent://public/default/test-topic',
            producer_name='client1-producer'
        )
        
        print("Successfully connected to Pulsar broker!")
        print("Producer created for topic: persistent://public/default/test-topic")
        
        return client, producer
        
    except Exception as e:
        print(f"Error connecting to Pulsar: {e}")
        print("\nTroubleshooting tips:")
        print("1. Ensure Pulsar cluster is running: docker-compose up -d")
        print("2. Ensure JWT tokens are generated: run setup-pulsar-jwt.bat")
        print("3. Ensure permissions are set up: run setup-pulsar-jwt.bat")
        print("4. Check if broker is accessible on localhost:6650")
        sys.exit(1)

def send_messages_interactive(producer):
    """Send messages interactively based on user input"""
    print("\nReady to send messages!")
    print("Type your message and press Enter to send.")
    print("Type 'exit' to quit or press Ctrl+C to stop.")
    print("-" * 50)
    
    message_count = 0
    
    try:
        while True:
            try:
                # Get user input
                user_message = input("Enter message: ").strip()
                
                # Check if user wants to exit
                if user_message.lower() == 'exit':
                    print("Exiting producer...")
                    break
                
                # Skip empty messages
                if not user_message:
                    print("Empty message, please enter some text.")
                    continue
                
                # Add timestamp to the message
                timestamped_message = f"{user_message} - {time.strftime('%Y-%m-%d %H:%M:%S')}"
                
                # Send message
                msg_id = producer.send(timestamped_message.encode('utf-8'))
                message_count += 1
                print(f"✓ Message sent successfully - ID: {msg_id}")
                print()
                
            except EOFError:
                # Handle Ctrl+D
                print("\nReceived EOF, exiting...")
                break
            except Exception as e:
                print(f"Error sending message: {e}")
                continue
                
    except KeyboardInterrupt:
        print(f"\nReceived Ctrl+C, exiting...")
    
    print(f"\nTotal messages sent: {message_count}")
    print("Producer session ended.")

def main():
    """Main function"""
    print("=" * 50)
    print("Pulsar Producer with JWT Authentication")
    print("Client: client1 (Producer permissions)")
    print("=" * 50)
    
    # Create producer
    client, producer = create_producer()
    
    try:
        # Send messages interactively
        send_messages_interactive(producer)
        
    except KeyboardInterrupt:
        print("\nProducer interrupted by user")
        
    finally:
        # Clean up
        print("\nClosing producer and client...")
        producer.close()
        client.close()
        print("Producer closed successfully!")

if __name__ == "__main__":
    main()