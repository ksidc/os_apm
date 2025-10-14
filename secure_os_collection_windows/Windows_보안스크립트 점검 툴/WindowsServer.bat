@echo off
chcp 437
setlocal

cd "%~dp0"

::----------- 스크립트 버전
::v1.3 2023.01.30.


::----------- 점검 준비
if exist Config (
	rmdir /S /Q Config
) 
mkdir Config

if exist Temp (
	rmdir /S /Q Temp
) 
mkdir Temp

if exist %COMPUTERNAME%.txt ( del %COMPUTERNAME%.txt )

set TEMP=Temp
set TOOLS=Tools
set CONFIG=Config\%COMPUTERNAME%_
set FILENAME=%COMPUTERNAME%.txt

::----------- 시스템 정보
systeminfo >> %CONFIG%System_Info.txt
tasklist >> %CONFIG%Task_List.txt
ipconfig /all >> %CONFIG%Ipconfig.txt
netstat -an >> %CONFIG%Netstat.txt
Tools\pslist >> %CONFIG%PS_List.txt
wmic share get name,path >> %TEMP%\Net_share_path.txt
type %TEMP%\Net_share_path.txt | find /v /i "Path" >> %CONFIG%NetShare_List.txt
net start >> %CONFIG%Net_Start.txt
secedit /export /cfg %CONFIG%Security_Policy.txt > nul

:: Windows 버전 확인
ver >> %CONFIG%Win_Ver.txt
FOR /f "tokens=2 delims=[" %%i IN (%CONFIG%Win_Ver.txt) DO set WIN=%%i
set WINVER=%WIN:~8,3%

:: IIS 구동 확인
type %CONFIG%Net_Start.txt | find /i "World Wide Web Publishing" > nul
if errorlevel 1 (
	set IIS_RUN=0
) else (
	set IIS_RUN=1
)

:: FTP 구동 확인
type %CONFIG%Net_Start.txt | find /i "ftp" > nul
if errorlevel 1 (
	set FTP_RUN=0
) else (
	type %CONFIG%Net_Start.txt | find /i "Microsoft FTP" > nul
	if errorlevel 1 (
		set FTP_RUN=2
		echo 윈도우 기본 FTP 이외 타 FTP 서비스가 활성화되어 있음 > nul
	) else (
		set FTP_RUN=1
	)
)
:: FTP 기본정보 확인
if %FTP_RUN% EQU 1 (
	%systemroot%\System32\inetsrv\appcmd list site | find /i "ftp" >> %CONFIG%FTP_SiteList.txt
	FOR /f "tokens=1 delims=(" %%a IN (%CONFIG%FTP_SiteList.txt) DO (
		FOR /f "tokens=2-11 delims= " %%b in ("%%a") do (
			echo %%b %%c %%d %%e %%f %%g %%h %%i %%j %%k >> %TEMP%\FTP_site_name.txt
		)
	)
	:: FTP 사이트 경로 확인
	FOR /f "delims=" %%r IN (%TEMP%\FTP_site_name.txt) DO (
		%systemroot%\system32\inetsrv\appcmd list site %%r /config | find /i "PhysicalPath" >> %TEMP%\FTP_root.txt
	)
	FOR /f "delims=" %%u IN (%TEMP%\FTP_site_name.txt) DO (
		%systemroot%\system32\inetsrv\appcmd list site %%u /config | findstr /i "name protocol physicalpath"	>> %TEMP%\FTP_homedir.txt
	)	
	FOR /f "tokens=3 delims==" %%s IN (%TEMP%\FTP_root.txt) DO (
		FOR /f "tokens=1 delims=/" %%t IN ("%%s") DO (
			echo %%t >> %TEMP%\FTP_root_path.txt
			call cacls %%t >> %TEMP%\FTP_path_acl.txt
		)
	)
)

:: Local group 계정 목록
::net localgroup | find /i /v "Administrators" | findstr /v "Comment Members completed" | findstr /v /i "Alias -----" | findstr . 

::----------- 점검 시작

echo %date% %time:~0,5% > %FILENAME%
echo. >> %FILENAME%

set end=1

call standard\W-01.bat
echo W-01 end %end%/82..

call standard\W-02.bat
set /a end+=1
echo W-02 end %end%/82..

call standard\W-03.bat
set /a end+=1
echo W-03 end %end%/82.. 

call standard\W-04.bat
set /a end+=1
echo W-04 end %end%/82.. 

call standard\W-05.bat
set /a end+=1
echo W-05 end %end%/82.. 

call standard\W-06.bat
set /a end+=1
echo W-06 end %end%/82.. 

call standard\W-46.bat
set /a end+=1
echo W-46 end %end%/82.. 

call standard\W-47.bat
set /a end+=1
echo W-47 end %end%/82.. 

