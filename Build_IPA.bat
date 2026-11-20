@echo off
chcp 65001 >nul
title 3105 x nminhios - Build IPA Tool
cd /d "%~dp0"

echo ========================================================
echo        3105 x nminhios - TỰ ĐỘNG THEO DÕI VÀ TẢI IPA
echo ========================================================
echo.

python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [LỖI] Không tìm thấy Python trên máy tính của bạn!
    echo Vui lòng cài đặt Python để sử dụng công cụ này.
    pause
    exit /b
)

python build_ipa.py
