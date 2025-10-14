@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-81. 시작프로그램 목록 분석 	>> %FILENAME%
echo.	>> %FILENAME%

dir "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" 			>> %TEMP%\START_RUN.txt
echo.																>> %TEMP%\START_RUN.txt
echo 2012 버전에서는 시작 프로그램 목록 편집이 불가능함	>> %TEMP%\START_RUN.txt
echo [레지스트리 Run 목록]		>> %TEMP%\START_RUN.txt
reg query "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"							>> %TEMP%\START_RUN.txt
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"							>> %TEMP%\START_RUN.txt
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"						>> %TEMP%\START_RUN.txt
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"					>> %TEMP%\START_RUN.txt
type %TEMP%\START_RUN.txt | findstr /v "[ \Programs\Startup" | findstr /i ".lnk .bat .cmd .vbs .exe CurrentVersion\Run" > nul

if errorlevel 1 (
	echo ■ 결과 : 양호, 시작프로그램이 존재하지 않음	>> %FILENAME%
) else (
	echo ■ 결과 : 수동점검, 불필요한 시작프로그램 존재 여부 및 정기적인 시작프로그램 목록 점검 현황 파악 필요	>> %FILENAME%
	echo.	>> %FILENAME%
	echo ■ 상세 현황		>> %FILENAME%
	echo.	>> %FILENAME%
	type %TEMP%\START_RUN.txt				>> %FILENAME%
)
echo.						>> %FILENAME%
echo. 						>> %FILENAME%
echo.						>> %FILENAME%