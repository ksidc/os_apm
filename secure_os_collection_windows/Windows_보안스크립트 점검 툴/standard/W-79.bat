@echo off

echo �������������������� W-79. ���� �� ���͸� ��ȣ 	>> %FILENAME%
echo. 	>> %FILENAME%
wmic logicaldisk get caption,description,filesystem > %TEMP%\FILE_TEMP.TXT
type %TEMP%\FILE_TEMP.TXT | findstr /i "fat fat32" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, NTFS ���� �ý��۸� ����ϰ� ����					>> %FILENAME%
) else (
	echo �� ��� : ���, FAT ���� �ý����� ����ϰ� ����				>> %FILENAME%
)

echo. 	>> %FILENAME%
echo �� �� ��Ȳ				>> %FILENAME%
echo. 	>> %FILENAME%
type %TEMP%\FILE_TEMP.txt		>> %FILENAME%								
echo. 	>> %FILENAME%
echo. 	>> %FILENAME%
echo. 	>> %FILENAME%