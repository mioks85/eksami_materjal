# Impordib DHCP mooduli (RSAT)
Import-Module DHCPServer

# Kaust raporti salvestamiseks, lisab kuupäeva
$kuupaev = Get-Date -Format "yyyy-MM-dd"
$folder = "C:\Raportid\DHCP_$kuupaev"

# Loob kausta, kui seda ei eksisteeri
if (!(Test-Path $folder)) { New-Item -ItemType Directory -Path $folder -Force }

# DHCP teenuse olek (veakontrolliga)
try {
    $service = Get-Service -Name dhcpserver
    $service | Select-Object Status, Name, DisplayName |
    Export-Csv "$folder\Teenuse_Olek.csv" -NoTypeInformation -Encoding UTF8
} catch {
    Write-Host "Viga teenuse oleku hankimisel: $_" -ForegroundColor Red
}

# Aktiivsed scoped ja veakontroll
try {
    $scopes = Get-DhcpServerv4Scope
    $scopes |
    Select-Object ScopeId, Name, State, StartRange, EndRange |
    Export-Csv "$folder\Skoopid.csv" -NoTypeInformation -Encoding UTF8
} catch {
    Write-Host "Viga skoopide hankimisel: $_" -ForegroundColor Red
}

# Kasutusel olevad IP-aadressid ja MACid, ainult aktiivsed
try {
    $leases = Get-DhcpServerv4Lease | Where-Object { $_.AddressState -eq "Active" }
    $leases |
    Select-Object IPAddress, ClientId, HostName, AddressState |
    Export-Csv "$folder\AktiivsedIPd.csv" -NoTypeInformation -Encoding UTF8
} catch {
    Write-Host "Viga IP-aadresside hankimisel: $_" -ForegroundColor Red
}

# Vabad IP-aadressid
foreach ($scope in $scopes) {
    try {
        # Kasutusel olevad IP-d selles skoopis
        $usedIPs = ($leases | Where-Object { $_.ScopeId -eq $scope.ScopeId }).IPAddress

        # Leia ainult kõik skoopi määratud IP-vahemik (10.0.22.100 - 10.0.22.200)
        $allIPs = 100..200 | ForEach-Object { "$($scope.ScopeId -replace '0$','').$_" }

        # Leia vabad IP-d
        $freeIPs = $allIPs | Where-Object { $usedIPs -notcontains $_ }

        # Salvesta vabad IP-aadressid CSV-sse
        $freeIPs |
        Select-Object @{Name="Scope";Expression={$scope.ScopeId}}, @{Name="VabaIP";Expression={$_}} |
        Export-Csv "$folder\VabadIPd_$($scope.ScopeId).csv" -NoTypeInformation -Append -Encoding UTF8
    } catch {
        Write-Host "Viga vaba IP-de arvutamisel: $_" -ForegroundColor Red
    }
}

Write-Host "DHCP raportid loodud kausta: $folder" -ForegroundColor Cyan
