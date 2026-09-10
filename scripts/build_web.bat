@echo off
echo ===================================================
echo   Building 3erdh (عِرضْ) Web Application (Release)
echo ===================================================

call flutter build web --release --base-href "/" --pwa-strategy offline-first
if %errorlevel% neq 0 (
    echo [ERROR] Flutter build failed.
    exit /b %errorlevel%
)

echo ===================================================
echo   Build Successful! Output ready in: build\web
echo ===================================================
