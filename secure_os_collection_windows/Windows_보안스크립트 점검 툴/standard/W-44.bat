@echo off

echo �������������������� W-44. �̵��� �̵�� ���� �� ������ ��� >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "AllocateDASD" >> %TEMP%\Allocate_dasd.txt
echo �� ��� : ��������, '�̵��� �̵�� ���� �� ������ ���' ��å ���� �� Ȯ�� >> %FILENAME%
echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
type %TEMP%\Allocate_dasd.txt >> %FILENAME%

echo. >> %FILENAME%
echo �� 1,"0": Administrators / 1,"1": Administrators �� Power Users / 1,"2": Administrators �� Interactive Users >> %FILENAME%
echo ����, ����� ���� ��� �ش� ��å�� ���ǵ��� �ʾ� default�� Administrators�� ���� >> %FILENAME%

echo. >> %FILENAME%
echo ** ���� :  ����� ������ ��ȣ  >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%