@echo off
REM Quick diagnostic tool for admin authentication
echo ============================================
echo Admin Authentication Diagnostic Tool
echo ============================================
echo.

REM Check if admin token file exists
if not exist "tokens\admin-token.txt" (
    echo ERROR: Admin token file not found locally
    echo Run: setup-pulsar-jwt.bat
    exit /b 1
)

REM Check if admin token exists in container
docker exec broker test -f /pulsar/tokens/admin-token.txt >nul 2>&1
if errorlevel 1 (
    echo ERROR: Admin token not found in broker container
    echo The tokens directory may not be mounted correctly
    exit /b 1
)

echo Admin token file exists. Testing authentication...
echo.

REM Test authenticated health check
echo 1. Testing authenticated health check...
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" brokers healthcheck
if errorlevel 1 (
    echo ERROR: Authenticated health check failed
    echo Admin token may be invalid
    exit /b 1
) else (
    echo ✓ Authenticated health check successful!
)

echo.
echo 2. Testing list tenants...
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" tenants list
if errorlevel 1 (
    echo ERROR: List tenants failed
    exit /b 1
) else (
    echo ✓ List tenants successful!
)

echo.
echo 3. Testing namespace operations...
docker exec broker bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params "file:///pulsar/tokens/admin-token.txt" namespaces list public
if errorlevel 1 (
    echo ERROR: List namespaces failed
    exit /b 1
) else (
    echo ✓ List namespaces successful!
)

echo.
echo ============================================
echo Admin authentication is working correctly!
echo ============================================
echo.
echo This confirms your JWT setup is functioning properly.
echo If you're having client issues, run: verify-setup.bat
echo.
pause