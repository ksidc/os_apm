@echo off

echo �������������������� W-57. �����͹̳� ���� ������ ����� �׷� ����                              >> %FILENAME%
echo.                              		>> %FILENAME%
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server"             >> %TEMP%\terminal_temp.txt
type %TEMP%\terminal_temp.txt | find /i "fDenyTSConnections" | find /i /v "fDenyTSConnectionsBackup" | find "0x1"  > nul
if errorlevel 1 (
	echo �� ��� : ���� ����, "���� ����ũ�� ���񽺸� ���� �α��� ��� ���� �׷�" �� ���ʿ��� �׷� �� ���� ��� ���� ����          >> %FILENAME%
	echo.                             	>> %FILENAME%
	echo �� �� ��Ȳ                      	>> %FILENAME%
	echo.                              	>> %FILENAME%
	echo [���� ����ũ�� ���� ���� ��� ����]		>> %FILENAME%
	type %TEMP%\terminal_temp.txt | find /i "fDenyTSConnections" | find /i /v "fDenyTSConnectionsBackup"          >> %FILENAME%
	echo.                              				>> %FILENAME%
	echo [���� ����ũ�� ���񽺸� ���� �α��� ��� ���� �׷� Ȯ��]		>> %FILENAME%
	type Config\%COMPUTERNAME%_Security_Policy.txt | find /I "SeRemoteInteractiveLogonRight"          >> %FILENAME%
	echo.                              				>> %FILENAME%
	
	echo [Administrators Group ������ Ȯ�� - Everyone�� �����ϹǷ� �ش� �׷� ���� �� ���]                           >> %FILENAME%
	net localgroup Administrators | find /i /v "Alias name" | find /i /v "comment" | find /i /v "members" | find /i /v "completed" | find /i /v "-"  >> %FILENAME%
	
	echo [Remote Desktop Users Group ������ Ȯ��]       >> %FILENAME%
	net localgroup "Remote Desktop Users" | find /i /v "Alias name" | find /i /v "comment" | find /i /v "members" | find /i /v "completed" | find /i /v "-"  >> %FILENAME%
) else (
	echo �� ��� : ��ȣ, ���� ����ũ�� ���񽺰� "���� ��� �ȵ�"���� �����Ǿ� ����          >> %FILENAME%
	echo.                              >> %FILENAME%
	echo �� �� ��Ȳ                      >> %FILENAME%
	echo.                              >> %FILENAME%
	echo [���� ����ũ�� ���� ���� ��� ����]     >> %FILENAME%
	type %TEMP%\terminal_temp.txt | find /i "fDenyTSConnections" | find /i /v "fDenyTSConnectionsBackup"          >> %FILENAME%
	echo.                              >> %FILENAME%
	echo ���� ����ũ�� ���� ������ ������ �������� �����Ǿ� �ֽ��ϴ�.					>> %FILENAME%	
) 

echo. >> %FILENAME%
echo ** ���� :  SeRemoteInteractiveLogonRight = *S-1-5-32-544,*S-1-5-32-555 �̸� ��ȣ >> %FILENAME%
echo ��� �������� ���ʿ��� ������ �ִ��� Ȯ��>> %FILENAME%


echo.             	>> %FILENAME%
echo.             	>> %FILENAME%
echo.            	>> %FILENAME%	