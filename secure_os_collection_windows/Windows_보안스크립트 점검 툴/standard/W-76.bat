@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-76. 사용자별 홈 디렉터리 권한 설정 								>> %FILENAME%
echo. 	>> %FILENAME%
dir "c:\Users\*" | findstr "<DIR>" | findstr /V "All Defalt . Public MSSQL"		> %TEMP%\HOME_TEMP.txt
for /F "tokens=5" %%j in (%TEMP%\HOME_TEMP.txt) do cacls "c:\Users\%%j"			> %TEMP%\HOME_TEMP2.txt

type %TEMP%\HOME_TEMP2.txt | findstr /i "Everyone"	> nul
if errorlevel 1 (
	echo ■ 결과 : 양호, Everyone 권한이 존재하지 않음	>> %FILENAME%
) else (
	echo ■ 결과 : 취약, everyone 권한이 부여된 사용자 홈디렉터리 존재함		>> %FILENAME%								
)

echo. 	>> %FILENAME%
echo ■ 상세 현황					>> %FILENAME%
echo. 	>> %FILENAME%
echo [사용자 홈디렉터리 정보]				> %TEMP%\result.txt
type %TEMP%\HOME_TEMP.txt				>> %TEMP%\result.txt
echo.								>> %TEMP%\result.txt
echo [사용자 계정 정보]					>> %TEMP%\result.txt
net user | findstr /i "active name " | findstr /i /V "full"		>> %TEMP%\result.txt
echo.								>> %TEMP%\result.txt
echo [사용자 홈디렉터리별 상세 권한 정보]	>> %TEMP%\result.txt
type %TEMP%\HOME_TEMP2.txt			>> %TEMP%\result.txt
echo.					>> %TEMP%\result.txt
type %TEMP%\result.txt	>> %FILENAME%
echo. 	>> %FILENAME%
echo. 	>> %FILENAME%
echo. 	>> %FILENAME%