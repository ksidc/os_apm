@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-07. 공유 권한 및 사용자 그룹 설정 >> %FILENAME%
echo. >> %FILENAME%

chcp 949
net share | find /v "명령" | findstr . >> %CONFIG%NetShare_Info.txt

chcp 437

type %CONFIG%NetShare_List.txt | find /v /i "$" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, 기본공유 외 일반공유 폴더가 존재하지 않음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	type %CONFIG%NetShare_Info.txt >> %FILENAME%	
) else (
	type %CONFIG%NetShare_List.txt | find /v /i "$" > %TEMP%\Net_share.txt
	FOR /F "tokens=2 delims= " %%i IN (%TEMP%\Net_share.txt) DO (
		echo ----------------------------------------------------------------------- >> %CONFIG%NetShare_cacls.txt
		cacls %%i >> %CONFIG%NetShare_cacls.txt
		cacls %%i | find /i "everyone" > nul
		if errorlevel 1 (
			echo - Everyone 사용 권한이 설정되지 않음 > nul
		) else (
			echo ----------------------------------------------------------------------- >> %TEMP%\Net_share_every.txt
			cacls %%i  >> %TEMP%\Net_share_every.txt
		)
	)
	if exist %TEMP%\Net_share_every.txt (
		echo ■ 결과 : 취약, 일반공유 폴더에 Everyone 사용 권한이 설정되어 있음 >> %FILENAME%
		echo. >> %FILENAME%
		echo ■ 상세 현황 >> %FILENAME%
		echo. >> %FILENAME%
		type %TEMP%\Net_share_every.txt >> %FILENAME%
	) else (
		echo ■ 결과 : 양호, 일반공유 폴더에 Everyone 사용 권한이 설정되지 않음 >> %FILENAME%
		echo. >> %FILENAME%
		echo ■ 상세 현황 >> %FILENAME%
		echo. >> %FILENAME%
		echo - Everyone 사용 권한이 설정되지 않음 >> %FILENAME%
	)
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo ※ 상세 공유폴더 접근 권한은 %CONFIG%NetShare_cacls.txt 파일 참고 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%