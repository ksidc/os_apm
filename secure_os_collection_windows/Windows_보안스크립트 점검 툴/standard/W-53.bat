@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-53. 로컬 로그온 허용 >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "SeInteractiveLogonRight" >> %TEMP%\Local_logon_right.txt
type %Temp%\Local_logon_right.txt | findstr /i /v "*S-1-5-32-544 *S-1-5-17" | find /i "*S-1" > nul
if errorlevel 1 (
	echo ■ 결과 : 취약, 로컬 로그온 허용 정책에 Administrators, IUSR_ 외 다른 계정 또는 그룹이 존재함 >> %FILENAME%
) else (
	echo ■ 결과 : 양호, 로컬 로그온 허용 정책에 Administrators, IUSR_ 만 존재함 >> %FILENAME%
)


echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
type %CONFIG%Security_Policy.txt | find /i "SeInteractiveLogonRight"  >> %FILENAME%

echo. >> %FILENAME%
echo ** 설명 :  상기 결과 값이 *S-1-5-32-544,*S-1-5-32-568 이면 양호 >> %FILENAME%
echo 또는 secpol.msc 실행후 로컬 정책 - 사용자 권한 할당 - 로컬 로그온 허용 Administrators, IIS_IUSRS 확인 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%