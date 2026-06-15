#Requires -Version 7.0
<#
.SYNOPSIS
    Registriert die Fabric Keeper App im aktuellen Tenant.
    Idempotent: kann mehrmals ausgeführt werden, ohne Duplikate zu erzeugen.

.DESCRIPTION
    Benötigt die Azure CLI (az) — https://aka.ms/install-azure-cli
    Führen Sie zuerst "az login" aus.

    Zwei Modi:

    -Mode SingleTenant (Standard):
        Für Kunden-Admins, die die App in ihrem eigenen Tenant betreiben.
        Die App ist auf den eigenen Tenant beschränkt (AzureADMyOrg).
        Kein Cross-Tenant-Consent erforderlich. FABRIC_TENANT_ID wird automatisch gesetzt.

    -Mode MultiTenant:
        Für Consultants, die die App mit mehreren Kunden-Tenants nutzen.
        Die App ist Multi-Tenant (AzureADMultipleOrgs). Kunden erteilen
        beim ersten Login einmalig Consent im eigenen Tenant.

.EXAMPLE
    # Kunden-Admin betreibt die App selbst (empfohlen):
    .\Register-FabricApp.ps1

    # Consultant-Modell (eine App, viele Kunden-Tenants):
    .\Register-FabricApp.ps1 -Mode MultiTenant

    .\Register-FabricApp.ps1 -AppName "Meine Fabric Keeper App"
#>

[CmdletBinding()]
param(
    [string]$AppName = "Fabric Keeper",

    # "SingleTenant"  – App läuft nur im eigenen Tenant (Kunden-Admin betreibt die App selbst)
    # "MultiTenant"   – App läuft im Consultant-Tenant und verbindet sich per Cross-Tenant-Consent
    [ValidateSet("SingleTenant","MultiTenant")]
    [string]$Mode = "SingleTenant"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Write-Step([string]$Text) {
    Write-Host "`n[*] $Text" -ForegroundColor Cyan
}

function Write-Ok([string]$Text) {
    Write-Host "    [OK] $Text" -ForegroundColor Green
}

function Write-Skip([string]$Text) {
    Write-Host "    [--] $Text" -ForegroundColor DarkGray
}

function Write-Warn([string]$Text) {
    Write-Host "    [!]  $Text" -ForegroundColor Yellow
}

function Assert-AzCli {
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Host "FEHLER: Azure CLI (az) nicht gefunden." -ForegroundColor Red
        Write-Host "       Installation: https://aka.ms/install-azure-cli" -ForegroundColor Red
        exit 1
    }
}

function Get-CurrentTenantId {
    $account = az account show --query "{tenantId:tenantId}" -o json 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Host "FEHLER: Nicht angemeldet. Führen Sie 'az login' aus." -ForegroundColor Red
        exit 1
    }
    return $account.tenantId
}

