@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-33. 백신 프로그램 업데이트	>> %FILENAME%
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
					echo ■ 결과 : 취약, 백신 프로그램이 존재하지 않음 >> %FILENAME%
					echo. >> %FILENAME%
					echo ■ 상세 현황 >> %FILENAME%
					echo. >> %FILENAME%
					echo - 일부 백신의 존재 여부만 점검하였으므로 %CONFIG%Net_Start.txt 파일 참고 또는 담당자 질의를 통해 백신 설치 확인 필요 >> %FILENAME%
					goto W-33_end
				) else (
					echo ■ 결과 : 수동점검, 백신 프로그램의 설치 및 최신 업데이트 적용 확인 필요 >> %FILENAME%
					echo. >> %FILENAME%
					echo ■ 상세 현황 >> %FILENAME%
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

echo ■ 결과 : 수동점검, 백신 프로그램의 설치 및 업데이트 여부 확인 필요 >> %FILENAME%
echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
echo [anti-virus.txt] >> %FILENAME%
type %TEMP%\anti-virus.txt >> %FILENAME%
echo. >> %FILENAME%
echo [anti-virus_reg.txt] >> %FILENAME%
if exist %TEMP%\anti-virus_reg.txt (
	type %TEMP%\anti-virus_reg.txt >> %FILENAME%
) else (
	echo - 백신 프로그램 관련 레지스트리가 존재하지 않음 >> %FILENAME%
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo ※ %CONFIG%Net_Start.txt 또는 %TEMP%\anti-virus.txt 및 %TEMP%\anti-virus_reg.txt 파일 내용 참고 >> %FILENAME%

:W-33_end
echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%