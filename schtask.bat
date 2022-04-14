@echo off

schtasks /Create /SC MONTHLY /MO 3 /TN "SLAPS Password Reset" /TR "Powershell.exe -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -File "C:\ProgramData\Microsoft\SLAPS\New-LocalAdmin.ps1"" /RU SYSTEM /RL HIGHEST /F >NUL