@echo off

echo �������������������� W-71. ���ݿ��� �̺�Ʈ �α����� ���� ����	>> %FILENAME%
echo.	>> %FILENAME%
cacls %systemroot%\system32\config		> %TEMP%\rreventlog.txt
cacls %systemroot%\system32\logfiles	>> %TEMP%\rreventlog.txt

type %TEMP%\rreventlog.txt | findstr /I "everyone" 
if errorlevel 1 (
	echo �� ��� : ��ȣ, �α� ���͸� ���ٱ��ѿ� Everyone ������ �������� ����			>> %FILENAME%
) else (
	echo �� ��� : ���, �α� ���͸� ���ٱ��ѿ� Everyone ������ ������			>> %FILENAME%
)

echo.	>> %FILENAME%
echo �� �� ��Ȳ			>> %FILENAME%
echo.	>> %FILENAME%
type %TEMP%\rreventlog.txt	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%