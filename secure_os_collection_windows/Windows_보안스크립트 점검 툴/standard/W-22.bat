@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-22. IIS Exec 명령어 쉘 호출 진단 >> %FILENAME%
echo. >> %FILENAME%

echo ■ 결과 : 양호, IIS 6.0 이상 버전에서는 해당 항목의 취약점이 존재하지 않음 >> %FILENAME%
echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
echo [IIS 버전] >> %FILENAME%
reg query "HKLM\SOFTWARE\Microsoft\InetStp" | findstr /i "SetupString" >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%