@echo off

echo �������������������� W-55. �ֱ� ��ȣ ���                              >> %FILENAME%
echo.                              >> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | find /I "history"          > %TEMP%\pw_history.txt
FOR /F "tokens=3" %%i IN (%TEMP%\pw_history.txt) DO set history_temp=%%i
if %history_temp% GEQ 12 (
	echo �� ��� : ��ȣ, �ֱ� ��ȣ ����� 12�� �̻����� �����Ǿ� ����          >> %FILENAME%
) else (
	echo �� ��� : ���, �ֱ� ��ȣ ����� 12�� �̸����� �����Ǿ� ����          >> %FILENAME%
)

echo.                              >> %FILENAME%
echo �� �� ��Ȳ                              >> %FILENAME%
echo.                              >> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | find /I "history"                              >> %FILENAME%
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%
