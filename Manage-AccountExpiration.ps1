<#
.SYNOPSIS
List AD users with a finite account expiration date.
Optionally remove expiration and set them to never expire.
Can be scoped to a single user.

.PARAMETER SearchBase
LDAP path to scope the search. Defaults to the domain root.

.PARAMETER IncludeDisabled
Include disabled accounts. By default they are excluded.

.PARAMETER ExportCsv
Optional path to export results as CSV.

.PARAMETER RemoveExpiration
If present, will set accountExpires to never for the users found.

.PARAMETER UserFilter
SamAccountName to limit the query to one user.
#>

param(
  [string]$SearchBase = (Get-ADDomain).DistinguishedName,
  [switch]$IncludeDisabled,
  [string]$ExportCsv,
  [switch]$RemoveExpiration,
  [string]$UserFilter
)

# Sentinel values for "never"
$Never0   = 0
$NeverMax = [Int64]::MaxValue   # 9223372036854775807

# Build LDAP filter
if ($UserFilter) {
  # Filter for a specific user
  $baseFilter = "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$UserFilter)(!(accountExpires=0))(!(accountExpires=$NeverMax)))"
} else {
  # General filter for all finite expirations
  $baseFilter = '(&(objectCategory=person)(objectClass=user)(!(accountExpires=0))(!(accountExpires=9223372036854775807)))'
}

if (-not $IncludeDisabled) {
  $baseFilter = "(&${baseFilter}(!(userAccountControl:1.2.840.113556.1.4.803:=2)))"
}

$props = @(
  'SamAccountName','DisplayName','Enabled','accountExpires','userAccountControl','whenChanged','DistinguishedName'
)

$raw = Get-ADUser -LDAPFilter $baseFilter -SearchBase $SearchBase -ResultSetSize $null -Properties $props

$now = Get-Date

$rows = $raw | ForEach-Object {
  $ae = [int64]$_.accountExpires
  $expiry = $null
  if ($ae -gt 0 -and $ae -lt $NeverMax) {
    try { $expiry = [DateTime]::FromFileTimeUtc($ae) } catch { $expiry = $null }
  }

  $uac = [int]$_.userAccountControl
  $pwdNeverExpires = [bool]($uac -band 0x10000)

  $daysRemaining = if ($expiry) { [math]::Floor(($expiry - $now.ToUniversalTime()).TotalDays) } else { $null }

  [pscustomobject]@{
    SamAccountName       = $_.SamAccountName
    DisplayName          = $_.DisplayName
    Enabled              = $_.Enabled
    ExpirationUtc        = $expiry
    DaysRemaining        = $daysRemaining
    PasswordNeverExpires = $pwdNeverExpires
    DN                   = $_.DistinguishedName
    LastModified         = $_.whenChanged
  }
} | Sort-Object ExpirationUtc

# Export if requested
if ($ExportCsv) {
  $rows | Export-Csv -NoTypeInformation -Path $ExportCsv -Encoding UTF8
}

# Display table
$rows | Format-Table SamAccountName, DisplayName, Enabled, ExpirationUtc, DaysRemaining, PasswordNeverExpires -Auto

function Set-NeverExpires {
  param([Parameter(Mandatory)][string]$Identity)

  # Prefer purpose-built cmdlet if available
  $clearCmd = Get-Command Clear-ADAccountExpiration -ErrorAction SilentlyContinue
  if ($clearCmd) {
    Clear-ADAccountExpiration -Identity $Identity -ErrorAction Stop
    return
  }

  # Fallback 1: supported broadly
  try {
    Set-ADUser -Identity $Identity -AccountExpirationDate $null -ErrorAction Stop
    return
  } catch {}

  # Fallback 2: raw attribute write
  Set-ADUser -Identity $Identity -Replace @{accountExpires=0} -ErrorAction Stop
}

# Optionally remove expiration
if ($RemoveExpiration -and $rows) {
  if ($UserFilter) {
    Write-Host "`n[INFO] Removing account expiration for user $UserFilter..."
  } else {
    Write-Host "`n[INFO] Removing account expiration for $($rows.Count) users..."
  }

  foreach ($u in $rows) {
    try {
      Set-NeverExpires -Identity $u.SamAccountName
      Write-Host "[OK] $($u.SamAccountName) ($($u.DisplayName)) reset to never expire"
    }
    catch {
      Write-Warning "Failed to update $($u.SamAccountName): $($_.Exception.Message)"
    }
  }
}
