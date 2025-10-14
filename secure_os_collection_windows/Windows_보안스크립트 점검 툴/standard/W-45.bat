@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-45. 디스크볼륨 암호화 설정 >> %FILENAME%
echo. >> %FILENAME%

wmic logicaldisk get caption,description,filesystem > %TEMP%\Disk_volume.txt
type %TEMP%\Disk_volume.txt | findstr /i "fat fat32" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, 암호화 가능한 NTFS 파일 시스템을 사용하고 있음 >> %FILENAME%
) else (
	echo ■ 결과 : 취약, 암호화 불가능한 파일 시스템을 사용하고 있음 >> %FILENAME%
)

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Disk_volume.txt >> %FILENAME%

echo. >> %FILENAME%
echo ※ 서버가 물리적으로 보호된 장소(IDC 내, PC 시건장치 등)에 위치하거나, >> %FILENAME%
echo    하드디스크 교체 시 기존 하드디스크의 디가우징 또는 천공 등 폐기 관련 규정을 수행하는 경우 예외 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%