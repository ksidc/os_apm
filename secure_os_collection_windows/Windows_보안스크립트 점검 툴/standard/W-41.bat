@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-41. 보안 감사를 로그할 수 없는 경우 즉시 시스템 종료 >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "CrashOnAuditFail" | Tools\awk.exe -F\ "{print $6}" >> %TEMP%\Audit_fail.txt
FOR /f "tokens=2 delims=," %%t IN (%TEMP%\Audit_fail.txt) DO set AUDIT_F=%%t

if %AUDIT_F% EQU 0 echo ■ 결과 : 양호, '보안 감사를 로그할 수 없는 경우 즉시 시스템 종료' 정책이 '사용 안 함'으로 설정되어 있음 >> %FILENAME%
if %AUDIT_F% EQU 1 echo ■ 결과 : 취약, '보안 감사를 로그할 수 없는 경우 즉시 시스템 종료' 정책이 '사용'으로 설정되어 있음 >> %FILENAME%

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Audit_fail.txt >> %FILENAME%

echo. >> %FILENAME%
echo ※ 사용 안 함: 4,0 / 사용: 4,1 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%