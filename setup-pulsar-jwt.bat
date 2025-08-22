@echo off
setlocal enabledelayedexpansion

REM Complete Pulsar JWT Authentication Setup Script
REM Works on fresh Windows machines and existing setups
echo ============================================
echo Pulsar JWT Authentication Setup
echo ============================================
echo.

echo This script will set up Apache Pulsar with JWT authentication including:
echo - JWT key generation
echo - Admin and client token creation
echo - Pulsar cluster startup with authentication
echo - Client permissions configuration
echo - Verification of the setup
echo.

REM Check if Docker is available
docker --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not installed or not running
    echo Please install Docker Desktop and make sure it's running
    pause
    exit /b 1
)

echo Docker is available. Proceeding with setup.
echo.

REM Step 1: Generate JWT keys if they don't exist
if not exist "keys\private.key" (
    echo Step 1: Generating JWT key pair
    if not exist "keys" mkdir keys
    docker run --rm -v "%CD%/keys:/keys" apachepulsar/pulsar-all:latest ^
      bin/pulsar tokens create-key-pair --output-private-key /keys/private.key --output-public-key /keys/public.key
    
    if not exist "keys\private.key" (
        echo ERROR: Failed to generate JWT keys
        echo Make sure your drive is shared with Docker Desktop
        pause
        exit /b 1
    )
    echo [OK] JWT keys generated successfully
) else (
    echo Step 1: JWT keys already exist, skipping generation
)

REM Step 2: Generate tokens if they don't exist
if not exist "tokens" mkdir tokens

if not exist "tokens\admin-token.txt" (
    echo Step 2: Generating admin token
    docker run --rm -v "%CD%/keys:/keys" -v "%CD%/tokens:/tokens" apachepulsar/pulsar-all:latest ^
      bin/pulsar tokens create --private-key /keys/private.key --subject admin > tokens\admin-token.txt
    echo [OK] Admin token generated
) else (
    echo Step 2: Admin token already exists, skipping generation
)

if not exist "tokens\client1-token.txt" (
    echo Generating client1 token (producer)
    docker run --rm -v "%CD%/keys:/keys" -v "%CD%/tokens:/tokens" apachepulsar/pulsar-all:latest ^
      bin/pulsar tokens create --private-key /keys/private.key --subject client1 > tokens\client1-token.txt
    echo [OK] Client1 token generated
) else (
    echo Client1 token already exists, skipping generation
)

if not exist "tokens\client2-token.txt" (
    echo Generating client2 token (consumer)
    docker run --rm -v "%CD%/keys:/keys" -v "%CD%/tokens:/tokens" apachepulsar/pulsar-all:latest ^
      bin/pulsar tokens create --private-key /keys/private.key --subject client2 > tokens\client2-token.txt
    echo [OK] Client2 token generated
) else (
    echo Client2 token already exists, skipping generation
)

echo.
echo Step 3: Starting Pulsar cluster with JWT authentication
docker-compose up -d

echo Waiting for cluster to start (60 seconds)
timeout /t 60 /nobreak >nul

REM Step 4: Wait for broker to be ready and set up permissions
echo Step 4: Setting up client permissions
set /a counter=0
:waitloop
set /a counter+=1
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" brokers healthcheck >nul 2>&1
if errorlevel 1 (
    if !counter! leq 30 (
        echo Waiting for broker to be ready - attempt !counter!/30
        timeout /t 3 /nobreak >nul
        goto waitloop
    ) else (
        echo ERROR: Broker is not ready after 90 seconds
        echo Check status: docker-compose ps
        echo Check logs: docker logs broker
        pause
        exit /b 1
    )
)

echo [OK] Broker is ready!

REM Create tenant and namespace if needed
echo Setting up tenants and namespaces
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" tenants create public --allowed-clusters cluster-a 2>nul || echo "Tenant already exists"
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces create public/default 2>nul || echo "Namespace already exists"

REM Set up comprehensive permissions
echo Setting up client permissions
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces grant-permission public/default --role client1 --actions produce,consume,functions
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces grant-permission public/default --role client2 --actions produce,consume,functions

REM Create test topic with permissions
echo Creating test topic
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" topics create persistent://public/default/test-topic 2>nul || echo "Topic already exists"
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" topics grant-permission persistent://public/default/test-topic --role client1 --actions produce,consume
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" topics grant-permission persistent://public/default/test-topic --role client2 --actions produce,consume

echo.
echo Step 5: Verifying setup
echo.
echo Current permissions for public/default:
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces permissions public/default

echo.
echo ============================================
echo Setup completed successfully!
echo ============================================
echo.
echo Generated files:
echo - keys\private.key (JWT private key)
echo - keys\public.key (JWT public key)
echo - tokens\admin-token.txt (Admin token)
echo - tokens\client1-token.txt (Producer token)
echo - tokens\client2-token.txt (Consumer token)
echo.
echo Next steps:
echo 1. Install Python dependencies: pip install -r requirements.txt
echo 2. Test producer: python producer.py
echo 3. Test consumer: python consumer.py
echo.
echo For troubleshooting, run: verify-setup.bat
echo.
pause