@echo off

echo �������������������� W-05. �ص� ������ ��ȣȭ�� ����Ͽ� ��ȣ ���� ���� >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "ClearTextPassword" | find "0" > nul
if errorlevel 1 (
	echo �� ��� : ���, '�ص� ������ ��ȣȭ�� ����Ͽ� ��ȣ ����' ��å�� '���'���� �����Ǿ� ���� >> %FILENAME%
) else (
	echo �� ��� : ��ȣ, '�ص� ������ ��ȣȭ�� ����Ͽ� ��ȣ ����' ��å�� '��� �� ��'���� �����Ǿ� ���� >> %FILENAME%
)

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
type %CONFIG%Security_Policy.txt | find /i "ClearTextPassword" >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%