call standard\W-48.bat
set /a end+=1
echo W-48 end %end%/82.. 

call standard\W-49.bat
set /a end+=1
echo W-49 end %end%/82.. 

call standard\W-50.bat
set /a end+=1
echo W-50 end %end%/82.. 

call standard\W-51.bat
set /a end+=1
echo W-51 end %end%/82.. 

call standard\W-52.bat
set /a end+=1
echo W-52 end %end%/82.. 

call standard\W-53.bat
set /a end+=1
echo W-53 end %end%/82.. 

call standard\W-54.bat
set /a end+=1
echo W-54 end %end%/82.. 

call standard\W-55.bat
set /a end+=1
echo W-55 end %end%/82.. 

call standard\W-56.bat
set /a end+=1
echo W-56 end %end%/82.. 

call standard\W-57.bat
set /a end+=1
echo W-57 end %end%/82.. 

call standard\W-07.bat
set /a end+=1
echo W-07 end %end%/82..

call standard\W-08.bat
set /a end+=1
echo W-08 end %end%/82..

call standard\W-09.bat
set /a end+=1
echo W-09 end %end%/82..

call standard\W-10.bat
set /a end+=1
echo W-10 end %end%/82..

if %IIS_RUN% EQU 0 goto W_IIS_NoRun

:W_IIS_Run

:: IIS Version 확인
reg query "HKLM\SOFTWARE\Microsoft\InetStp" | find /i "Version" | find /i "Major" | find /v "MetabaseSetMajorVersion" >> %TEMP%\IIS_ver.txt
FOR /f "tokens=3" %%i IN (%TEMP%\IIS_ver.txt) Do set IIS_V=%%i

:: IIS 6 이하
if %IIS_V% LEQ 6 (
	echo ※ IIS 6 이하 버전을 구동중이므로, 수동 점검이 필요함 >> %FILENAME%
	echo. >> %FILENAME%
	echo [IIS 버전 정보] >> %FILENAME%
	reg query "HKLM\SOFTWARE\Microsoft\InetStp" | find /i "SetupString" >> %FILENAME%
	echo. >> %FILENAME%
	echo. >> %FILENAME%
	echo. >> %FILENAME%
	goto W_IIS_NoRun
)

:: IIS 7 이상 기본정보 확인
%systemroot%\System32\inetsrv\appcmd list config /text:* >> %CONFIG%IIS_Config.txt

%systemroot%\System32\inetsrv\appcmd list site | find /i "http" >> %CONFIG%IIS_WebList.txt
FOR /f "tokens=1 delims=(" %%a IN (%CONFIG%IIS_WebList.txt) DO (
	FOR /f "tokens=2-11 delims= " %%b in ("%%a") do (
		echo %%b %%c %%d %%e %%f %%g %%h %%i %%j %%k >> %TEMP%\IIS_web_name.txt
	)
)

:: IIS 웹 사이트 경로 확인
FOR /f "delims=" %%l IN (%TEMP%\IIS_web_name.txt) DO (
	%systemroot%\system32\inetsrv\appcmd list site %%l /config | find /i "PhysicalPath" >> %TEMP%\IIS_root.txt
)
FOR /f "tokens=3 delims==" %%m IN (%TEMP%\IIS_root.txt) DO (
	FOR /f "tokens=1 delims=/" %%n IN ("%%m") DO (
		echo %%n >> %TEMP%\IIS_root_path.txt
		cacls %%n >> %TEMP%\IIS_path_acl.txt
	)
)


call standard\W-11.bat
set /a end+=1
echo W-11 end %end%/82..
echo -----------------------  > nul
call standard\W-12.bat
set /a end+=1
echo W-12 end %end%/82..
echo -----------------------  > nul
call standard\W-13.bat
set /a end+=1
echo W-13 end %end%/82..
echo -----------------------  > nul
call standard\W-14.bat
set /a end+=1
echo W-14 end %end%/82..
echo -----------------------  > nul
call standard\W-15.bat
set /a end+=1
echo W-15 end %end%/82..
echo -----------------------  > nul
call standard\W-16.bat
set /a end+=1
echo W-16 end %end%/82..
echo -----------------------  > nul
call standard\W-17.bat
set /a end+=1
echo W-17 end %end%/82..
echo -----------------------  > nul
call standard\W-18.bat
set /a end+=1
echo W-18 end %end%/82..
echo -----------------------  > nul
call standard\W-19.bat
set /a end+=1
echo W-19 end %end%/82..
echo -----------------------  > nul
call standard\W-20.bat
set /a end+=1
echo W-20 end %end%/82..
echo -----------------------  > nul
call standard\W-21.bat
set /a end+=1
echo W-21 end %end%/82..
echo -----------------------  > nul
call standard\W-22.bat
set /a end+=1
echo W-22 end %end%/82..
echo -----------------------  > nul
call standard\W-23.bat
set /a end+=1
echo W-23 end %end%/82..

