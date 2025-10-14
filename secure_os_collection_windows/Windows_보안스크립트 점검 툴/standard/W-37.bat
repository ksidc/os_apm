@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-37. SAM 파일 접근 통제 설정 >> %FILENAME%
echo. >> %FILENAME%

cacls %systemroot%\system32\config\SAM >> %TEMP%\SAM_file_acl.txt

type %TEMP%\SAM_file_acl.txt | find /i /v "NT AUTHORITY\SYSTEM" | find /i /v "BUILTIN\Administrators" | find "\" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, SAM 파일 접근권한에 Administrators, System 그룹만 존재함 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	type %TEMP%\SAM_file_acl.txt >> %FILENAME%	
) else (
	echo ■ 결과 : 수동점검, SAM 파일 접근권한에 Administrator, System 그룹 이외 다른 계정 존재 여부 확인 필요 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	type %TEMP%\SAM_file_acl.txt >> %FILENAME%
	echo. >> %FILENAME%
	echo [관리자 그룹 계정 목록] >> %FILENAME%
	type %TEMP%\Admin_account.txt >> %FILENAME%
)

echo. >> %FILENAME%
echo ※ 관리자 그룹 상세 현황은 W-06 점검 항목을 참고 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%