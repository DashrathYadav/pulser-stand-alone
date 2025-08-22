@echo off
REM Verify Pulsar JWT setup on Windows
echo ============================================
echo Pulsar JWT Setup Verification Tool
echo ============================================
echo.

echo Step 1: Checking Docker Desktop...
docker --version >nul 2>&1
if errorlevel 1 (
    echo ✗ Docker is not installed or not running
    echo   Please install Docker Desktop and make sure it's running
    exit /b 1
) else (
    echo ✓ Docker is installed and running
)

echo.
echo Step 2: Checking if Pulsar containers are running...
docker-compose ps
echo.

echo Step 3: Checking generated files...
if exist "keys\private.key" (
    echo ✓ Private key exists: keys\private.key
) else (
    echo ✗ Private key missing: keys\private.key
    echo   Run: setup-pulsar-jwt.bat
)

if exist "keys\public.key" (
    echo ✓ Public key exists: keys\public.key
) else (
    echo ✗ Public key missing: keys\public.key
    echo   Run: setup-pulsar-jwt.bat
)

if exist "tokens\admin-token.txt" (
    echo ✓ Admin token exists: tokens\admin-token.txt
) else (
    echo ✗ Admin token missing: tokens\admin-token.txt
    echo   Run: setup-pulsar-jwt.bat
)

if exist "tokens\client1-token.txt" (
    echo ✓ Client1 token exists: tokens\client1-token.txt
) else (
    echo ✗ Client1 token missing: tokens\client1-token.txt
    echo   Run: setup-pulsar-jwt.bat
)

if exist "tokens\client2-token.txt" (
    echo ✓ Client2 token exists: tokens\client2-token.txt
) else (
    echo ✗ Client2 token missing: tokens\client2-token.txt
    echo   Run: setup-pulsar-jwt.bat
)

echo.
echo Step 4: Testing broker connectivity...
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" brokers healthcheck >nul 2>&1
if errorlevel 1 (
    echo ✗ Broker is not responding or authentication failed
    echo   Check if containers are running: docker-compose ps
    echo   Check broker logs: docker logs broker
) else (
    echo ✓ Broker is responding and authentication working
)

echo.
echo Step 5: Checking namespace permissions...
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces permissions public/default >nul 2>&1
if errorlevel 1 (
    echo ✗ Cannot check permissions
    echo   Run: setup-pulsar-jwt.bat
) else (
    echo ✓ Permissions are configured
    echo   Current permissions:
    docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces permissions public/default
)

echo.
echo Step 6: Testing Python requirements...
python --version >nul 2>&1
if errorlevel 1 (
    echo ✗ Python is not installed or not in PATH
    echo   Install Python 3.7+ and add to PATH
) else (
    echo ✓ Python is available
    python -c "import pulsar" >nul 2>&1
    if errorlevel 1 (
        echo ✗ pulsar-client module not installed
        echo   Run: pip install -r requirements.txt
    ) else (
        echo ✓ pulsar-client module is installed
    )
)

echo.
echo ============================================
echo Verification completed!
echo ============================================
echo.
echo If you see any ✗ marks above:
echo 1. Run: setup-pulsar-jwt.bat (sets up everything)
echo 2. Run: pip install -r requirements.txt (for Python dependencies)
echo.
echo If all checks pass, test with:
echo - python producer.py
echo - python consumer.py
echo.
pause