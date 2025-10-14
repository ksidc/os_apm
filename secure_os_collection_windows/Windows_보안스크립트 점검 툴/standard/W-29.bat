@echo off

echo �������������������� W-29. DNS Zone Transfer ���� >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Net_Start.txt | find /i "DNS Server" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, DNS ���񽺰� ��Ȱ��ȭ�Ǿ� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	echo - DNS Server ���񽺰� ���� ������ ���� >> %FILENAME%	
) else (
	reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\DNS Server\Zones" | find /i /v "TrustAnchors" | findstr .  > nul
	if errorlevel 1 (
		echo �� ��� : ���, DNS ��/������ ��ȸ ������ �����Ǿ� ���� �����Ƿ� DNS ���񽺸� ������� ���� ��� ������ ���� �ǰ� >> %FILENAME%
		echo. >> %FILENAME%
		echo �� �� ��Ȳ >> %FILENAME%
		echo. >> %FILENAME%
		echo - DNS ��ȸ ������ �������� ���� >> %FILENAME%
	) else (
		reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\DNS Server\Zones" | find /i /v "TrustAnchors" >> %TEMP%\DNS_zone_name.txt
		FOR /f "delims=" %%a IN (%TEMP%\DNS_zone_name.txt) DO (
			reg query "%%a" >> %CONFIG%DNS_zones.txt
			reg query "%%a" | find /i "SecureSecondaries" | findstr /i "x0 x1" > nul
			if errorlevel 1 (
				echo ���� ���� ������Ʈ�� ���� 2 �Ǵ� 3���� �����Ǿ� ���� > nul
			) else (
				reg query "%%a" | findstr /i "HKEY DatabaseFile SecureSecondaries" >> %TEMP%\DNS_zone_transfer.txt
				echo. >> %TEMP%\DNS_zone_transfer.txt
			)
		)
		if exist %TEMP%\DNS_zone_transfer.txt (
			echo �� ��� : ���, ���� ������ '�ƹ� ������' �Ǵ� '�̸� ���� �ǿ� ������ �����θ�' ���� �����Ǿ� ���� >> %FILENAME%
			echo. >> %FILENAME%
			echo �� �� ��Ȳ >> %FILENAME%
			echo. >> %FILENAME%
			type %TEMP%\DNS_zone_transfer.txt >> %FILENAME%
		) else (
			echo �� ��� : ��ȣ, ���� ������ ������� �ʰų� Ư�� �����θ� �����ϵ��� �����Ǿ� ���� >> %FILENAME%
			echo. >> %FILENAME%
			echo �� �� ��Ȳ >> %FILENAME%
			echo. >> %FILENAME%
			type %CONFIG%DNS_zones.txt | find /i "SecureSecondaries" >> %FILENAME%
		)
		echo. >> %FILENAME%
		echo. >> %FILENAME%
		echo �� SecureSecondaries - 0x3: ���� ���� ��� �� ��, 0x2: ���� �����θ�, 0x1: �̸� ���� �ǿ� ������ �����θ�, 0x0: �ƹ� ������ >> %FILENAME%
		echo    DNS ��ȸ ���� ���� �� ������Ʈ�� ��Ȳ�� %CONFIG%DNS_zones.txt ���� ���� >> %FILENAME%
	)
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%