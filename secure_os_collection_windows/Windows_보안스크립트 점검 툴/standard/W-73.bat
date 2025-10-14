@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-73. 사용자가 프린터 드라이버를 설치할 수 없게 함 	>> %FILENAME%
echo.	>> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "AddPrinterDrivers" | Tools\awk.exe -F\ "{print $9}"		> nul
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "AddPrinterDrivers" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, “이동식 미디어 포맷 및 꺼내기 허용” 정책이 정의되어 있지 않으므로 사용자가 프린터 드라이버를 설치할 수 없음	>> %FILENAME%
	goto W-73_end
)

type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "AddPrinterDrivers" | findstr "4,1" > nul
if errorlevel 1 (
	echo ■ 결과 : 취약, 사용자가 프린터 드라이버를 설치할 수 있도록 설정되어 있음						>> %FILENAME%
) else (
	echo ■ 결과 : 양호, 사용자가 프린터 드라이버를 설치할 수 없도록 설정되어 있음					>> %FILENAME%
)

:W-73_end
echo.	>> %FILENAME%
echo ■ 상세 현황	>> %FILENAME%
echo.	>> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "AddPrinterDrivers" | Tools\awk.exe -F\ "{print $9}"		>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%