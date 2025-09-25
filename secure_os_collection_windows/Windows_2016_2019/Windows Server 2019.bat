@echo off
REM 현재 BAT 파일이 위치한 폴더로 이동
cd /d %~dp0

REM 기존 실행정책(CurrentUser 스코프)을 저장
for /f "delims=" %%a in ('powershell -NoProfile -Command "Get-ExecutionPolicy -Scope CurrentUser"') do set OLDPOLICY=%%a

REM 일시적으로 실행정책을 CurrentUser 스코프로 변경 (관리자 권한 불필요)
powershell -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force"

REM Windows Server 2019.ps1 실행 (경로 지정 중요)
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Windows Server 2019.ps1"

REM 실행정책(CurrentUser 스코프) 원상복구
powershell -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy %OLDPOLICY% -Force"

echo.
echo [안내] Windows Server 2019.ps1 실행 완료. 실행 정책(CurrentUser 스코프)을 [%OLDPOLICY%]로 복구했습니다.
echo 재부팅이 필요한 설정이 적용되었습니다.
echo.
set /p REBOOT=계속하려면 [Enter] 키를 누르세요. (누르면 즉시 재부팅됩니다)

REM 재부팅 실행
shutdown /r /t 0