@echo off

echo �������������������� W-24. NetBIOS ���ε� ���� ���� ���� >> %FILENAME%
echo. >> %FILENAME%

reg query "HKLM\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces" /s | findstr . >> %CONFIG%NetBT.txt
type %CONFIG%NetBT.txt | find /i "NetbiosOptions" | findstr "0x0 0x1" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, NetbiosOptions�� 'NetBIOS over TCP/IP ��� �� ��'���� �����Ǿ� ���� >> %FILENAME%
) else (
	echo �� ��� : ���, NetbiosOptions�� 'NetBIOS over TCP/IP ���' �Ǵ� �⺻������ �����Ǿ� ���� >> %FILENAME%
)

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
type %CONFIG%NetBT.txt | find /i /v "ServerList" >> %FILENAME%

echo. >> %FILENAME%
echo �� NetbiosOptions - 0x2: NetBIOS ��� �� ��, 0x1: NetBIOS ���, 0x0: �⺻�� >> %FILENAME%
echo    TCP/IP ��Ʈ��ũ �������� %CONFIG%IPconfig.txt ���� ���� >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%