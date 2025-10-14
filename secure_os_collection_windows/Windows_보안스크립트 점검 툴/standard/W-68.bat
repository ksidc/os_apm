@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-68. 예약된 작업에 의심스러운 명령이 등록되어 있는지 점검	>> %FILENAME%
echo.	>> %FILENAME%
at | schtasks | findstr /I "ready running"	> nul
if errorlevel 1 (
	echo ■ 결과 : 양호, 예약된 작업이 존재하지 않음	>> %FILENAME%
) else (
	echo ■ 결과 : 수동 점검, 불필요한 작업 및 명령어 확인 필요 >> %FILENAME%
)

echo.	>> %FILENAME%
echo ■ 상세 현황	>> %FILENAME%
echo.	>> %FILENAME%
at | schtasks | findstr /I "ready running"	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%