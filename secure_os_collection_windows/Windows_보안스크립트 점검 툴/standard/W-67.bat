@echo off
echo �������������������� W-67. �����͹̳� ���� Ÿ�Ӿƿ� ���� >> %FILENAME%
echo. >> %FILENAME%

reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" | findstr /i "fDenyTSConnections"	| findstr /i "0x0" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, ���� �͹̳� ���񽺰� ��Ȱ��ȭ�Ǿ� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" | findstr /i "fDenyTSConnections" >> %FILENAME%
) else (
	reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" > %TEMP%\Remote_temp.txt
	type %TEMP%\Remote_temp.txt | findstr /i "MaxIdleTime" > nul
	if errorlevel 1 (
		echo �� ��� : ���, Ȱ�� �������� ���� �͹̳� ���� ���ǿ� �ð� ���� ���� ��å�� �������� ���� >> %FILENAME%
		echo. >> %FILENAME%	
		echo �� �� ��Ȳ >> %FILENAME%	
		echo. >> %FILENAME%
		echo - MaxIdleTime ������Ʈ�� ���� �������� ���� >> %FILENAME%	
	) else (
		type %TEMP%\Remote_temp.txt | findstr /i "MaxIdleTime" > %TEMP%\Remote_idletime.txt
		type %TEMP%\Remote_idletime.txt | findstr /i "0x0" > nul
		if errorlevel 1 (
			echo �� ��� : ��ȣ, Session Timeout�� �����Ǿ� ���� >> %FILENAME%
			echo. >> %FILENAME%
			echo �� �� ��Ȳ >> %FILENAME%
			echo. >> %FILENAME%
			type %TEMP%\Remote_idletime.txt >> %FILENAME%
		) else (
			echo �� ��� : ���, Ȱ�� �������� ���� �͹̳� ���� ���ǿ� �ð� ���� ���� ��å�� ��� �� �� ���� ���� �Ǿ� ���� >> %FILENAME%
			echo. >> %FILENAME%
			echo �� �� ��Ȳ >> %FILENAME%
			echo. >> %FILENAME%
			type %TEMP%\Remote_idletime.txt >> %FILENAME%
		)
	)
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%