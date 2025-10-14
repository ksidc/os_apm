@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-66. 불필요한 ODBC/OLE-DB 데이터 소스와 드라이브 제거 >> %FILENAME%
echo. >> %FILENAME%
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBC.ini\ODBC Data Sources" /s	> %TEMP%\ODB_TEMP.txt
type %TEMP%\ODB_TEMP.txt | find /i "ODBC" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	echo - 불필요한 데이터 소스 및 드라이브가 존재하지 않음 >> %FILENAME%
) else (
	echo ■ 결과 : 취약, 불필요한 데이터 소스 및 드라이브인지 확인 필요 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	type %TEMP%\ODB_TEMP.txt >> %FILENAME%
)
echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%