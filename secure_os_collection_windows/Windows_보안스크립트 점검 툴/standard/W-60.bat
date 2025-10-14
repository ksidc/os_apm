@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-60. SNMP 서비스 구동 점검 >> %FILENAME%
net start | findstr /I "SNMP" > nul

if errorlevel 1 ( 
	echo. >> %FILENAME%
	echo ■ 결과 : 양호, SNMP 서비스가 비활성화 되어 있음		>> %FILENAME%
) else (
	echo. >> %FILENAME%
	echo ■ 결과 : 취약, SNMP 서비스가 구동중임		>> %FILENAME%
)

echo. >> %FILENAME%
echo ■ 상세 현황	>> %FILENAME%
echo. >> %FILENAME%
net start | findstr /I "SNMP"	>> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%