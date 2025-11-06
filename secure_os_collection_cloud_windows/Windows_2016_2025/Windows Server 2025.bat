@echo off
chcp 65001>nul & setlocal enabledelayedexpansion
:: ──────────────────────────────────────────
::  Windows Server 보안 설정 자동화 배치
:: ──────────────────────────────────────────

:: PowerShell 스크립트 실행 (정책 변경 없이 Bypass 사용)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Windows Server 2025.ps1"
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

exit /b 0


