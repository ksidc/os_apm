@echo off

echo �������������������� W-42. SAM ������ ������ �͸� ���� ��� �� �� >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "RestrictAnonymous=" | Tools\awk.exe -F\ "{print $6}" >> %TEMP%\Restrict_anonymous.txt
type %CONFIG%Security_Policy.txt | find /i "RestrictAnonymousSAM" | Tools\awk.exe -F\ "{print $6}" >> %TEMP%\Restrict_anonymous_sam.txt
FOR /f "tokens=2 delims=," %%v IN (%TEMP%\Restrict_anonymous.txt) DO set R_AM=%%v
FOR /f "tokens=2 delims=," %%w IN (%TEMP%\Restrict_anonymous_sam.txt) DO set R_SAM=%%w

if %R_AM% EQU 1 (
	if %R_SAM% EQU 1 (
		echo �� ��� : ��ȣ, 'SAM ������ ������ �͸� ���� ��� �� ��' �� 'SAM ������ �͸� ���� ��� �� ��' ��å�� '���'���� �����Ǿ� ���� >> %FILENAME%
	)
	if %R_SAM% EQU 0 (
		echo �� ��� : ���, 'SAM ������ �͸� ���� ��� �� ��' ��å�� '��� �� ��'���� �����Ǿ� ���� >> %FILENAME%
	)	
)
if %R_AM% EQU 0 (
	if %R_SAM% EQU 1 (
		echo �� ��� : ���, 'SAM ������ ������ �͸� ���� ��� �� ��' ��å�� '���'���� �����Ǿ� ���� >> %FILENAME%
	)
	if %R_SAM% EQU 0 (
		echo �� ��� : ���, 'SAM ������ ������ �͸� ���� ��� �� ��' �� 'SAM ������ �͸� ���� ��� �� ��' ��å�� '��� �� ��'���� �����Ǿ� ���� >> %FILENAME%
	)	
)

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
echo [SAM ������ ������ �͸� ���� ��� �� ��] >> %FILENAME%
type %TEMP%\Restrict_anonymous.txt >> %FILENAME%
echo. >> %FILENAME%
echo [SAM ������ �͸� ���� ��� �� ��] >> %FILENAME%
type %TEMP%\Restrict_anonymous_sam.txt >> %FILENAME%

echo. >> %FILENAME%
echo �� ��� �� ��: 4,0 / ���: 4,1 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%