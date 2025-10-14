@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-62. SNMP Access Control 설정 >> %FILENAME%
echo. >> %FILENAME%	
net start | findstr /I "SNMP" > nul
if errorlevel 1 ( 
	echo ■ 결과 : 양호, SNMP 서비스가 비활성화되어 있음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	echo SNMP 서비스가 비활성화되어 있음 >> %FILENAME%
) else (
	reg query "HKLM\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers" | findstr "1"  > nul
	if errorlevel 1 (
		echo ■ 결과 : 취약, SNMP ACL을 설정하지 않음 >> %FILENAME%
	) else (
		echo ■ 결과 : 양호, SNMP ACL이 설정되어 있음 >> %FILENAME%
	)
	echo. >> %FILENAME%
	echo ■ 상세 현황		>> %FILENAME%
	echo. >> %FILENAME%
	reg query "HKLM\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers" | findstr /i /v "SNMP\Parameters\PermittedManagers" >> %FILENAME% 2>&1
)
echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%