@echo off

echo �������������������� W-35. �������� �׼��� �� �� �ִ� ������Ʈ�� ���	>> %FILENAME%
echo.	>> %FILENAME%
net start | findstr /I "Remote" | findstr /I "Registry"	> %TEMP%\rr.txt

if errorlevel 1 (
	echo �� ��� : ��ȣ, ���� ������Ʈ���� ������� ����		>> %FILENAME%
) else (
	echo �� ��� : ���, ���� ������Ʈ���� ����ϰ� ����		>> %FILENAME%
)
echo.	>> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo.	>> %FILENAME%
type %TEMP%\rr.txt	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%