@echo off

echo �������������������� W-41. ���� ���縦 �α��� �� ���� ��� ��� �ý��� ���� >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "CrashOnAuditFail" | Tools\awk.exe -F\ "{print $6}" >> %TEMP%\Audit_fail.txt
FOR /f "tokens=2 delims=," %%t IN (%TEMP%\Audit_fail.txt) DO set AUDIT_F=%%t

if %AUDIT_F% EQU 0 echo �� ��� : ��ȣ, '���� ���縦 �α��� �� ���� ��� ��� �ý��� ����' ��å�� '��� �� ��'���� �����Ǿ� ���� >> %FILENAME%
if %AUDIT_F% EQU 1 echo �� ��� : ���, '���� ���縦 �α��� �� ���� ��� ��� �ý��� ����' ��å�� '���'���� �����Ǿ� ���� >> %FILENAME%

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Audit_fail.txt >> %FILENAME%

echo. >> %FILENAME%
echo �� ��� �� ��: 4,0 / ���: 4,1 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%