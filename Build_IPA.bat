@echo off
title 3105 x PHUCVN - Build IPA Tool
cd /d "C:\Users\phuc vo\Downloads\nminhios-ipa-main"

python build_ipa.py
if %errorlevel% neq 0 (
    echo.
    echo [Loi] Chuong trinh bi dung dot ngot voi ma loi: %errorlevel%
)
pause