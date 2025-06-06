# Impordib AD mooduli
Import-Module ActiveDirectory

# Kaust kuhu raport salvestatakse
$folder = "C:\Raportid\AD"
if (!(Test-Path $folder)) { New-Item -ItemType Directory -Path $folder }

# Kontod, mis pole kunagi sisseloginud
Get-ADUser -Filter * -Properties LastLogonDate |
Where-Object { -not $_.LastLogonDate } |
Select-Object Name, SamAccountName |
Export-Csv "$folder\EiOleLoginud.csv" -NoTypeInformation -Encoding UTF8

# kontod mis on keelatud
Get-ADUser -Filter 'Enabled -eq $false' |
Select-Object Name, SamAccountName |
Export-Csv "$folder\KeelatudKontod.csv" -NoTypeInformation -Encoding UTF8

# kontod mis on lukustatud
Search-ADAccount -LockedOut |
Select-Object Name, SamAccountName |
Export-Csv "$folder\LukustatudKontod.csv" -NoTypeInformation -Encoding UTF8

Write-Host "AD raportid loodud kausta: $folder" -ForegroundColor Green
