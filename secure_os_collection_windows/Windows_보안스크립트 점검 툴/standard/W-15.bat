@echo off

echo �������������������� W-15. IIS �� ���μ��� ���� ���� >> %FILENAME%
echo. >> %FILENAME%

%systemroot%\system32\inetsrv\appcmd list apppool /text:* | findstr /i "APPPOOL.NAME IdentityType" >> %TEMP%\App_pool_id.txt

type %TEMP%\App_pool_id.txt | find /i "LocalSystem" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, ���� ���α׷� Ǯ ID�� LocalSystem ���� �������� ���� >> %FILENAME%
) else (
	echo �� ��� : ���, ID�� LocalSystem ���� ������ ���� ���α׷� Ǯ�� ������ >> %FILENAME%
)
echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%

type %TEMP%\App_pool_id.txt >> %FILENAME%
echo. >> %FILENAME%
echo �� �⺻ ���� ����(LocalSystem, NetworkService, LocalService, ApplicationPoolIdentity) �Ǵ� ����� ���� ������ ����� �� ���� >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%