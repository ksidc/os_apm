@echo off

echo �������������������� W-08. �ϵ��ũ �⺻ ���� ���� >> %FILENAME%
echo. >> %FILENAME%

TYPE %CONFIG%NetShare_Info.txt | find /v "IPC$" | find /i "$" | findstr /v /i "PRINT FAX" > nul
if errorlevel 1 (
	set share=0
	reg query "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" | findstr /i "AutoShareServer AutoShareWks" > %TEMP%\Netshare_reg.txt
	TYPE %TEMP%\Netshare_reg.txt | find "0x0" > nul
	if errorlevel 1 (
		echo �� ��� : ���, �⺻ ������ ���ŵǾ� ������, AutoShareServer�� �������� ���� >> %FILENAME%
	) else (
		echo �� ��� : ��ȣ, �⺻ ������ ���ŵǾ� ������, AutoShareServer�� �����Ǿ� ���� >> %FILENAME%
	)
) else (
	set share=1
	echo �� ��� : ���, �⺻ ������ ������ >> %FILENAME%
)
echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
echo [�ϵ��ũ �⺻ ���� ���] >> %FILENAME%
if %share% EQU 0 (
	echo - �⺻ ������ �������� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo [������Ʈ�� ����] >> %FILENAME%
	TYPE %TEMP%\Netshare_reg.txt | findstr /i "AutoShareServer AutoShareWks" > nul
	if errorlevel 1 (
		echo - AutoShareServer ������Ʈ�� ���� �������� ���� >> %FILENAME%
	) else (
		echo HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters >> %FILENAME%
		TYPE %TEMP%\Netshare_reg.txt >> %FILENAME%
	)
) else (
	type %CONFIG%NetShare_Info.txt | find /v "IPC$" | find /i "$" | findstr /v /i "PRINT FAX" >> %FILENAME%
)

echo. >> %FILENAME%
echo �� �ϵ��ũ ���� �� ��Ȳ�� %CONFIG%NetShare_Info.txt ���� ���� >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%