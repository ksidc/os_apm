@echo off

echo �������������������� W-81. �������α׷� ��� �м� 	>> %FILENAME%
echo.	>> %FILENAME%

dir "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" 			>> %TEMP%\START_RUN.txt
echo.																>> %TEMP%\START_RUN.txt
echo 2012 ���������� ���� ���α׷� ��� ������ �Ұ�����	>> %TEMP%\START_RUN.txt
echo [������Ʈ�� Run ���]		>> %TEMP%\START_RUN.txt
reg query "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"							>> %TEMP%\START_RUN.txt
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"							>> %TEMP%\START_RUN.txt
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"						>> %TEMP%\START_RUN.txt
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"					>> %TEMP%\START_RUN.txt
type %TEMP%\START_RUN.txt | findstr /v "[ \Programs\Startup" | findstr /i ".lnk .bat .cmd .vbs .exe CurrentVersion\Run" > nul

if errorlevel 1 (
	echo �� ��� : ��ȣ, �������α׷��� �������� ����	>> %FILENAME%
) else (
	echo �� ��� : ��������, ���ʿ��� �������α׷� ���� ���� �� �������� �������α׷� ��� ���� ��Ȳ �ľ� �ʿ�	>> %FILENAME%
	echo.	>> %FILENAME%
	echo �� �� ��Ȳ		>> %FILENAME%
	echo.	>> %FILENAME%
	type %TEMP%\START_RUN.txt				>> %FILENAME%
)
echo.						>> %FILENAME%
echo. 						>> %FILENAME%
echo.						>> %FILENAME%