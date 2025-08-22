# Pulsar JWT Authentication Setup for Windows

Simple setup for Apache Pulsar with JWT authentication on Windows using Docker Desktop.

## Prerequisites

- **Docker Desktop for Windows** (running and drive shared)
- **Python 3.7+** (with pip)
- **Windows Command Prompt** (run as Administrator recommended)

## Quick Setup

### 1. Complete Setup (One Command)
```cmd
setup-pulsar-jwt.bat
```
This single script handles everything:
- Generates JWT keys and tokens
- Starts Pulsar cluster with authentication
- Configures client permissions
- Verifies the setup

### 2. Install Python Dependencies
```cmd
pip install -r requirements.txt
```

### 3. Test the Setup
**Terminal 1 (Producer):**
```cmd
python producer.py
```
- Type custom messages and press Enter to send
- Type 'exit' or press Ctrl+C to stop

**Terminal 2 (Consumer):**
```cmd
python consumer.py
```
- Listens continuously for messages
- Press Ctrl+C to stop

## File Structure
```
pulser stand alone\
├── docker-compose.yaml          # Pulsar cluster with JWT auth
├── setup-pulsar-jwt.bat         # Complete setup script (MAIN)
├── verify-setup.bat             # Verification and troubleshooting tool
├── test-admin-auth.bat          # Admin authentication diagnostic tool
├── producer.py                  # Interactive producer with client1 token
├── consumer.py                  # Continuous consumer with client2 token
├── requirements.txt             # Python dependencies
├── README.md                    # Setup instructions
├── JWT-Authentication-Guide.md  # Comprehensive JWT guide
├── keys\                        # JWT keys (auto-generated)
│   ├── private.key
│   └── public.key
├── tokens\                      # Client tokens (auto-generated)
│   ├── admin-token.txt
│   ├── client1-token.txt
│   └── client2-token.txt
└── data\                        # Persistent data (auto-created)
```

## Authentication Details

- **admin**: Full superuser access
- **client1**: Producer permissions (used by producer.py)
- **client2**: Consumer permissions (used by consumer.py)

## Permission Management

**Note**: Initial permissions are automatically set by `setup-pulsar-jwt.bat`. Use these commands to modify permissions after setup.

### View Current Permissions

```cmd
# View namespace permissions
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces permissions public/default

# View topic permissions
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" topics permissions persistent://public/default/test-topic

# List all namespaces
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces list public
```

### Grant Permissions

```cmd
# Grant namespace permissions to existing clients
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces grant-permission public/default --role client1 --actions produce,consume,functions

# Grant topic permissions
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" topics grant-permission persistent://public/default/test-topic --role client1 --actions produce,consume

# Create new client with specific permissions
docker run --rm -v "%CD%/keys:/keys" -v "%CD%/tokens:/tokens" apachepulsar/pulsar-all:latest bin/pulsar tokens create --private-key /keys/private.key --subject newclient > tokens\newclient-token.txt

docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces grant-permission public/default --role newclient --actions consume
```

### Revoke Permissions

```cmd
# Remove all permissions for a role from namespace
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces revoke-permission public/default --role client1

# Remove all permissions for a role from topic
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" topics revoke-permission persistent://public/default/test-topic --role client1
```

### Available Actions

| Action | Description |
|--------|-------------|
| `produce` | Send messages to topics |
| `consume` | Receive messages from topics |
| `functions` | Deploy and manage functions |
| `sources` | Create and manage sources |
| `sinks` | Create and manage sinks |
| `packages` | Upload and manage packages |

### Common Permission Scenarios

**Make a client read-only:**
```cmd
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces revoke-permission public/default --role client1

docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces grant-permission public/default --role client1 --actions consume
```

**Give a client full admin permissions:**
```cmd
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces grant-permission public/default --role client2 --actions produce,consume,functions,sources,sinks,packages
```

**Create a write-only client:**
```cmd
docker run --rm -v "%CD%/keys:/keys" -v "%CD%/tokens:/tokens" apachepulsar/pulsar-all:latest bin/pulsar tokens create --private-key /keys/private.key --subject writeonly > tokens\writeonly-token.txt

docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces grant-permission public/default --role writeonly --actions produce
```

## Troubleshooting

### Setup Issues
```cmd
verify-setup.bat
```

### Authentication Issues
```cmd
test-admin-auth.bat
```

### Common Solutions
1. **Drive not shared**: Docker Desktop → Settings → Resources → File Sharing
2. **Containers not running**: `docker-compose ps`
3. **Broker not ready**: Wait 60+ seconds after startup
4. **Token issues**: Re-run `setup-pulsar-jwt.bat`

### Useful Commands
```cmd
# Check cluster status
docker-compose ps

# View broker logs
docker logs broker

# Restart cluster
docker-compose restart

# Clean restart
docker-compose down && docker-compose up -d

# Check permissions
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces permissions public/default

# List all topics
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" topics list public/default

# Check topic permissions
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" topics permissions persistent://public/default/test-topic
```

## Notes

- **Fresh Setup**: Works on new Windows machines
- **Existing Setup**: Detects existing tokens/setup and skips generation
- **Secure**: All admin commands require JWT authentication
- **Portable**: Self-contained setup with persistent data

---

**That's it!** Run `setup-pulsar-jwt.bat` and start producing/consuming messages!