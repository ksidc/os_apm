@echo off

echo �������������������� W-78. ���� ä�� ������ ������ ��ȣȭ �Ǵ� ����	>> %FILENAME%
echo. 	>> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "RequireSignOrSeal SealSecureChannel SignSecureChannel" | findstr "4,0" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, ���� ä�� ������ ������ ��ȣȭ �Ǵ� ���� ���� ��å ��� "���" �����Ǿ� ����			>> %FILENAME%
) else (
	echo �� ��� : ���, ���� ä�� ������ ������ ��ȣȭ �Ǵ� ���� ��å ������ ������			>> %FILENAME%
)

echo. 	>> %FILENAME%
echo �� �� ��Ȳ	>> %FILENAME%
echo. 	>> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "RequireSignOrSeal SealSecureChannel SignSecureChannel" | Tools\awk.exe -F\ "{print $7}"	>> %FILENAME%
echo. 	>> %FILENAME%
echo. 	>> %FILENAME%
echo. 	>> %FILENAME%