@echo off

echo �������������������� W-63. DNS ���� ���� ���� >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Net_Start.txt | find /i "DNS Server" > nul
if errorlevel 1 ( 
	echo �� ��� : ��ȣ, DNS ���񽺰� ��Ȱ��ȭ �Ǿ� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%	
) else (
	reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\DNS Server\Zones" /s | find /i "AllowUpdate" >> %TEMP%\win_63.txt
	type %TEMP%\win_63.txt | find /i "AllowUpdate" | find "1" > nul
	if errorlevel 1 (
		echo �� ��� : ��ȣ, DNS ���񽺰� �������̳�, ���� ������Ʈ "����"���� �����Ǿ� ���� >> %FILENAME%
	) else (
		echo �� ��� : ���, ���� ������Ʈ�� ������ DNS ������ ������ >> %FILENAME%
	)
	echo. >> %FILENAME%	
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	type %TEMP%\win_63.txt | find /i "AllowUpdate" >> %FILENAME%
	)
)
echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%
