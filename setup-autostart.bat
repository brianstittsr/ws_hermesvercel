@echo off
REM Setup Docker and Hermes to auto-start on Windows

echo Setting Docker Desktop to auto-start...
powershell -Command "Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Docker Desktop' -ErrorAction SilentlyContinue; if ($?) { Write-Host 'Docker Desktop already in startup' } else { Write-Host 'Adding Docker Desktop to startup...'; Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Docker Desktop' -Value 'C:\Program Files\Docker\Docker\Docker Desktop.exe' }"

echo Starting Docker Desktop...
start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"

echo Waiting for Docker to start...
timeout /t 30 /nobreak

echo Starting Hermes containers...
cd /d "%~dp0"
docker-compose up -d

echo Hermes auto-start setup complete!
echo Dashboard will be available at http://localhost:9119
pause
