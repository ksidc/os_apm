@echo off

echo �������������������� W-77. LAN Manager ���� ���� >> %FILENAME%
echo. >> %FILENAME%

type Config\%COMPUTERNAME%_Security_Policy.txt | find /i "LmCompatibilityLevel" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, LAN Manager ���� ������ ���ǵ��� �ʾ� �⺻���� "NTLMv2 ���丸 ����"���� ����� >> %FILENAME%
	echo. 	>> %FILENAME%
	echo �� �� ��Ȳ			>> %FILENAME%
	echo. 	>> %FILENAME%
	echo - LmCompatibilityLevel ������Ʈ�� ���� �������� ���� 	>> %FILENAME%
	goto W-77_end
)
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "LmCompatibilityLevel" | Tools\awk.exe -F\ "{print $6}" > %TEMP%\NTLMver.txt
for /F "tokens=2 delims=," %%a in (%TEMP%\NTLMver.txt) do set COM_LV=%%a
if %COM_LV% GEQ 3 (
	echo �� ��� : ��ȣ, LAN Manager ���� ������ NTLMv2 ���丸 �������� �����Ǿ� ����	>> %FILENAME%
) else (
	echo �� ��� : ���, LAN Manager ���� ������ NT �Ǵ� NTLM ���丸 �������� �����Ǿ� ����	>> %FILENAME%
)
echo. 	>> %FILENAME%
echo �� �� ��Ȳ			>> %FILENAME%
echo. 	>> %FILENAME%
type %TEMP%\NTLMver.txt	>> %FILENAME%
echo. 	>> %FILENAME%
echo �� ���� >> %FILENAME%
echo LmCompatibilityLevel 4,0 : LM �� NTLM ���� ������ >> %FILENAME%
echo LmCompatibilityLevel 4,1 : LM �� NTLM ������ - ����Ǹ� NTLMv2 ���� ���� ��� >> %FILENAME%
echo LmCompatibilityLevel 4,2 : NTLM ���丸 ������	>> %FILENAME%
echo LmCompatibilityLevel 4,3 : NTLMv2 ���丸 ������	>> %FILENAME%
echo LmCompatibilityLevel 4,4 : NTLMv2 ���丸 ������ �� LM �ź�	>> %FILENAME%
echo LmCompatibilityLevel 4,5 : NTLMv2 ���丸 �����ϴ�. LM �� NTLM�� �ź��մϴ�. >> %FILENAME%

:W-77_end
echo. 	>> %FILENAME%
echo. 	>> %FILENAME%
echo. 	>> %FILENAME%