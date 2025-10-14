@echo off

echo �������������������� W-61. SNMP ���� Ŀ�´�Ƽ��Ʈ�� ���⼺ ���� >> %FILENAME%
echo. >> %FILENAME%
net start | findstr /I "SNMP" > nul
if errorlevel 1 ( 
	echo �� ��� : ��ȣ, SNMP ���񽺰� ��Ȱ��ȭ�Ǿ� ����		>> %FILENAME%
	echo. > %TEMP%\SNMP_NAME.txt
) else (
	reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ValidCommunities" 	 > %TEMP%\SNMP_NAME.txt
	type %TEMP%\SNMP_NAME.txt | findstr /i "REG_DWORD" > nul
	if errorlevel 1 ( 
		echo �� ��� : ���, SNMP ���� Ŀ�´�Ƽ��Ʈ���� �������� ����	>> %FILENAME%

	) else (
		type %TEMP%\SNMP_NAME.txt | findstr /i "\<private\> \<public\>" | findstr /i /v "! @ # $ % ^ & * ( ) < > [ ] { } public_ _public private_ _private -" > nul    
		if errorlevel 1 (
			echo �� ��� : ��ȣ, Ŀ�´�Ƽ��Ʈ���� �����Ͽ� ����ϰ� ���� >> %FILENAME%
		) else (
			echo �� ��� : ���, Ŀ�´�Ƽ��Ʈ���� �������� ���� >> %FILENAME%
		)
	)
)
echo. >> %FILENAME%
echo �� �� ��Ȳ	>> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\SNMP_NAME.txt 	>> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%
