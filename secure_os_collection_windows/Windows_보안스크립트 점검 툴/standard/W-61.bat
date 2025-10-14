@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-61. SNMP 서비스 커뮤니티스트링 복잡성 설정 >> %FILENAME%
echo. >> %FILENAME%
net start | findstr /I "SNMP" > nul
if errorlevel 1 ( 
	echo ■ 결과 : 양호, SNMP 서비스가 비활성화되어 있음		>> %FILENAME%
	echo. > %TEMP%\SNMP_NAME.txt
) else (
	reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ValidCommunities" 	 > %TEMP%\SNMP_NAME.txt
	type %TEMP%\SNMP_NAME.txt | findstr /i "REG_DWORD" > nul
	if errorlevel 1 ( 
		echo ■ 결과 : 취약, SNMP 서비스 커뮤니티스트링이 지정되지 않음	>> %FILENAME%

	) else (
		type %TEMP%\SNMP_NAME.txt | findstr /i "\<private\> \<public\>" | findstr /i /v "! @ # $ % ^ & * ( ) < > [ ] { } public_ _public private_ _private -" > nul    
		if errorlevel 1 (
			echo ■ 결과 : 양호, 커뮤니티스트링을 변경하여 사용하고 있음 >> %FILENAME%
		) else (
			echo ■ 결과 : 취약, 커뮤니티스트링을 변경하지 않음 >> %FILENAME%
		)
	)
)
echo. >> %FILENAME%
echo ■ 상세 현황	>> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\SNMP_NAME.txt 	>> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%