# Fügt einen delegierten Scope nur hinzu, wenn er noch nicht in requiredResourceAccess steht.
# Verhindert Duplikate bei wiederholter Ausführung.
function Add-ScopeIfMissing {
    param(
        [string]$AppId,
        [string]$ResourceAppId,
        [string]$ScopeId,
        [string]$DisplayName
    )

    $currentPerms = az ad app show --id $AppId --query "requiredResourceAccess" -o json 2>$null | ConvertFrom-Json
    $resourceEntry = $currentPerms | Where-Object { $_.resourceAppId -eq $ResourceAppId }
    if ($resourceEntry) {
        $already = $resourceEntry.resourceAccess | Where-Object { $_.id -eq $ScopeId -and $_.type -eq "Scope" }
        if ($already) {
            Write-Skip "$DisplayName bereits vorhanden"
            return
        }
    }

    az ad app permission add `
        --id $AppId `
        --api $ResourceAppId `
        --api-permissions "${ScopeId}=Scope" 2>$null | Out-Null
    Write-Ok "$DisplayName hinzugefügt"
}

# ---------------------------------------------------------------------------
# Voraussetzungen
# ---------------------------------------------------------------------------

Assert-AzCli

Write-Step "Prüfe Azure-Anmeldung …"
$resolvedTenantId = Get-CurrentTenantId
$modeLabel = if ($Mode -eq "SingleTenant") { "Einzel-Tenant (Kunden-Admin)" } else { "Multi-Tenant (Consultant)" }
Write-Ok "Tenant-ID: $resolvedTenantId"
Write-Ok "Modus: $modeLabel"

# ---------------------------------------------------------------------------
# App-Registrierung (Multi-Tenant)
# ---------------------------------------------------------------------------

Write-Step "App-Registrierung: '$AppName' …"

$existingApp = az ad app list --display-name $AppName --query "[0].appId" -o tsv 2>$null
if ($existingApp) {
    Write-Skip "App '$AppName' existiert bereits (Client-ID: $existingApp)"
    $clientId = $existingApp
} else {
    $audience = if ($Mode -eq "SingleTenant") { "AzureADMyOrg" } else { "AzureADMultipleOrgs" }
    $appJson = az ad app create `
        --display-name $AppName `
        --sign-in-audience $audience `
        --query "{appId:appId,id:id}" `
        -o json | ConvertFrom-Json
    $clientId = $appJson.appId
    Write-Ok "App erstellt — Client-ID: $clientId"

    # Public-Client-Flow: kein Secret, interaktiver Login via MSAL
    az ad app update --id $clientId `
        --public-client-redirect-uris "http://localhost" `
        --set isFallbackPublicClient=true | Out-Null
    Write-Ok "Public-Client-Flow konfiguriert (Redirect: http://localhost)"

    # Service-Principal im eigenen Tenant anlegen
    az ad sp create --id $clientId | Out-Null
    Write-Ok "Service-Principal erstellt"
}

# ---------------------------------------------------------------------------
# API-Berechtigungen — idempotent: nur hinzufügen was noch fehlt
# ---------------------------------------------------------------------------

Write-Step "Prüfe API-Berechtigungen …"

# --- Microsoft Graph: User.Read + Group.Read.All ---
$graphResourceId     = "00000003-0000-0000-c000-000000000000"
$userReadScopeId     = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"  # User.Read delegated
$groupReadScopeId    = "5f8c59db-677d-491f-a6b8-5f174b11ec1d"  # Group.Read.All delegated
Add-ScopeIfMissing -AppId $clientId -ResourceAppId $graphResourceId `
    -ScopeId $userReadScopeId -DisplayName "Microsoft Graph: User.Read"
Add-ScopeIfMissing -AppId $clientId -ResourceAppId $graphResourceId `
    -ScopeId $groupReadScopeId -DisplayName "Microsoft Graph: Group.Read.All (Gruppensuche)"

# --- Power BI / Fabric Service: Tenant.Read.All + Tenant.ReadWrite.All ---
$fabricResourceId      = "00000009-0000-0000-c000-000000000000"
$tenantReadScopeId     = "47df08d3-85e6-4bd3-8c77-680fbe28162e"  # Tenant.Read.All delegated
$tenantReadWriteScopeId = "65853eff-8fca-4562-8c32-7c6d88cc23ed"  # Tenant.ReadWrite.All delegated

$fabricSpId = az ad sp list --filter "appId eq '$fabricResourceId'" --query "[0].id" -o tsv 2>$null
if (-not $fabricSpId) {
    Write-Warn "Power BI Service SP nicht im Tenant — versuche Erstellung …"
    az ad sp create --id $fabricResourceId 2>$null | Out-Null
    Start-Sleep -Seconds 5
    $fabricSpId = az ad sp list --filter "appId eq '$fabricResourceId'" --query "[0].id" -o tsv 2>$null
}

if ($fabricSpId) {
    Add-ScopeIfMissing -AppId $clientId -ResourceAppId $fabricResourceId `
        -ScopeId $tenantReadScopeId -DisplayName "Power BI Service: Tenant.Read.All"
    Add-ScopeIfMissing -AppId $clientId -ResourceAppId $fabricResourceId `
        -ScopeId $tenantReadWriteScopeId -DisplayName "Power BI Service: Tenant.ReadWrite.All (Einstellungen schreiben)"
} else {
    Write-Warn "Power BI Service SP nicht gefunden — manuell im Azure Portal hinzufügen:"
    Write-Warn "  App > API-Berechtigungen > Power BI Service > Tenant.Read.All + Tenant.ReadWrite.All"
}

# --- Azure Service Management: user_impersonation (optionales Azure-Modul) ---
$armResourceId  = "797f4846-ba00-4fd7-ba43-dac1f8f63013"
$armScopeId     = "41094075-9dad-400e-a0bd-54e686782033"  # user_impersonation delegated

$armSpId = az ad sp list --filter "appId eq '$armResourceId'" --query "[0].id" -o tsv 2>$null
if (-not $armSpId) {
    az ad sp create --id $armResourceId 2>$null | Out-Null
    Start-Sleep -Seconds 3
    $armSpId = az ad sp list --filter "appId eq '$armResourceId'" --query "[0].id" -o tsv 2>$null
}

if ($armSpId) {
    Add-ScopeIfMissing -AppId $clientId -ResourceAppId $armResourceId `
        -ScopeId $armScopeId -DisplayName "Azure Service Management: user_impersonation (opt. Azure-Modul)"
} else {
    Write-Warn "Azure Service Management SP nicht gefunden — ARM-Scope ggf. manuell hinzufügen."
}

# ---------------------------------------------------------------------------
# Berechtigungsübersicht nach Abschluss
# ---------------------------------------------------------------------------

Write-Step "Aktuelle API-Berechtigungen:"
$allPerms = az ad app show --id $clientId --query "requiredResourceAccess" -o json 2>$null | ConvertFrom-Json

