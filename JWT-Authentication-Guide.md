# JWT Authentication and Authorization in Apache Pulsar

## Table of Contents
- [Introduction](#introduction)
- [JWT Basics](#jwt-basics)
- [Cryptographic Keys in JWT](#cryptographic-keys-in-jwt)
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

## Cryptographic Keys in JWT

### Symmetric vs Asymmetric Cryptography

**Our Setup Uses: Asymmetric Cryptography (Public Key Cryptography)**

JWT supports both symmetric and asymmetric cryptographic approaches for signing and verification:

#### **Symmetric Key Cryptography**
```
Same key for signing AND verification
┌─────────────┐    shared secret    ┌─────────────┐
│   Token     │ ◄─────────────────► │   Verifier  │
│  Generator  │      (HS256)        │  (Broker)   │
└─────────────┘                     └─────────────┘
```

**Characteristics:**
- **Algorithm**: HMAC-SHA256 (HS256)
- **Key**: Same secret key for signing and verification
- **Use Case**: Single service or trusted environment
- **Security**: Shared secret must remain confidential
- **Distribution**: Difficult to distribute securely

#### **Asymmetric Key Cryptography (Our Setup)**
```
Private key for signing, Public key for verification
┌─────────────┐    private key     ┌─────────────┐    public key      ┌─────────────┐
│   Token     │ ◄─────────────────►│  Key Pair   │◄─────────────────► │   Verifier  │
│  Generator  │      (RS256)       │             │     (RS256)        │  (Broker)   │
└─────────────┘                    └─────────────┘                    └─────────────┘
```

**Characteristics:**
- **Algorithm**: RSA-SHA256 (RS256) - what we use
- **Keys**: Private key for signing, public key for verification
- **Use Case**: Distributed systems, multiple services
- **Security**: Private key kept secret, public key can be shared
- **Distribution**: Public key can be safely distributed

### RSA Key Pair in Our Setup

#### **Key Generation Process**
```bash
# Our command generates RSA key pair (2048-bit)
bin/pulsar tokens create-key-pair \
  --output-private-key /keys/private.key \
  --output-public-key /keys/public.key
```

**What happens:**
1. **RSA Key Pair Generation**: Creates mathematically related private/public key pair
2. **Private Key**: Used for signing JWTs (kept secure)
3. **Public Key**: Used for verification (shared with brokers)
4. **Key Size**: 2048-bit RSA (secure and industry standard)

#### **Private Key (keys/private.key)**
```
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...
-----END PRIVATE KEY-----
```

**Purpose:**
- **Token Signing**: Creates JWT signatures
- **Security**: Must be kept absolutely secure
- **Usage**: Only for token generation (offline process)
- **Access**: Should be restricted to token generation systems

**Mathematical Relationship:**
- Contains both private and public key components
- Can derive public key from private key (not reverse)
- Uses RSA algorithm with large prime numbers

#### **Public Key (keys/public.key)**
```
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvK...
-----END PUBLIC KEY-----
```

**Purpose:**
- **Token Verification**: Validates JWT signatures
- **Distribution**: Can be freely shared with all brokers
- **Security**: Safe to expose (cannot generate tokens)
- **Usage**: Real-time verification during client requests

**Mathematical Relationship:**
- Derived from private key during generation
- Cannot be used to derive private key (one-way function)
- Mathematically validates signatures created by private key

### JWT Signing Process with RSA

#### **Token Generation (using private key)**
```
1. Create Header: {"alg":"RS256","typ":"JWT"}
2. Create Payload: {"sub":"client1"}
3. Encode: Base64URL(header) + "." + Base64URL(payload)
4. Sign: RSA-SHA256(encoded_data, private_key)
5. Token: encoded_header.encoded_payload.signature
```

**Code representation:**
```python
# Simplified signing process
import jwt

# Our private key
private_key = open('keys/private.key', 'r').read()

# Create token
token = jwt.encode(
    payload={"sub": "client1"},
    key=private_key,
    algorithm="RS256"
)
```

#### **Token Verification (using public key)**
```
1. Receive: header.payload.signature
2. Extract: signature from token
3. Re-create: RSA-SHA256(header.payload, public_key)
4. Compare: provided_signature == computed_signature
5. Result: Valid/Invalid + extracted claims
```

**Code representation:**
```python
# Simplified verification process
import jwt

# Our public key
public_key = open('keys/public.key', 'r').read()

# Verify token
try:
    payload = jwt.decode(
        token=received_token,
        key=public_key,
        algorithms=["RS256"]
    )
    # payload = {"sub": "client1"}
    print(f"Valid token for: {payload['sub']}")
except jwt.InvalidTokenError:
    print("Invalid token")
```

### Security Advantages of Our Asymmetric Approach

#### **1. Key Distribution Security**
```
✓ Public key can be safely distributed to all brokers
✓ No shared secrets to manage across multiple services
✓ Private key only needed on token generation system
✓ Compromised public key doesn't allow token generation
```

#### **2. Scalability**
```
✓ Multiple brokers can verify tokens independently
✓ No need to synchronize secrets across cluster
✓ Easy to add new broker instances
✓ Centralized token generation, distributed verification
```

#### **3. Operational Security**
```
✓ Token generation can be offline/isolated
✓ Brokers never need access to signing capability
✓ Clear separation of concerns (sign vs verify)
✓ Private key can be stored in secure key management systems
```

### Key File Analysis in Our Setup

#### **File: keys/private.key**
```bash
# Example content structure
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7xKE...
[Base64 encoded RSA private key data]
...
-----END PRIVATE KEY-----
```

**Technical Details:**
- **Format**: PKCS#8 PEM format
- **Algorithm**: RSA
- **Key Size**: 2048 bits
- **Encoding**: Base64 within PEM structure
- **Usage**: Token signing only

#### **File: keys/public.key**
```bash
# Example content structure  
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvKxHE...
[Base64 encoded RSA public key data]
...
-----END PUBLIC KEY-----
```

**Technical Details:**
- **Format**: PKCS#8 PEM format
- **Algorithm**: RSA
- **Key Size**: 2048 bits (same as private key)
- **Encoding**: Base64 within PEM structure
- **Usage**: Token verification only

### Comparison: Symmetric vs Asymmetric in Pulsar Context

| Aspect | Symmetric (HS256) | Asymmetric (RS256) - Our Choice |
|--------|------------------|----------------------------------|
| **Key Management** | Shared secret across all services | Private key secure, public key distributed |
| **Token Generation** | Any service with shared secret | Only systems with private key |
| **Token Verification** | Any service with shared secret | Any service with public key |
| **Security Risk** | Shared secret compromise = full breach | Private key compromise = signing risk only |
| **Scalability** | Difficult to distribute secrets | Easy to distribute public keys |
| **Performance** | Faster (HMAC operations) | Slightly slower (RSA operations) |
| **Use Case** | Single service, trusted environment | Distributed systems, multiple brokers |
| **Our Setup** | ❌ Not used | ✅ Used (RS256) |

### Why We Chose Asymmetric (RS256)

**1. Distributed Architecture**
```
Multiple Pulsar brokers need to verify tokens
Public key can be safely shared with all brokers
No need to synchronize secrets across cluster
```

**2. Security Isolation**
```
Token generation happens offline/separately
Brokers only have verification capability
Compromised broker cannot generate valid tokens
```

**3. Operational Benefits**
```
Easy to add new brokers (just copy public key)
Clear separation between token issuance and verification
Supports centralized token management
```

**4. Industry Standard**
```
RS256 is widely adopted for distributed JWT systems
Better support in enterprise environments
Compatible with external JWT systems and tools
```

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