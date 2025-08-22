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

def create_consumer():
    """Create Pulsar consumer with JWT authentication"""
    
    # Read client2 token (consumer token)
    token_file = "tokens/client2-token.txt"
    jwt_token = read_token_from_file(token_file)
    
    print("Connecting to Pulsar broker with JWT authentication...")
    print(f"Using token from: {token_file}")
    
    try:
        # Create Pulsar client with JWT authentication
        client = pulsar.Client(
            service_url='pulsar://localhost:6650',
            authentication=pulsar.AuthenticationToken(jwt_token)
        )
        
        # Create consumer
        consumer = client.subscribe(
            topic='persistent://public/default/test-topic',
            subscription_name='client2-subscription',
            consumer_name='client2-consumer'
        )
        
        print("Successfully connected to Pulsar broker!")
        print("Consumer created for topic: persistent://public/default/test-topic")
        print("Subscription: client2-subscription")
        
        return client, consumer
        
    except Exception as e:
        print(f"Error connecting to Pulsar: {e}")
        print("\nTroubleshooting tips:")
        print("1. Ensure Pulsar cluster is running: docker-compose up -d")
        print("2. Ensure JWT tokens are generated: run setup-pulsar-jwt.bat")
        print("3. Ensure permissions are set up: run setup-pulsar-jwt.bat")
        print("4. Check if broker is accessible on localhost:6650")
        sys.exit(1)

def consume_messages_continuous(consumer):
    """Consume messages continuously until interrupted"""
    print("\nListening for messages continuously...")
    print("Press Ctrl+C to stop the consumer")
    print("-" * 50)
    
    message_count = 0
    
    try:
        while True:
            try:
                # Receive message with a reasonable timeout for checking interrupts
                msg = consumer.receive(timeout_millis=5000)  # 5 second timeout
                
                # Process the message
                message_count += 1
                message_data = msg.data().decode('utf-8')
                message_id = msg.message_id()
                
                print(f"Message {message_count} received:")
                print(f"  ID: {message_id}")
                print(f"  Data: {message_data}")
                print(f"  Received at: {time.strftime('%Y-%m-%d %H:%M:%S')}")
                print("-" * 50)
                
                # Acknowledge the message
                consumer.acknowledge(msg)
                    
            except Exception as e:
                if "Timeout" in str(e):
                    # This is expected - just continue waiting for messages
                    # Print a dot every 30 seconds to show the consumer is alive
                    if message_count == 0 or (int(time.time()) % 30 == 0):
                        print(".", end="", flush=True)
                    continue
                else:
                    print(f"Error receiving message: {e}")
                    # Don't break on errors, just continue
                    time.sleep(1)
                    continue
                    
    except KeyboardInterrupt:
        print(f"\nConsumer interrupted by user")
    
    print(f"\nTotal messages consumed: {message_count}")
    print("Consumer session ended.")

def main():
    """Main function"""
    print("=" * 50)
    print("Pulsar Consumer with JWT Authentication")
    print("Client: client2 (Consumer permissions)")
    print("=" * 50)
    
    # Create consumer
    client, consumer = create_consumer()
    
    try:
        # Start consuming messages continuously
        consume_messages_continuous(consumer)
        
    except KeyboardInterrupt:
        print("\nConsumer interrupted by user")
        
    finally:
        # Clean up
        print("\nClosing consumer and client...")
        consumer.close()
        client.close()
        print("Consumer closed successfully!")

if __name__ == "__main__":
    main()