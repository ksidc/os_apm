@echo off

echo �������������������� W-69. ��å�� ���� �ý��� �α뼳�� >> %FILENAME%
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

echo �� ��� : ��ȣ, ���� ��å �ǰ� ���ؿ� ���� �ý��� �̺�Ʈ ���� ������ �Ǿ� ���� >> %FILENAME%
goto END

:Audit_NO
echo �� ��� : ���, ���� ��å �ǰ� ���ؿ� ���� �ý��� �̺�Ʈ ���� ������ ������ >> %FILENAME%

:END
echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%

type %TEMP%\win_69.txt | find /i "AuditAccountManage" >> %FILENAME%
type %TEMP%\win_69.txt | find /i "AuditAccountLogon" >> %FILENAME%
type %TEMP%\win_69.txt | find /i "AuditPrivilegeUse" >> %FILENAME%
type %TEMP%\win_69.txt | find /i "AuditDSAccess" >> %FILENAME%
type %TEMP%\win_69.txt | find /i "AuditLogonEvents" >> %FILENAME%
type %TEMP%\win_69.txt | find /i "AuditPolicyChange" >> %FILENAME%

echo. >> %FILENAME%

echo �� ���� >> %FILENAME%
echo AuditAccountManage = ���� ���� ���� : ���� >> %FILENAME%
echo AuditAccountLogon  = ���� �α׿� �̺�Ʈ ���� : ����/���� >> %FILENAME%
echo AuditPrivilegeUse  = ���� ��� ���� : ���� >> %FILENAME%
echo AuditDSAccess      = ���͸� ���� �׼��� ���� : ���� >> %FILENAME%
echo AuditLogonEvents   = �α׿� �̺�Ʈ ���� : ����/���� >> %FILENAME%
echo AuditPolicyChange  = ��å ���� ���� : ����/���� >> %FILENAME%

echo. >> %FILENAME%
echo ����: 1, ����: 2, ����/����: 3, �������: 0 >> %FILENAME%

echo. >> %FILENAME%
echo ** ���� :  CMD â auditpol ( ��� ���� ��å )�� �����Ͽ� �Ʒ� Ȯ��  >> %FILENAME%
echo auditpol /get /category:* ^| find "����� ���� ����"  : ����/����  >> %FILENAME%
echo auditpol /get /category:* ^| find "�ڰ� ���� ��ȿ�� �˻�"  : ����/����  >> %FILENAME%
echo auditpol /get /category:* ^| find "�߿��� ���� ���" :  ���� >> %FILENAME%
echo auditpol /get /category:* ^| find "�α׿�" : ����/���� >> %FILENAME%
echo auditpol /get /category:* ^| find "���͸� ���� �׼���"  : ����/����  >> %FILENAME%
echo auditpol /get /category:* ^| find "���� ��å ����" : ����/����  >> %FILENAME%


echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%