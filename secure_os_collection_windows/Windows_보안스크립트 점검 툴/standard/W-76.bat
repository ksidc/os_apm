@echo off

echo �������������������� W-76. ����ں� Ȩ ���͸� ���� ���� 								>> %FILENAME%
echo. 	>> %FILENAME%
dir "c:\Users\*" | findstr "<DIR>" | findstr /V "All Defalt . Public MSSQL"		> %TEMP%\HOME_TEMP.txt
for /F "tokens=5" %%j in (%TEMP%\HOME_TEMP.txt) do cacls "c:\Users\%%j"			> %TEMP%\HOME_TEMP2.txt

type %TEMP%\HOME_TEMP2.txt | findstr /i "Everyone"	> nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, Everyone ������ �������� ����	>> %FILENAME%
) else (
	echo �� ��� : ���, everyone ������ �ο��� ����� Ȩ���͸� ������		>> %FILENAME%								
)

echo. 	>> %FILENAME%
echo �� �� ��Ȳ					>> %FILENAME%
echo. 	>> %FILENAME%
echo [����� Ȩ���͸� ����]				> %TEMP%\result.txt
type %TEMP%\HOME_TEMP.txt				>> %TEMP%\result.txt
echo.								>> %TEMP%\result.txt
echo [����� ���� ����]					>> %TEMP%\result.txt
net user | findstr /i "active name " | findstr /i /V "full"		>> %TEMP%\result.txt
echo.								>> %TEMP%\result.txt
echo [����� Ȩ���͸��� �� ���� ����]	>> %TEMP%\result.txt
type %TEMP%\HOME_TEMP2.txt			>> %TEMP%\result.txt
echo.					>> %TEMP%\result.txt
type %TEMP%\result.txt	>> %FILENAME%
echo. 	>> %FILENAME%
echo. 	>> %FILENAME%
echo. 	>> %FILENAME%