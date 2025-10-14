@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-71. 원격에서 이벤트 로그파일 접근 차단	>> %FILENAME%
echo.	>> %FILENAME%
cacls %systemroot%\system32\config		> %TEMP%\rreventlog.txt
cacls %systemroot%\system32\logfiles	>> %TEMP%\rreventlog.txt

type %TEMP%\rreventlog.txt | findstr /I "everyone" 
if errorlevel 1 (
	echo ■ 결과 : 양호, 로그 디렉터리 접근권한에 Everyone 권한이 존재하지 않음			>> %FILENAME%
) else (
	echo ■ 결과 : 취약, 로그 디렉터리 접근권한에 Everyone 권한이 존재함			>> %FILENAME%
)

echo.	>> %FILENAME%
echo ■ 상세 현황			>> %FILENAME%
echo.	>> %FILENAME%
type %TEMP%\rreventlog.txt	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%