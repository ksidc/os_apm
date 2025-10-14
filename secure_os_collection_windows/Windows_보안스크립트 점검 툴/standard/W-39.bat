@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-39. 로그온 하지 않고 시스템 종료 허용 >> %FILENAME%
echo. >> %FILENAME%
type %CONFIG%Security_Policy.txt | find /i "ShutdownWithoutLogon" | Tools\awk.exe -F\ "{print $8}" >> %TEMP%\Shutdown_without.txt
FOR /f "tokens=2 delims=," %%s IN (%TEMP%\Shutdown_without.txt) DO set W_LOGON=%%s

if %W_LOGON% EQU 0 echo ■ 결과 : 양호, '로그온 하지 않고 시스템 종료 허용' 정책이 '사용 안 함'으로 설정되어 있음 >> %FILENAME%
if %W_LOGON% EQU 1 echo ■ 결과 : 취약, '로그온 하지 않고 시스템 종료 허용' 정책이 '사용'으로 설정되어 있음 >> %FILENAME%	

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Shutdown_without.txt >> %FILENAME%

echo. >> %FILENAME%
echo ※ 사용 안 함: 4,0 / 사용: 4,1 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%