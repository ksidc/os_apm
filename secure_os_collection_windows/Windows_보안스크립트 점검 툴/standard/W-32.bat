@echo off

echo �������������������� W-32. �ֽ� HOT FIX ���� >> %FILENAME%
echo. >> %FILENAME%

wmic qfe get HotFixID,InstalledOn,Description >> %CONFIG%HotFix.txt 2>&1

echo �� ��� : ��������, Hot Fix �̷� Ȯ�� �ʿ� >> %FILENAME%
echo. >> %FILENAME%

echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
type %CONFIG%HotFix.txt >> %FILENAME%

echo. >> %FILENAME%
echo �� Hot Fix ������Ʈ ���ڴ� ���� ����Ʈ�� ���� https://www.catalog.update.microsoft.com/Home.aspx >> %FILENAME%
echo    ���� ��� �� Hot Fix �� ������ %CONFIG%HotFix.txt �Ǵ� %CONFIG%System_Info.txt ���� ���� >> %FILENAME%

echo. >> %FILENAME%
echo ** ���� :  �ֽ� ������Ʈ ���� Ȯ��  >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%