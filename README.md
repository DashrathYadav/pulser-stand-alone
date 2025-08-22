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
```

## Notes

- **Fresh Setup**: Works on new Windows machines
- **Existing Setup**: Detects existing tokens/setup and skips generation
- **Secure**: All admin commands require JWT authentication
- **Portable**: Self-contained setup with persistent data

---

**That's it!** Run `setup-pulsar-jwt.bat` and start producing/consuming messages!