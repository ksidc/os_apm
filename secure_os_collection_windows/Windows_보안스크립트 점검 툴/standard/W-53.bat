@echo off

echo �������������������� W-53. ���� �α׿� ��� >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "SeInteractiveLogonRight" >> %TEMP%\Local_logon_right.txt
type %Temp%\Local_logon_right.txt | findstr /i /v "*S-1-5-32-544 *S-1-5-17" | find /i "*S-1" > nul
if errorlevel 1 (
	echo �� ��� : ���, ���� �α׿� ��� ��å�� Administrators, IUSR_ �� �ٸ� ���� �Ǵ� �׷��� ������ >> %FILENAME%
) else (
	echo �� ��� : ��ȣ, ���� �α׿� ��� ��å�� Administrators, IUSR_ �� ������ >> %FILENAME%
)


echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
type %CONFIG%Security_Policy.txt | find /i "SeInteractiveLogonRight"  >> %FILENAME%

echo. >> %FILENAME%
echo ** ���� :  ��� ��� ���� *S-1-5-32-544,*S-1-5-32-568 �̸� ��ȣ >> %FILENAME%
echo �Ǵ� secpol.msc ������ ���� ��å - ����� ���� �Ҵ� - ���� �α׿� ��� Administrators, IIS_IUSRS Ȯ�� >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%