:W_IIS_NoRun
call standard\W-24.bat
set /a end+=1
echo W-24 end %end%/82..

call standard\W-25.bat
set /a end+=1
echo W-25 end %end%/82..

call standard\W-26.bat
set /a end+=1
echo W-26 end %end%/82..

call standard\W-27.bat
set /a end+=1
echo W-27 end %end%/82..

call standard\W-28.bat
set /a end+=1
echo W-28 end %end%/82..

call standard\W-28_Old.bat
echo W-28_Old end %end%/82..

call standard\W-29.bat
set /a end+=1
echo W-29 end %end%/82..

call standard\W-30.bat
set /a end+=1
echo W-30 end %end%/82..

call standard\W-31.bat
set /a end+=1
echo W-31 end %end%/82..

call standard\W-58.bat
set /a end+=1
echo W-58 end %end%/82..

call standard\W-59.bat
set /a end+=1
echo W-59 end %end%/82..

call standard\W-60.bat
set /a end+=1
echo W-60 end %end%/82.. 

call standard\W-61.bat
set /a end+=1
echo W-61 end %end%/82.. 

call standard\W-62.bat
set /a end+=1
echo W-62 end %end%/82.. 

call standard\W-63.bat
set /a end+=1
echo W-63 end %end%/82.. 

call standard\W-64.bat
set /a end+=1
echo W-64 end %end%/82..

call standard\W-65.bat
set /a end+=1
echo W-65 end %end%/82..

call standard\W-66.bat
set /a end+=1
echo W-66 end %end%/82..

call standard\W-67.bat
set /a end+=1
echo W-67 end %end%/82..

:: call standard\W-68.bat
:: set /a end+=1
:: echo W-68 end %end%/82..

call standard\W-32.bat
set /a end+=1
echo W-32 end %end%/82..

:: call standard\W-33.bat
:: set /a end+=1
:: echo W-33 end %end%/82..

call standard\W-69.bat
set /a end+=1
echo W-69 end %end%/82..

:: call standard\W-34.bat
:: set /a end+=1
:: echo W-34 end %end%/82..

call standard\W-35.bat
set /a end+=1
echo W-35 end %end%/82..

call standard\W-70.bat
set /a end+=1
echo W-70 end %end%/82..

call standard\W-71.bat
set /a end+=1
echo W-71 end %end%/82..

:: call standard\W-36.bat
:: set /a end+=1
:: echo W-36 end %end%/82..

call standard\W-37.bat
set /a end+=1
echo W-37 end %end%/82..

call standard\W-38.bat
set /a end+=1
echo W-38 end %end%/82..

call standard\W-39.bat
set /a end+=1
echo W-39 end %end%/82..

call standard\W-40.bat
set /a end+=1
echo W-40 end %end%/82..

call standard\W-41.bat
set /a end+=1
echo W-41 end %end%/82..

call standard\W-42.bat
set /a end+=1
echo W-42 end %end%/82..

call standard\W-43.bat
set /a end+=1
echo W-43 end %end%/82..

call standard\W-44.bat
set /a end+=1
echo W-44 end %end%/82..

call standard\W-45.bat
set /a end+=1
echo W-45 end %end%/82..

call standard\W-72.bat
set /a end+=1
echo W-72 end %end%/82..

call standard\W-73.bat
set /a end+=1
echo W-73 end %end%/82..

call standard\W-74.bat
set /a end+=1
echo W-74 end %end%/82..

call standard\W-75.bat
set /a end+=1
echo W-75 end %end%/82..

call standard\W-76.bat
set /a end+=1
echo W-76 end %end%/82..

call standard\W-77.bat
set /a end+=1
echo W-77 end %end%/82..

call standard\W-78.bat
set /a end+=1
echo W-78 end %end%/82..

call standard\W-79.bat
set /a end+=1
echo W-79 end %end%/82..

call standard\W-80.bat
set /a end+=1
echo W-80 end %end%/82..

:: call standard\W-81.bat
:: set /a end+=1
:: echo W-81 end %end%/82..

call standard\W-82.bat
set /a end+=1
echo W-82 end %end%/82..

call standard\W-83.bat
set /a end+=1
echo W-83 end %end%/83..

set YEAR=%DATE:~2,2%
set MONTH=%DATE:~5,2%
set DAY=%DATE:~8,2%
set HOUR=%time:~0,2%
set MINUTE=%time:~3,2%
FOR /F "TOKENS=2* DELIMS=:" %%A IN ('IPCONFIG ^| FIND "IPv4"') DO FOR %%B IN (%%A) DO SET IPADDR=%%B

copy %FILENAME% resualt.txt > nul

rmdir /S /Q Temp
rmdir /S /Q Config
del %FILENAME%
::del *.txt