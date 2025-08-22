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

**Note**: Initial permissions are automatically set by `setup-pulsar-jwt.bat` using namespace-level permissions only. Use these commands to modify permissions after setup.

### Permission Hierarchy and Configuration

Pulsar uses a hierarchical permission model with multiple levels of configuration:

```
Tenant (public)
  └── Namespace (default, custom-namespace) ← Permissions apply to ALL topics
      ├── Topic (test-topic) ← Inherits namespace permissions
      ├── Topic (logs-topic) ← Can override with specific permissions
      └── Topic (metrics-topic) ← Inherits namespace permissions
```

#### **Permission Levels (from broad to specific):**

| Level | Scope | When to Use | Command Pattern |
|-------|-------|-------------|----------------|
| **Tenant** | All namespaces in tenant | Multi-tenant setups | `tenants grant-permission` |
| **Namespace** | All topics in namespace | **Most common** (our setup) | `namespaces grant-permission` |
| **Topic** | Single specific topic | Fine-grained control | `topics grant-permission` |

#### **Permission Inheritance:**
- ✅ **Namespace permissions** apply to ALL topics (current and future)
- 🎯 **Topic permissions** override namespace permissions for that specific topic
- 🔒 **Most specific permission wins** (Topic > Namespace > Tenant)

#### **Our Setup Uses:**
- **Namespace-level permissions only** (simplest and most common)
- Covers all topics in `public/default` namespace
- No topic-specific permissions needed (inherits from namespace)

### View Current Permissions

```cmd
# View namespace permissions
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces permissions public/default

# View topic permissions
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" topics permissions persistent://public/default/test-topic

# List all namespaces
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces list public
```

### Configurable Permission Levels

#### **1. Tenant-Level Permissions (Broadest)**
```cmd
# Grant permissions across ALL namespaces in tenant
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" tenants grant-permission public --role admin-user --actions produce,consume,functions

# Use case: Multi-tenant setup where one role needs access to everything
```

#### **2. Namespace-Level Permissions (Recommended - Our Setup)**
```cmd
# Grant permissions to ALL topics in namespace (current and future)
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces grant-permission public/default --role client1 --actions produce,consume,functions

# Create new namespace with specific permissions
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces create public/logs
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces grant-permission public/logs --role log-reader --actions consume
```

#### **3. Topic-Level Permissions (Most Specific)**
```cmd
# Grant permissions to specific topic only (overrides namespace permissions)
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" topics grant-permission persistent://public/default/sensitive-topic --role client1 --actions consume

# Use case: Restrict access to sensitive topics while allowing general access
```

### Grant Permissions

#### **Create New Client with Permissions**
```cmd
# Step 1: Generate new token
docker run --rm -v "%CD%/keys:/keys" -v "%CD%/tokens:/tokens" apachepulsar/pulsar-all:latest bin/pulsar tokens create --private-key /keys/private.key --subject newclient > tokens\newclient-token.txt

# Step 2: Grant namespace permissions (recommended)
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces grant-permission public/default --role newclient --actions consume
```

#### **Modify Existing Client Permissions**
```cmd
# Add more actions to existing client
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces grant-permission public/default --role client1 --actions produce,consume,functions,sources,sinks
```

### Revoke Permissions

#### **Tenant-Level Revoke**
```cmd
# Remove all permissions for a role from entire tenant
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" tenants revoke-permission public --role admin-user
```

#### **Namespace-Level Revoke**
```cmd
# Remove all permissions for a role from namespace (most common)
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces revoke-permission public/default --role client1

# Remove from specific namespace
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces revoke-permission public/logs --role log-reader
```

#### **Topic-Level Revoke**
```cmd
# Remove permissions for a role from specific topic only
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" topics revoke-permission persistent://public/default/sensitive-topic --role client1
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

#### **Scenario 1: Read-Only Client**
```cmd
# Revoke existing permissions
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces revoke-permission public/default --role client1

# Grant only consume permission (applies to all topics in namespace)
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces grant-permission public/default --role client1 --actions consume
```

#### **Scenario 2: Write-Only Client**
```cmd
# Create new write-only client
docker run --rm -v "%CD%/keys:/keys" -v "%CD%/tokens:/tokens" apachepulsar/pulsar-all:latest bin/pulsar tokens create --private-key /keys/private.key --subject writeonly > tokens\writeonly-token.txt

# Grant only produce permission
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces grant-permission public/default --role writeonly --actions produce
```

#### **Scenario 3: Full Admin Client**
```cmd
# Give client full admin permissions on namespace
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces grant-permission public/default --role client2 --actions produce,consume,functions,sources,sinks,packages
```

#### **Scenario 4: Multi-Namespace Access**
```cmd
# Create client with access to multiple namespaces
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces create public/metrics
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces grant-permission public/default --role datacollector --actions produce
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces grant-permission public/metrics --role datacollector --actions produce
```

#### **Scenario 5: Topic-Specific Override**
```cmd
# Client has general namespace access but restricted access to sensitive topic
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces grant-permission public/default --role client1 --actions produce,consume

# Override: only consume access to sensitive topic
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" topics grant-permission persistent://public/default/sensitive-data --role client1 --actions consume
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