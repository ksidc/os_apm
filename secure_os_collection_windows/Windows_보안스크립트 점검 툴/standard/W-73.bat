@echo off

echo �������������������� W-73. ����ڰ� ������ ����̹��� ��ġ�� �� ���� �� 	>> %FILENAME%
echo.	>> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "AddPrinterDrivers" | Tools\awk.exe -F\ "{print $9}"		> nul
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "AddPrinterDrivers" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, ���̵��� �̵�� ���� �� ������ ��롱 ��å�� ���ǵǾ� ���� �����Ƿ� ����ڰ� ������ ����̹��� ��ġ�� �� ����	>> %FILENAME%
	goto W-73_end
)

type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "AddPrinterDrivers" | findstr "4,1" > nul
if errorlevel 1 (
	echo �� ��� : ���, ����ڰ� ������ ����̹��� ��ġ�� �� �ֵ��� �����Ǿ� ����						>> %FILENAME%
) else (
	echo �� ��� : ��ȣ, ����ڰ� ������ ����̹��� ��ġ�� �� ������ �����Ǿ� ����					>> %FILENAME%
)

:W-73_end
echo.	>> %FILENAME%
echo �� �� ��Ȳ	>> %FILENAME%
echo.	>> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "AddPrinterDrivers" | Tools\awk.exe -F\ "{print $9}"		>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%