@echo off

echo �������������������� W-31. �ֽ� ������ ���� >> %FILENAME%
echo. >> %FILENAME%

echo �� ��� : ��ȣ, Windows Server 20012 �̻� ���������� �������� �������� ���� >> %FILENAME%
echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
echo [Windows ����] >> %FILENAME%
type %CONFIG%System_Info.txt | find /i "OS" | findstr /i "Name Version" | findstr /i /v "Host BIOS" >> %FILENAME%

echo. >> %FILENAME%
echo �� Windows 2008 ���� ������ ���, %CONFIG%System_Info.txt ������ �����Ͽ� ������ Ȯ�� �ʿ� >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%