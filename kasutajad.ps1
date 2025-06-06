# määrab AD kataloogi üksikasjad
$domain = "oige.local"
$kasutajadOU = "OU=KASUTAJAD,DC=oige,DC=local"
$defaultPassword = "Parool12345!"

# Erimärkide eemaldamine 
function Remove-Diacritics {
    param([string]$text)
    $normalized = [System.Text.NormalizationForm]::FormD
    $bytes = [System.Text.Encoding]::GetEncoding("ISO-8859-8").GetBytes($text.Normalize($normalized))
    [System.Text.Encoding]::UTF8.GetString($bytes)
}

# Ou loomine kui seda pole olemas
function Create-ADOU {
    param (
        [string]$parentOU,
        [string]$newOU
    )

    $ouPath = "OU=$newOU,$parentOU"

    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$newOU'" -SearchBase $parentOU -Server $domain)) {
        New-ADOrganizationalUnit -Name $newOU -Path $parentOU -Server $domain
        Write-Host "OU created: $ouPath"
    } else {
        Write-Host "OU already exists: $ouPath"
    }

    return $ouPath
}

# genereerib unikaalse kasutajanime and UPN
function Get-UniqueUsername {
    param (
        [string]$baseUsername
    )

    $suffix = 0
    $uniqueUsername = $baseUsername

    while ($true) {
        $samAccountName = $uniqueUsername.Replace(".", "")
        $upn = "$uniqueUsername@$domain"

        $existingUser = Get-ADUser -Filter {
            SamAccountName -eq $samAccountName -or UserPrincipalName -eq $upn
        } -Server $domain -ErrorAction SilentlyContinue

        if (-not $existingUser) {
            return $uniqueUsername
        }

        $suffix++
        $uniqueUsername = "$baseUsername$suffix"
    }
}

# loob AD kasutaja kui teda ei eksisteeri
function Create-ADUser {
    param (
        [string]$ouPath,
        [string]$name,
        [string]$baseUsername,
        [string]$password
    )

    $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force

    $finalUsername = Get-UniqueUsername -baseUsername $baseUsername
    $samAccountName = $finalUsername.Replace(".", "")
    $userPrincipalName = "$finalUsername@$domain"

    New-ADUser -Name $name `
               -SamAccountName $samAccountName `
               -UserPrincipalName $userPrincipalName `
               -Path $ouPath `
               -AccountPassword $securePassword `
               -Enabled $true `
               -Server $domain
    Write-Host "User created: $samAccountName (UPN: $userPrincipalName) in OU: $ouPath"
}

# Loeb ja impordib csv
$csvPath = "C:\kasutajad.csv"
Import-Csv $csvPath | ForEach-Object {
    $name = $_.Nimi.Trim()
    $ouName = $_.Osakond.Trim()

    if ($name -and $ouName) {
        # Generate username: eesnimi.perenimi
        $parts = $name.Split(" ")
        if ($parts.Count -ge 2) {
            $firstname = $parts[0].ToLower()
            $lastname = $parts[-1].ToLower()

            # Optional: Remove Estonian diacritics
            # $firstname = Remove-Diacritics $firstname
            # $lastname = Remove-Diacritics $lastname

            $baseUsername = "$firstname.$lastname"

            # Create OU under KASUTAJAD
            $ouPath = Create-ADOU -parentOU $kasutajadOU -newOU $ouName

            # Create user
            Create-ADUser -ouPath $ouPath -name $name -baseUsername $baseUsername -password $defaultPassword
        } else {
            Write-Host "Skipping user due to malformed name: $name"
        }
    }
}
