@echo off

echo �������������������� W-19. IIS ���� ���丮 ���� >> %FILENAME%
echo. >> %FILENAME%

echo �� ��� : ��ȣ, IIS 6.0 �̻� ���������� �ش� �׸��� ������� �������� ���� >> %FILENAME%
echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
echo [IIS ����] >> %FILENAME%
reg query "HKLM\SOFTWARE\Microsoft\InetStp" | findstr /i "SetupString" >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%