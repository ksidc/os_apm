@echo off
chcp 65001>nul & setlocal enabledelayedexpansion
:: ──────────────────────────────────────────
::  Windows Server 2012 보안 설정 자동화 배치
:: ──────────────────────────────────────────

:: 현재 BAT 위치로 이동
cd /d "%~dp0"

:: 현재 배치 파일 위치 기준 백업 폴더 설정
set "BACKUP_DIR=%~dp0backup"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

echo [*] 백업 시작: %BACKUP_DIR%
set "DATESTR=%DATE:~0,4%%DATE:~5,2%%DATE:~8,2%_%TIME:~0,2%%TIME:~3,2%"
set "DATESTR=%DATESTR: =0%"

:: 1. 로컬 보안 정책 백업
echo [*] 로컬 보안 정책 백업 중...
secedit /export /cfg "%BACKUP_DIR%\security_policy_%DATESTR%.inf" /areas SECURITYPOLICY USER_RIGHTS >nul 2>&1

:: 2. 전체 레지스트리 백업 (HKLM, HKCU, HKU, HKCR, HKCC)
echo [*] 전체 레지스트리 백업 중... (약간 시간 소요)
reg export HKLM "%BACKUP_DIR%\HKLM_%DATESTR%.reg" /y >nul 2>&1
reg export HKCU "%BACKUP_DIR%\HKCU_%DATESTR%.reg" /y >nul 2>&1
reg export HKU  "%BACKUP_DIR%\HKU_%DATESTR%.reg"  /y >nul 2>&1
reg export HKCR "%BACKUP_DIR%\HKCR_%DATESTR%.reg" /y >nul 2>&1
reg export HKCC "%BACKUP_DIR%\HKCC_%DATESTR%.reg" /y >nul 2>&1

:: 3. 감사 정책 백업
echo [*] 감사 정책 백업 중...
auditpol /backup /file:"%BACKUP_DIR%\auditpol_%DATESTR%.csv"

:: 4. 사용자 및 그룹 정보 백업
echo [*] 사용자/그룹 정보 백업 중...
net user > "%BACKUP_DIR%\users_%DATESTR%.txt"
net localgroup administrators > "%BACKUP_DIR%\administrators_%DATESTR%.txt"

:: 기존 실행정책(CurrentUser) 백업
for /f "delims=" %%a in ('
  powershell -NoProfile -Command "Get-ExecutionPolicy -Scope CurrentUser"
') do set "OLDPOLICY=%%a"
if "%OLDPOLICY%"=="" set "OLDPOLICY=Undefined"

:: PowerShell 스크립트 실행 (정책 변경 없이 Bypass 사용)
set "PS1PATH=%~dp0Windows Server 2012.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%PS1PATH%'"
set "PS_ERR=%errorlevel%"

:: 실행정책 복원
if /i "%OLDPOLICY%"=="Undefined" (
  powershell -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser Undefined -Force"
) else (
  powershell -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser %OLDPOLICY% -Force"
)

@echo off

echo.
if %PS_ERR% NEQ 0 (
  echo [오류] PowerShell 스크립트가 오류 코드 %PS_ERR% 로 종료되었습니다.
  pause
  exit /b %PS_ERR%
)

echo [안내] 보안 설정 적용이 완료되었습니다. (실행정책: %OLDPOLICY% 로 복원)
echo 재부팅이 필요한 항목이 포함되어 있습니다.

shutdown /r /t 30 /c "Windows Server 2012 보안 설정 적용 ? 30초 후 자동 재부팅"
exit /b 0
