@echo off
REM VESPA Staff Dashboard V3 - Deployment Script (Windows)
REM Run this to build and prepare for deployment

echo.
echo ========================================
echo VESPA Staff Dashboard V3 - Deployment
echo ========================================
echo.

REM Check if .env exists
if not exist .env (
    echo ERROR: .env file not found!
    echo Please create .env file with your Supabase credentials
    echo See .env.example for template
    pause
    exit /b 1
)

echo [OK] Environment file found
echo.

REM Install dependencies
echo Installing dependencies...
call npm install

if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)

echo [OK] Dependencies installed
echo.

REM Run build
echo Building for production...
call npm run build

if errorlevel 1 (
    echo ERROR: Build failed
    pause
    exit /b 1
)

echo [OK] Build successful
echo.

REM Check output
if exist dist (
    echo Build output created in dist/ folder
    dir dist /b
    echo.
) else (
    echo ERROR: dist/ folder not found
    pause
    exit /b 1
)

echo ========================================
echo Deployment build complete!
echo ========================================
echo.
echo Next steps:
echo 1. Upload dist/ folder to your CDN or hosting service
echo 2. Update Knack page to point to new bundle
echo 3. Test with real staff account
echo 4. Monitor Supabase logs for errors
echo.
echo Ready to deploy!
echo.
pause

