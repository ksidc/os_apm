@echo off

echo �������������������� W-07. ���� ���� �� ����� �׷� ���� >> %FILENAME%
echo. >> %FILENAME%

chcp 949
net share | find /v "���" | findstr . >> %CONFIG%NetShare_Info.txt

chcp 437

type %CONFIG%NetShare_List.txt | find /v /i "$" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, �⺻���� �� �Ϲݰ��� ������ �������� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	type %CONFIG%NetShare_Info.txt >> %FILENAME%	
) else (
	type %CONFIG%NetShare_List.txt | find /v /i "$" > %TEMP%\Net_share.txt
	FOR /F "tokens=2 delims= " %%i IN (%TEMP%\Net_share.txt) DO (
		echo ----------------------------------------------------------------------- >> %CONFIG%NetShare_cacls.txt
		cacls %%i >> %CONFIG%NetShare_cacls.txt
		cacls %%i | find /i "everyone" > nul
		if errorlevel 1 (
			echo - Everyone ��� ������ �������� ���� > nul
		) else (
			echo ----------------------------------------------------------------------- >> %TEMP%\Net_share_every.txt
			cacls %%i  >> %TEMP%\Net_share_every.txt
		)
	)
	if exist %TEMP%\Net_share_every.txt (
		echo �� ��� : ���, �Ϲݰ��� ������ Everyone ��� ������ �����Ǿ� ���� >> %FILENAME%
		echo. >> %FILENAME%
		echo �� �� ��Ȳ >> %FILENAME%
		echo. >> %FILENAME%
		type %TEMP%\Net_share_every.txt >> %FILENAME%
	) else (
		echo �� ��� : ��ȣ, �Ϲݰ��� ������ Everyone ��� ������ �������� ���� >> %FILENAME%
		echo. >> %FILENAME%
		echo �� �� ��Ȳ >> %FILENAME%
		echo. >> %FILENAME%
		echo - Everyone ��� ������ �������� ���� >> %FILENAME%
	)
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo �� �� �������� ���� ������ %CONFIG%NetShare_cacls.txt ���� ���� >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%