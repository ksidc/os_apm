@echo off

echo �������������������� W-45. ��ũ���� ��ȣȭ ���� >> %FILENAME%
echo. >> %FILENAME%

wmic logicaldisk get caption,description,filesystem > %TEMP%\Disk_volume.txt
type %TEMP%\Disk_volume.txt | findstr /i "fat fat32" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, ��ȣȭ ������ NTFS ���� �ý����� ����ϰ� ���� >> %FILENAME%
) else (
	echo �� ��� : ���, ��ȣȭ �Ұ����� ���� �ý����� ����ϰ� ���� >> %FILENAME%
)

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Disk_volume.txt >> %FILENAME%

echo. >> %FILENAME%
echo �� ������ ���������� ��ȣ�� ���(IDC ��, PC �ð���ġ ��)�� ��ġ�ϰų�, >> %FILENAME%
echo    �ϵ��ũ ��ü �� ���� �ϵ��ũ�� �𰡿�¡ �Ǵ� õ�� �� ��� ���� ������ �����ϴ� ��� ���� >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%