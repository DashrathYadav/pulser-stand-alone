# JWT Authentication and Authorization in Apache Pulsar

## Table of Contents
- [Introduction](#introduction)
- [JWT Basics](#jwt-basics)
- [Authentication vs Authorization](#authentication-vs-authorization)
- [Pulsar JWT Implementation](#pulsar-jwt-implementation)
- [Our Setup Deep Dive](#our-setup-deep-dive)
- [Step-by-Step Authentication Flow](#step-by-step-authentication-flow)
- [Code Analysis](#code-analysis)
- [Security Considerations](#security-considerations)

## Introduction

This guide explains how JWT (JSON Web Token) authentication and authorization work in Apache Pulsar, using our specific setup as a practical example. We'll break down each component and show how the authentication flow works from token generation to message processing.

## JWT Basics

### What is JWT?

JWT (JSON Web Token) is a compact, URL-safe token format used for securely transmitting information between parties. A JWT consists of three parts separated by dots (`.`):

```
header.payload.signature
```

### JWT Structure

**1. Header**
```json
{
  "alg": "RS256",
  "typ": "JWT"
}
```
- `alg`: Algorithm used for signing (we use RSA256)
- `typ`: Token type (always "JWT")

**2. Payload (Claims)**
```json
{
  "sub": "client1",
  "iat": 1692700800,
  "exp": 1692787200
}
```
- `sub`: Subject (the client identity)
- `iat`: Issued at time
- `exp`: Expiration time (optional in our setup)

**3. Signature**
```
RS256(
  base64UrlEncode(header) + "." + base64UrlEncode(payload),
  private_key
)
```

### Our JWT Example

When we generate a token for `client1`, it looks like:
```
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJjbGllbnQxIn0.signature...
```

Decoded:
- **Header**: `{"alg":"RS256","typ":"JWT"}`
- **Payload**: `{"sub":"client1"}`
- **Signature**: Signed with our private key

## Authentication vs Authorization

### Authentication (Who are you?)
- **Process**: Verifying the identity of the client
- **In Pulsar**: JWT token validation using public key
- **Our Setup**: Broker verifies tokens using `keys/public.key`
- **Question**: "Is this token valid and who does it belong to?"

### Authorization (What can you do?)
- **Process**: Determining what actions the authenticated client can perform
- **In Pulsar**: Role-based permissions on namespaces and topics
- **Our Setup**: client1 can produce, client2 can consume
- **Question**: "Can this client perform this specific action?"

### Flow Example
```
1. Authentication: "This JWT belongs to client1" ✓
2. Authorization: "Can client1 produce to this topic?" ✓
3. Action: Allow message production
```

## Pulsar JWT Implementation

### Components in Pulsar

**1. Authentication Provider**
```yaml
authenticationProviders: org.apache.pulsar.broker.authentication.AuthenticationProviderToken
```
- Handles JWT token validation
- Extracts subject from validated tokens

**2. Authorization Provider**
```yaml
authorizationProvider: org.apache.pulsar.broker.authorization.PulsarAuthorizationProvider
```
- Checks permissions based on authenticated subject
- Manages role-based access control

**3. Public Key Configuration**
```yaml
tokenPublicKey: file:///pulsar/keys/public.key
```
- Used to verify JWT signatures
- Must match the private key used for signing

## Our Setup Deep Dive

### 1. Key Generation

**Command in our setup:**
```bash
bin/pulsar tokens create-key-pair --output-private-key /keys/private.key --output-public-key /keys/public.key
```

**What happens:**
- Generates RSA key pair (2048-bit)
- Private key: Signs tokens (kept secure)
- Public key: Verifies tokens (shared with broker)

**Files created:**
- `keys/private.key`: Used for token generation
- `keys/public.key`: Used by broker for verification

### 2. Token Generation

**Admin Token:**
```bash
bin/pulsar tokens create --private-key /keys/private.key --subject admin
```

**Client Tokens:**
```bash
bin/pulsar tokens create --private-key /keys/private.key --subject client1
bin/pulsar tokens create --private-key /keys/private.key --subject client2
```

**Result:**
- `tokens/admin-token.txt`: JWT with subject="admin"
- `tokens/client1-token.txt`: JWT with subject="client1"
- `tokens/client2-token.txt`: JWT with subject="client2"

### 3. Broker Configuration

**In our docker-compose.yaml:**
```yaml
environment:
  # Enable authentication
  - authenticationEnabled=true
  - authenticationProviders=org.apache.pulsar.broker.authentication.AuthenticationProviderToken
  
  # Configure broker's own authentication
  - brokerClientAuthenticationPlugin=org.apache.pulsar.client.impl.auth.AuthenticationToken
  - brokerClientAuthenticationParameters=file:///pulsar/tokens/admin-token.txt
  
  # JWT verification key
  - tokenPublicKey=file:///pulsar/keys/public.key
  
  # Superuser roles
  - superUserRoles=admin
  
  # Enable authorization
  - authorizationEnabled=true
  - authorizationProvider=org.apache.pulsar.broker.authorization.PulsarAuthorizationProvider
```

### 4. Permission Setup

**Namespace permissions:**
```bash
# Grant produce permissions to client1
pulsar-admin namespaces grant-permission public/default --role client1 --actions produce,consume,functions

# Grant consume permissions to client2
pulsar-admin namespaces grant-permission public/default --role client2 --actions produce,consume,functions
```

**Topic permissions:**
```bash
# Grant topic-level permissions
pulsar-admin topics grant-permission persistent://public/default/test-topic --role client1 --actions produce,consume
pulsar-admin topics grant-permission persistent://public/default/test-topic --role client2 --actions produce,consume
```

## Step-by-Step Authentication Flow

### Producer Authentication Flow

**1. Producer Startup (producer.py)**
```python
# Read JWT token from file
token_file = "tokens/client1-token.txt"
jwt_token = read_token_from_file(token_file)

# Create authenticated client
client = pulsar.Client(
    service_url='pulsar://localhost:6650',
    authentication=pulsar.AuthenticationToken(jwt_token)
)
```

**2. Connection to Broker**
```
Client → Broker: Connect with JWT token
Broker → Broker: Validate JWT signature using public key
Broker → Broker: Extract subject "client1" from token
Broker → Client: Connection established (authenticated as client1)
```

**3. Producer Creation**
```python
producer = client.create_producer(
    topic='persistent://public/default/test-topic',
    producer_name='client1-producer'
)
```

**4. Authorization Check**
```
Client → Broker: Request to create producer on topic
Broker → Broker: Check if "client1" has "produce" permission on namespace "public/default"
Broker → Broker: Check if "client1" has "produce" permission on topic "test-topic"
Broker → Client: Producer creation allowed/denied
```

**5. Message Sending**
```python
msg_id = producer.send(message.encode('utf-8'))
```

**Flow:**
```
Client → Broker: Send message with authenticated connection
Broker → Broker: Verify client1 still has produce permissions
Broker → BookKeeper: Store message
Broker → Client: Return message ID
```

### Consumer Authentication Flow

**1. Consumer Startup (consumer.py)**
```python
# Read JWT token from file
token_file = "tokens/client2-token.txt"
jwt_token = read_token_from_file(token_file)

# Create authenticated client
client = pulsar.Client(
    service_url='pulsar://localhost:6650',
    authentication=pulsar.AuthenticationToken(jwt_token)
)
```

**2. Subscription Creation**
```python
consumer = client.subscribe(
    topic='persistent://public/default/test-topic',
    subscription_name='client2-subscription',
    consumer_name='client2-consumer'
)
```

**3. Authorization Check**
```
Client → Broker: Request to subscribe to topic
Broker → Broker: Verify JWT and extract "client2"
Broker → Broker: Check if "client2" has "consume" permission
Broker → Client: Subscription created
```

**4. Message Reception**
```python
msg = consumer.receive(timeout_millis=5000)
```

**Flow:**
```
Broker → Client: Push message to authenticated consumer
Client → Client: Process message
Client → Broker: Acknowledge message (as client2)
```

## Code Analysis

### Producer Authentication Code

**File: producer.py**

**Token Reading:**
```python
def read_token_from_file(token_file):
    # Convert paths for Windows compatibility
    windows_path = token_file.replace('/', os.sep)
    with open(windows_path, 'r', encoding='utf-8') as f:
        return f.read().strip()
```

**Client Creation with Authentication:**
```python
def create_producer():
    # Read client1 token (maps to subject="client1")
    token_file = "tokens/client1-token.txt"
    jwt_token = read_token_from_file(token_file)
    
    # Create client with JWT authentication
    client = pulsar.Client(
        service_url='pulsar://localhost:6650',
        authentication=pulsar.AuthenticationToken(jwt_token)  # JWT auth plugin
    )
    
    # Create producer (requires produce permissions for client1)
    producer = client.create_producer(
        topic='persistent://public/default/test-topic',
        producer_name='client1-producer'  # Operational name, not auth identity
    )
    
    return client, producer
```

### Consumer Authentication Code

**File: consumer.py**

**Consumer with Different Token:**
```python
def create_consumer():
    # Read client2 token (maps to subject="client2")
    token_file = "tokens/client2-token.txt"
    jwt_token = read_token_from_file(token_file)
    
    # Same authentication method, different token
    client = pulsar.Client(
        service_url='pulsar://localhost:6650',
        authentication=pulsar.AuthenticationToken(jwt_token)
    )
    
    # Create consumer (requires consume permissions for client2)
    consumer = client.subscribe(
        topic='persistent://public/default/test-topic',
        subscription_name='client2-subscription',
        consumer_name='client2-consumer'
    )
    
    return client, consumer
```

### Admin Operations Code

**File: setup-pulsar-jwt.bat**

**Using Admin Token for Management:**
```bash
# Admin operations require admin token
docker exec broker bin/pulsar-admin \
  --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken \
  --auth-params "file:///pulsar/tokens/admin-token.txt" \
  namespaces grant-permission public/default --role client1 --actions produce,consume,functions
```

**Flow:**
1. Admin command loads admin token (subject="admin")
2. Broker validates JWT and extracts "admin" subject
3. Broker checks if "admin" is in superUserRoles (it is)
4. Command executes with full privileges

## Security Considerations

### 1. Key Management

**Private Key Security:**
- `keys/private.key` must be kept secure
- Can generate valid tokens for any subject
- Should not be shared or committed to version control
- In production: Use secure key management systems

**Public Key Distribution:**
- `keys/public.key` can be shared safely
- Only used for verification, not generation
- Must be accessible to all brokers in cluster

### 2. Token Lifecycle

**Token Generation:**
- Done offline using private key
- No expiration set (in our setup)
- Subject determines the role/identity

**Token Validation:**
- Happens on every request
- Uses public key cryptography
- Stateless (no server-side token storage)

**Token Revocation:**
- Not implemented in our setup
- Production should consider short-lived tokens + refresh mechanism
- Or maintain a revocation list

### 3. Network Security

**TLS/SSL:**
- Our setup uses unencrypted connections (development)
- Production should enable TLS for all communications
- Prevents token interception

**Network Isolation:**
- Broker should be in secure network
- Client access should be controlled

### 4. Permission Model

**Principle of Least Privilege:**
- client1: Only produce permissions (as intended)
- client2: Only consume permissions (as intended)
- admin: Full access (superuser)

**Granular Permissions:**
- Namespace-level: `public/default`
- Topic-level: `persistent://public/default/test-topic`
- Action-level: `produce`, `consume`, `functions`

### 5. Audit and Monitoring

**Authentication Events:**
- Broker logs all authentication attempts
- Failed authentications are logged
- Monitor for unusual patterns

**Authorization Events:**
- Permission denied events are logged
- Track which clients access which resources
- Monitor for privilege escalation attempts

## Comparison with Other Auth Methods

### JWT vs Username/Password

**JWT Advantages:**
- Stateless (no server-side session storage)
- Contains claims (roles, permissions)
- Cryptographically signed
- Can carry additional metadata

**JWT in Our Setup:**
- No password storage needed
- Roles embedded in subject claim
- Cryptographic verification ensures integrity

### JWT vs TLS Client Certificates

**Similarities:**
- Both use public key cryptography
- Both provide strong authentication

**JWT Advantages:**
- Easier to generate and distribute
- Can be passed as simple strings
- Better integration with application logic

### JWT vs OAuth 2.0

**Our Setup:**
- Simple JWT without OAuth flow
- Pre-generated tokens (not dynamic)
- No authorization server

**Production Considerations:**
- Could integrate with OAuth 2.0 providers
- Dynamic token generation
- Centralized token management

## Troubleshooting Authentication Issues

### Common Issues and Solutions

**1. "Authentication failed"**
```
Cause: Invalid JWT token
Check: Token file exists and is readable
Verify: Token was generated with correct private key
Solution: Regenerate tokens
```

**2. "Authorization Error"**
```
Cause: Valid token but insufficient permissions
Check: Role permissions on namespace/topic
Verify: Subject in token matches role in permissions
Solution: Grant appropriate permissions
```

**3. "Connection refused"**
```
Cause: Network connectivity or broker not ready
Check: Broker is running and healthy
Verify: Authentication configuration is loaded
Solution: Wait for broker startup, check configuration
```

**4. "Token verification failed"**
```
Cause: Public key mismatch
Check: Public key file is accessible to broker
Verify: Public key matches private key used for generation
Solution: Ensure key pair consistency
```

## Best Practices

### Development
1. Use descriptive subject names (client1, client2, admin)
2. Keep tokens in secure files (not in code)
3. Use version control ignore for private keys
4. Test with minimal permissions first

### Production
1. Implement token expiration and refresh
2. Use secure key storage (HSM, key vaults)
3. Enable TLS for all communications
4. Implement comprehensive monitoring
5. Regular key rotation
6. Centralized token management

### Security
1. Never log full JWT tokens
2. Validate all incoming tokens
3. Monitor for authentication failures
4. Implement rate limiting
5. Use strong key sizes (2048+ bit RSA)

---

This guide provides a comprehensive understanding of how JWT authentication and authorization work in Apache Pulsar, mapped directly to our implementation. The combination of cryptographic verification (authentication) and role-based permissions (authorization) provides a robust security model for distributed messaging systems.