@echo off

echo �������������������� W-36. ��� ���α׷� ��ġ >> %FILENAME%
echo. >> %FILENAME%

if exist %TEMP%\anti-virus.txt (
	echo �� ��� : ��ȣ, ��� ���α׷��� ��ġ�Ǿ� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	type %TEMP%\anti-virus.txt >> %FILENAME%
) else (
	echo �� ��� : ���, ��� ���α׷��� �������� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	echo - �Ϻ� ����� ���� ���θ� �����Ͽ����Ƿ� %CONFIG%Net_Start.txt ���� ���� �Ǵ� ����� ���Ǹ� ���� ��� ��ġ Ȯ�� >> %FILENAME%
)

echo. >> %FILENAME%
echo �� W-33 ���� ��� ���� >> %FILENAME%
	
echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%