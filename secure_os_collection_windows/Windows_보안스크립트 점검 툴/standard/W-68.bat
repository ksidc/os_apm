@echo off

echo �������������������� W-68. ����� �۾��� �ǽɽ����� ����� ��ϵǾ� �ִ��� ����	>> %FILENAME%
echo.	>> %FILENAME%
at | schtasks | findstr /I "ready running"	> nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, ����� �۾��� �������� ����	>> %FILENAME%
) else (
	echo �� ��� : ���� ����, ���ʿ��� �۾� �� ��ɾ� Ȯ�� �ʿ� >> %FILENAME%
)

echo.	>> %FILENAME%
echo �� �� ��Ȳ	>> %FILENAME%
echo.	>> %FILENAME%
at | schtasks | findstr /I "ready running"	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%