$apiNames = @{
    "00000003-0000-0000-c000-000000000000" = "Microsoft Graph"
    "00000009-0000-0000-c000-000000000000" = "Power BI Service"
    "797f4846-ba00-4fd7-ba43-dac1f8f63013" = "Azure Service Management"
}
$scopeNames = @{
    "e1fe6dd8-ba31-4d61-89e7-88639da4683d" = "User.Read"
    "5f8c59db-677d-491f-a6b8-5f174b11ec1d" = "Group.Read.All"
    "47df08d3-85e6-4bd3-8c77-680fbe28162e" = "Tenant.Read.All"
    "65853eff-8fca-4562-8c32-7c6d88cc23ed" = "Tenant.ReadWrite.All"
    "41094075-9dad-400e-a0bd-54e686782033" = "user_impersonation"
}

foreach ($res in $allPerms) {
    $apiLabel = $apiNames[$res.resourceAppId] ?? $res.resourceAppId
    foreach ($scope in $res.resourceAccess) {
        $scopeLabel = $scopeNames[$scope.id] ?? $scope.id
        Write-Host "    $apiLabel  →  $scopeLabel  ($($scope.type))" -ForegroundColor White
    }
}

# ---------------------------------------------------------------------------
# Admin-Consent
# ---------------------------------------------------------------------------

Write-Step "Admin-Consent erteilen …"

try {
    az ad app permission admin-consent --id $clientId 2>$null | Out-Null
    Write-Ok "Admin-Consent automatisch erteilt (az CLI)"
} catch {
    Write-Warn "Automatischer Consent fehlgeschlagen — bitte URL unten im Browser öffnen."
}

Write-Host ""
Write-Host "  Falls der automatische Consent nicht funktioniert hat, öffnen Sie:" -ForegroundColor Yellow
$adminConsentUrl = "https://login.microsoftonline.com/$resolvedTenantId/adminconsent?client_id=$clientId&redirect_uri=http://localhost"
Write-Host "  $adminConsentUrl" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# Ergebnis
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "  FERTIG — Tragen Sie folgende Werte in Ihre .env ein:" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""
Write-Host "FABRIC_APP_CLIENT_ID=$clientId"
if ($Mode -eq "SingleTenant") {
    Write-Host "FABRIC_TENANT_ID=$resolvedTenantId"
} else {
    Write-Host "# FABRIC_TENANT_ID wird pro Kunden-Tenant gesetzt (nicht hier)"
}
Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""
Write-Host "Nächste Schritte:" -ForegroundColor White
if ($Mode -eq "SingleTenant") {
    Write-Host "  1. Beide Werte oben in .env eintragen" -ForegroundColor Gray
    Write-Host "  2. App starten: python -m uvicorn api.main:app --reload" -ForegroundColor Gray
    Write-Host "  3. Mit Ihrem Fabric-Admin-Account anmelden" -ForegroundColor Gray
} else {
    Write-Host "  1. FABRIC_APP_CLIENT_ID in .env eintragen (Wert oben kopieren)" -ForegroundColor Gray
    Write-Host "  2. FABRIC_TENANT_ID in .env auf den Kunden-Tenant setzen" -ForegroundColor Gray
    Write-Host "  3. App starten: python -m uvicorn api.main:app --reload" -ForegroundColor Gray
    Write-Host "  4. Im Browser anmelden — Kunden-Admin erteilt Consent beim ersten Login" -ForegroundColor Gray
}
Write-Host ""

# ---------------------------------------------------------------------------
# MFA-Empfehlung — Conditional Access
# ---------------------------------------------------------------------------

Write-Host ("=" * 70) -ForegroundColor Yellow
Write-Host "  SICHERHEITSEMPFEHLUNG: MFA per Conditional Access erzwingen" -ForegroundColor Yellow
Write-Host ("=" * 70) -ForegroundColor Yellow
Write-Host ""
Write-Host "  Fabric Keeper ist ein administratives Tool. Es wird empfohlen," -ForegroundColor White
Write-Host "  MFA für alle Benutzer dieser App über eine Conditional-Access-" -ForegroundColor White
Write-Host "  Policy im Entra-Admin-Center zu erzwingen." -ForegroundColor White
Write-Host ""
Write-Host "  Policy-Konfiguration:" -ForegroundColor Cyan
Write-Host "    Name          :  Fabric Keeper – MFA erforderlich" -ForegroundColor Gray
Write-Host "    Benutzer      :  Alle Benutzer (oder gezielte Gruppe)" -ForegroundColor Gray
Write-Host "    Zielanwendung :  $AppName (Client-ID: $clientId)" -ForegroundColor Gray
Write-Host "    Zugriffssteuerung: Mehrstufige Authentifizierung (MFA) erforderlich" -ForegroundColor Gray
Write-Host ""
Write-Host "  Entra-Admin-Center öffnen:" -ForegroundColor Cyan
Write-Host "  https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Hinweis: Für Multi-Tenant-Betrieb muss die Policy im jeweiligen" -ForegroundColor Yellow
Write-Host "  Kunden-Tenant konfiguriert werden, nicht im Consultant-Tenant." -ForegroundColor Yellow
Write-Host ""
