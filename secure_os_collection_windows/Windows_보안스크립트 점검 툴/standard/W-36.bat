@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-36. 백신 프로그램 설치 >> %FILENAME%
echo. >> %FILENAME%

if exist %TEMP%\anti-virus.txt (
	echo ■ 결과 : 양호, 백신 프로그램이 설치되어 있음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	type %TEMP%\anti-virus.txt >> %FILENAME%
) else (
	echo ■ 결과 : 취약, 백신 프로그램이 존재하지 않음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	echo - 일부 백신의 존재 여부만 점검하였으므로 %CONFIG%Net_Start.txt 파일 참고 또는 담당자 질의를 통해 백신 설치 확인 >> %FILENAME%
)

echo. >> %FILENAME%
echo ※ W-33 점검 결과 참고 >> %FILENAME%
	
echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%