@echo off

echo �������������������� W-33. ��� ���α׷� ������Ʈ	>> %FILENAME%
echo.	>> %FILENAME%

type %CONFIG%Net_Start.txt | findstr /i "AhnLab V3" > nul
if errorlevel 1 (
	type %CONFIG%Net_Start.txt | findstr /i "ESTsoft ALYac" > nul
	if errorlevel 1 (
		type %CONFIG%Net_Start.txt | findstr /i "Hauri ViRobot" > nul
		if errorlevel 1 (
			type %CONFIG%Net_Start.txt | findstr /i "Trend.*Micro Deep.*Security" > nul
			if errorlevel 1 (
				type %CONFIG%Net_Start.txt | findstr /i "mcafee norton virus anti.*" > nul
				if errorlevel 1 (
					echo �� ��� : ���, ��� ���α׷��� �������� ���� >> %FILENAME%
					echo. >> %FILENAME%
					echo �� �� ��Ȳ >> %FILENAME%
					echo. >> %FILENAME%
					echo - �Ϻ� ����� ���� ���θ� �����Ͽ����Ƿ� %CONFIG%Net_Start.txt ���� ���� �Ǵ� ����� ���Ǹ� ���� ��� ��ġ Ȯ�� �ʿ� >> %FILENAME%
					goto W-33_end
				) else (
					echo �� ��� : ��������, ��� ���α׷��� ��ġ �� �ֽ� ������Ʈ ���� Ȯ�� �ʿ� >> %FILENAME%
					echo. >> %FILENAME%
					echo �� �� ��Ȳ >> %FILENAME%
					echo. >> %FILENAME%
					type %CONFIG%Net_Start.txt | findstr /i "mcafee norton virus anti.*" >> %TEMP%\anti-virus.txt
					type %TEMP%\anti-virus.txt >> %FILENAME%
					goto W-33_end
				)
			) else (
				reg query "HKLM\SOFTWARE\TrendMicro" > nul
				if errorlevel 1 (
					type %CONFIG%Net_Start.txt | findstr /i "Trend.*Micro Deep.*Security" >> %TEMP%\anti-virus.txt
				) else (
					type %CONFIG%Net_Start.txt | findstr /i "Trend.*Micro Deep.*Security" >> %TEMP%\anti-virus.txt
					reg query "HKLM\SOFTWARE\TrendMicro" /s > %TEMP%\anti-virus_reg.txt
				)
			)
		) else (
			reg query "HKLM\SOFTWARE\Hauri\Virobot" > nul
			if errorlevel 1 (
				type %CONFIG%Net_Start.txt | findstr /i "Hauri ViRobot" >> %TEMP%\anti-virus.txt
			) else (
				type %CONFIG%Net_Start.txt | findstr /i "Hauri ViRobot" >> %TEMP%\anti-virus.txt
				reg query "HKLM\SOFTWARE\Hauri\Virobot" /s > %TEMP%\anti-virus_reg.txt
			)
		)
	) else (
		reg query "HKLM\SOFTWARE\ESTsoft\ALYac" > nul
		if errorlevel 1 (
			type %CONFIG%Net_Start.txt | findstr /i "ESTsoft ALYac" >> %TEMP%\anti-virus.txt
		) else (
			type %CONFIG%Net_Start.txt | findstr /i "ESTsoft ALYac" >> %TEMP%\anti-virus.txt
			reg query "HKLM\SOFTWARE\ESTsoft\ALYac" /s > %TEMP%\anti-virus_reg.txt
		)
	)
) else (
	reg query "HKLM\SOFTWARE\AhnLab" > nul
	if errorlevel 1 (
		type %CONFIG%Net_Start.txt | findstr /i "AhnLab V3" >> %TEMP%\anti-virus.txt
	) else (
		type %CONFIG%Net_Start.txt | findstr /i "AhnLab V3" >> %TEMP%\anti-virus.txt
		reg query "HKLM\SOFTWARE\AhnLab" /s > %TEMP%\anti-virus_reg.txt
	)
)

echo �� ��� : ��������, ��� ���α׷��� ��ġ �� ������Ʈ ���� Ȯ�� �ʿ� >> %FILENAME%
echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
echo [anti-virus.txt] >> %FILENAME%
type %TEMP%\anti-virus.txt >> %FILENAME%
echo. >> %FILENAME%
echo [anti-virus_reg.txt] >> %FILENAME%
if exist %TEMP%\anti-virus_reg.txt (
	type %TEMP%\anti-virus_reg.txt >> %FILENAME%
) else (
	echo - ��� ���α׷� ���� ������Ʈ���� �������� ���� >> %FILENAME%
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo �� %CONFIG%Net_Start.txt �Ǵ� %TEMP%\anti-virus.txt �� %TEMP%\anti-virus_reg.txt ���� ���� ���� >> %FILENAME%

:W-33_end
echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%