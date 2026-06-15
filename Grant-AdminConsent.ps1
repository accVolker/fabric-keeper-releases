#Requires -Version 7.0
<#
.SYNOPSIS
    Generiert den Admin-Consent-Link für einen Kunden-Tenant und öffnet ihn optional im Browser.

.DESCRIPTION
    Fabric Keeper ist eine Multi-Tenant-App. Bevor sich der erste Nutzer eines Kunden-Tenants
    anmelden kann, muss ein Entra-Administrator des Kunden-Tenants einmalig Consent erteilen.

    Dieser Link ist an den Consultant-Tenant gebunden (FABRIC_APP_CLIENT_ID aus .env).
    Der IT-Admin des Kunden klickt den Link, meldet sich als Global Admin an und bestätigt
    die Berechtigungen. Danach können alle Nutzer dieses Tenants die App verwenden.

.PARAMETER CustomerTenantId
    Tenant-ID (GUID) oder Domain (z.B. contoso.onmicrosoft.com) des Kunden-Tenants.

.PARAMETER ClientId
    App-Client-ID aus der Entra-Registrierung im Consultant-Tenant.
    Wird automatisch aus .env geladen wenn nicht angegeben.

.PARAMETER Open
    Öffnet den Consent-Link direkt im Standardbrowser.

.EXAMPLE
    .\Grant-AdminConsent.ps1 -CustomerTenantId "12345678-abcd-..."
    .\Grant-AdminConsent.ps1 -CustomerTenantId "contoso.onmicrosoft.com" -Open
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CustomerTenantId,

    [string]$ClientId,

    [switch]$Open
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# ClientId aus .env laden wenn nicht angegeben
# ---------------------------------------------------------------------------

if (-not $ClientId) {
    $EnvFile = Join-Path $PSScriptRoot ".." ".env"
    if (Test-Path $EnvFile) {
        Get-Content $EnvFile | ForEach-Object {
            if ($_ -match "^FABRIC_APP_CLIENT_ID\s*=\s*(.+)$") {
                $ClientId = $Matches[1].Trim()
            }
        }
    }
    if (-not $ClientId) {
        Write-Error "FABRIC_APP_CLIENT_ID nicht gefunden. Bitte -ClientId angeben oder in .env setzen."
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Consent-URL generieren
# ---------------------------------------------------------------------------

$RedirectUri  = [Uri]::EscapeDataString("http://localhost:8000")
$ConsentUrl   = "https://login.microsoftonline.com/$CustomerTenantId/adminconsent?client_id=$ClientId&redirect_uri=$RedirectUri"

Write-Host ""
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host "  Fabric Keeper — Admin-Consent-Link" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan
Write-Host ""
Write-Host "  Kunden-Tenant : $CustomerTenantId"
Write-Host "  App-Client-ID : $ClientId"
Write-Host ""
Write-Host "  Consent-Link:" -ForegroundColor Yellow
Write-Host "  $ConsentUrl" -ForegroundColor White
Write-Host ""
Write-Host "  Anleitung für den IT-Admin des Kunden:" -ForegroundColor Gray
Write-Host "  1. Link oben kopieren und im Browser öffnen" -ForegroundColor Gray
Write-Host "  2. Als Entra Global Admin (oder Application Administrator) anmelden" -ForegroundColor Gray
Write-Host "  3. Berechtigungen prüfen und 'Akzeptieren' klicken" -ForegroundColor Gray
Write-Host "  4. Nach Weiterleitung auf localhost: Consent erfolgreich" -ForegroundColor Gray
Write-Host "  5. Danach kann der Consultant-Admin die App mit diesem Tenant nutzen" -ForegroundColor Gray
Write-Host ""

# Auf Clipboard kopieren
try {
    $ConsentUrl | Set-Clipboard
    Write-Host "  Link wurde in die Zwischenablage kopiert." -ForegroundColor Green
} catch {
    Write-Host "  (Zwischenablage nicht verfügbar)" -ForegroundColor Gray
}

# Optional: Browser öffnen
if ($Open) {
    Write-Host ""
    Write-Host "  Öffne Browser …" -ForegroundColor Cyan
    Start-Process $ConsentUrl
}

Write-Host ""
