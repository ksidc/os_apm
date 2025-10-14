@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-35. 원격으로 액세스 할 수 있는 레지스트리 경로	>> %FILENAME%
echo.	>> %FILENAME%
net start | findstr /I "Remote" | findstr /I "Registry"	> %TEMP%\rr.txt

if errorlevel 1 (
	echo ■ 결과 : 양호, 원격 레지스트리를 사용하지 않음		>> %FILENAME%
) else (
	echo ■ 결과 : 취약, 원격 레지스트리를 사용하고 있음		>> %FILENAME%
)
echo.	>> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo.	>> %FILENAME%
type %TEMP%\rr.txt	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%