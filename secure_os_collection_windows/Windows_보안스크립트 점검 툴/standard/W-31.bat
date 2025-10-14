@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-31. 최신 서비스팩 적용 >> %FILENAME%
echo. >> %FILENAME%

echo ■ 결과 : 양호, Windows Server 20012 이상 버전에서는 서비스팩이 존재하지 않음 >> %FILENAME%
echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
echo [Windows 버전] >> %FILENAME%
type %CONFIG%System_Info.txt | find /i "OS" | findstr /i "Name Version" | findstr /i /v "Host BIOS" >> %FILENAME%

echo. >> %FILENAME%
echo ※ Windows 2008 이하 버전의 경우, %CONFIG%System_Info.txt 파일을 참고하여 서비스팩 확인 필요 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%