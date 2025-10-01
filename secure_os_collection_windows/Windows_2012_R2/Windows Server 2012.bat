@echo off
chcp 65001>nul & setlocal enabledelayedexpansion
rem ──────────────────────────────────────────
rem  Windows Server 2012 보안 설정 자동화 배치
rem ──────────────────────────────────────────

rem 현재 BAT 위치로 이동
cd /d "%~dp0"

rem 기존 실행정책(CurrentUser) 백업
for /f "delims=" %%a in ('
  powershell -NoProfile -Command "Get-ExecutionPolicy -Scope CurrentUser"
') do set "OLDPOLICY=%%a"
if "%OLDPOLICY%"=="" set "OLDPOLICY=Undefined"

rem PowerShell 스크립트 실행 (정책 변경 없이 Bypass 사용)
set "PS1PATH=%~dp0Windows Server 2012.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%PS1PATH%'"
set "PS_ERR=%errorlevel%"

rem 실행정책 복원
if /i "%OLDPOLICY%"=="Undefined" (
  powershell -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser Undefined -Force"
) else (
  powershell -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser %OLDPOLICY% -Force"
)

echo.
if %PS_ERR% NEQ 0 (
  echo [오류] PowerShell 스크립트가 오류 코드 %PS_ERR% 로 종료되었습니다.
  pause
  exit /b %PS_ERR%
)

echo [안내] 보안 설정 적용이 완료되었습니다. (실행정책: %OLDPOLICY% 로 복원)
echo 재부팅이 필요한 항목이 포함되어 있습니다.

choice /c YN /n /m "지금 재부팅하시겠습니까? (Y/N): "
if errorlevel 2 (
  echo 재부팅을 취소했습니다.
  exit /b 0
)

shutdown /r /t 30 /c "Windows Server 2012 보안 설정 적용 ? 30초 후 자동 재부팅"
exit /b 0
