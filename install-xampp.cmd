@echo off
rem Double-click to install Silkaura into XAMPP (C:\xampp). Start Apache and MySQL in XAMPP first.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\xampp-install.ps1" %*
pause
