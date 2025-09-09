# Active Directory Account Expiration Audit & Remediation

This PowerShell script reports on Active Directory users who have a finite **`accountExpires`** value (i.e., accounts that are set to expire).  
It can also optionally remove expiration and reset them to **never expire**.

---

## Features

- **Report Mode**: Lists all users with an expiration date.
- **Targeted Mode**: Limit output to a specific user by `SamAccountName`.
- **Bulk Remediation**: Optionally clear account expiration for all or one user.
- **Flexible Filtering**:
  - Exclude or include disabled accounts.
  - Scope queries to a specific OU with `-SearchBase`.
- **Export Support**: Save results to CSV for auditing.

---

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+  
- Active Directory PowerShell module (`RSAT: Active Directory`)  
- Domain user with permissions to read and modify AD user attributes  

---

## Parameters

| Parameter         | Description                                                                                  |
|-------------------|----------------------------------------------------------------------------------------------|
| `-SearchBase`     | LDAP path to scope the query (default: domain root).                                         |
| `-IncludeDisabled`| Include disabled accounts in results (default: excluded).                                    |
| `-ExportCsv`      | Path to save results as CSV.                                                                 |
| `-RemoveExpiration`| Reset `accountExpires` to “never” for returned users.                                       |
| `-UserFilter`     | Limit the query to a single user by `SamAccountName`.                                        |

---

## Usage Examples

### List all users with finite expiration
```powershell
.\Get-FiniteAccountExpiry.ps1
```

### Limit search to a specific OU
```powershell
.\Get-FiniteAccountExpiry.ps1 -SearchBase "OU=Employees,DC=example,DC=com"
```

### Check one specific user
```powershell
.\Get-FiniteAccountExpiry.ps1 -UserFilter jsmith
```

### Remove expiration for a single user
```powershell
.\Get-FiniteAccountExpiry.ps1 -UserFilter jsmith -RemoveExpiration
```

### Remove expiration for all expiring users (use with caution)
```powershell
.\Get-FiniteAccountExpiry.ps1 -RemoveExpiration
```

### Export results to CSV
```powershell
.\Get-FiniteAccountExpiry.ps1 -ExportCsv "C:\Temp\account-expirations.csv"
```

---

## How It Works

- Queries Active Directory for users with `accountExpires` values other than `0` or `9223372036854775807` (sentinel “never” values).
- Converts raw **FILETIME** values to human-readable UTC expiration dates.
- Provides optional remediation using:
  - `Clear-ADAccountExpiration` (if available),
  - `Set-ADUser -AccountExpirationDate $null`,
  - Or directly writing `accountExpires=0`.

---

## Notes

- Default user creation in AD sets `accountExpires=0` (never expires).  
- Use caution with `-RemoveExpiration` in production; bulk changes may bypass intended IAM/HR workflows.  
- Replication lag may delay updates across all domain controllers.  
- Audit changes to ensure compliance with organizational policy.  

---

## License

Vibe Code License. Use at your own risk.
