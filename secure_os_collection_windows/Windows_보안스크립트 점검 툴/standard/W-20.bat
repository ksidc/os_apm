@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-20. IIS 데이터 파일 ACL 적용 >> %FILENAME%
echo. >> %FILENAME%

FOR /f "delims=" %%j IN (%TEMP%\IIS_root_path.txt) DO (
	echo -----------------------------------------------------------------------  >> %TEMP%\Data_file_acl.txt
	echo 홈 디렉토리 경로 : %%j >> %TEMP%\Data_file_acl.txt
	echo. >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.exe /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.dll /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.cmd /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.pl /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.asp /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.inc /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.shtm /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.shtml /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.txt /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.gif /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.jpg /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.html /t 2> nul >> %TEMP%\Data_file_acl.txt
)

type %TEMP%\Data_file_acl.txt | find /i "Everyone:" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, IIS 홈 디렉토리 내에 Everyone 권한이 설정된 파일이 존재하지 않음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	echo - Everyone 권한이 설정된 파일이 존재하지 않음 >> %FILENAME%
) else (
	echo ■ 결과 : 취약, IIS 홈 디렉토리 내에 Everyone 권한이 설정된 파일이 존재함 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	type %TEMP%\Data_file_acl.txt | find /i "Everyone" >> %FILENAME%
)

echo. >> %FILENAME%
echo ※ IIS 홈 디렉토리 내 파일들의 권한 설정 상세 현황은 %TEMP%\Data_file_acl.txt 파일 참고 >> %FILENAME%
echo    exe, dll, cmd, pl, asp, inc, shtm, shtml, txt, gif, jpg, html 확장자를 대상으로 점검을 수행함 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%