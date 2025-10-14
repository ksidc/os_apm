@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-69. 정책에 따른 시스템 로깅설정 >> %FILENAME%
echo. >> %FILENAME%
type %CONFIG%Security_Policy.txt | find /i "Audit" | findstr /v /i "SeAudit \\" > %TEMP%\win_69.txt

type %TEMP%\win_69.txt | find /i "AuditAccountManage" | findstr "2 3" > nul
if errorlevel 1 goto Audit_NO
type %TEMP%\win_69.txt | find /i "AuditAccountLogon" | find "3" > nul
if errorlevel 1 goto Audit_NO
type %TEMP%\win_69.txt | find /i "AuditPrivilegeUse" | findstr "2 3" > nul
if errorlevel 1 goto Audit_NO
type %TEMP%\win_69.txt | find /i "AuditDSAccess" | findstr "2 3" > nul
if errorlevel 1 goto Audit_NO
type %TEMP%\win_69.txt | find /i "AuditLogonEvents" | find "3" > nul
if errorlevel 1 goto Audit_NO
type %TEMP%\win_69.txt | find /i "AuditPolicyChange" | find "3" > nul
if errorlevel 1 goto Audit_NO

echo ■ 결과 : 양호, 감사 정책 권고 기준에 따라 시스템 이벤트 감사 설정이 되어 있음 >> %FILENAME%
goto END

:Audit_NO
echo ■ 결과 : 취약, 감사 정책 권고 기준에 따른 시스템 이벤트 감사 설정이 미흡함 >> %FILENAME%

:END
echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%

type %TEMP%\win_69.txt | find /i "AuditAccountManage" >> %FILENAME%
type %TEMP%\win_69.txt | find /i "AuditAccountLogon" >> %FILENAME%
type %TEMP%\win_69.txt | find /i "AuditPrivilegeUse" >> %FILENAME%
type %TEMP%\win_69.txt | find /i "AuditDSAccess" >> %FILENAME%
type %TEMP%\win_69.txt | find /i "AuditLogonEvents" >> %FILENAME%
type %TEMP%\win_69.txt | find /i "AuditPolicyChange" >> %FILENAME%

echo. >> %FILENAME%

echo ※ 참고 >> %FILENAME%
echo AuditAccountManage = 계정 관리 감사 : 실패 >> %FILENAME%
echo AuditAccountLogon  = 계정 로그온 이벤트 감사 : 성공/실패 >> %FILENAME%
echo AuditPrivilegeUse  = 권한 사용 감사 : 실패 >> %FILENAME%
echo AuditDSAccess      = 디렉터리 서비스 액세스 감사 : 실패 >> %FILENAME%
echo AuditLogonEvents   = 로그온 이벤트 감사 : 성공/실패 >> %FILENAME%
echo AuditPolicyChange  = 정책 변경 감사 : 성공/실패 >> %FILENAME%

echo. >> %FILENAME%
echo 성공: 1, 실패: 2, 성공/실패: 3, 감사안함: 0 >> %FILENAME%

echo. >> %FILENAME%
echo ** 설명 :  CMD 창 auditpol ( 고급 감사 정책 )에 설정하여 아래 확인  >> %FILENAME%
echo auditpol /get /category:* ^| find "사용자 계정 관리"  : 성공/실패  >> %FILENAME%
echo auditpol /get /category:* ^| find "자격 증명 유효성 검사"  : 성공/실패  >> %FILENAME%
echo auditpol /get /category:* ^| find "중요한 권한 사용" :  실패 >> %FILENAME%
echo auditpol /get /category:* ^| find "로그온" : 성공/실패 >> %FILENAME%
echo auditpol /get /category:* ^| find "디렉터리 서비스 액세스"  : 성공/실패  >> %FILENAME%
echo auditpol /get /category:* ^| find "감사 정책 변경" : 성공/실패  >> %FILENAME%


echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%