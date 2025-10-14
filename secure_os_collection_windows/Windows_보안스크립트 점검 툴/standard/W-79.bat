@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-79. 파일 및 디렉터리 보호 	>> %FILENAME%
echo. 	>> %FILENAME%
wmic logicaldisk get caption,description,filesystem > %TEMP%\FILE_TEMP.TXT
type %TEMP%\FILE_TEMP.TXT | findstr /i "fat fat32" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, NTFS 파일 시스템만 사용하고 있음					>> %FILENAME%
) else (
	echo ■ 결과 : 취약, FAT 파일 시스템을 사용하고 있음				>> %FILENAME%
)

echo. 	>> %FILENAME%
echo ■ 상세 현황				>> %FILENAME%
echo. 	>> %FILENAME%
type %TEMP%\FILE_TEMP.txt		>> %FILENAME%								
echo. 	>> %FILENAME%
echo. 	>> %FILENAME%
echo. 	>> %FILENAME%