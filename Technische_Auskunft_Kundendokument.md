# Microsoft Fabric Keeper — Technische Auskunft für Kunden
**Version 1.0 | Juni 2026 | Öffentlich — Kundeninformation**

---

## Inhalt

1. [Was macht die Anwendung?](#1-was-macht-die-anwendung)
2. [Welche Daten werden abgerufen?](#2-welche-daten-werden-abgerufen)
3. [Welche Daten werden gespeichert?](#3-welche-daten-werden-gespeichert)
4. [Welche Berechtigungen werden benötigt?](#4-welche-berechtigungen-werden-ben%C3%B6tigt)
5. [Einmalige Einrichtung — App-Registrierung](#5-einmalige-einrichtung--app-registrierung)
6. [Authentifizierungsablauf](#6-authentifizierungsablauf)
7. [Datenschutz und Datensicherheit](#7-datenschutz-und-datensicherheit)
8. [Fragen und Antworten](#8-fragen-und-antworten)

---

## 1. Was macht die Anwendung?

Microsoft Fabric Keeper ist ein Desktop-Tool für Windows, das Fabric-Administratoren und Compliance-Teams dabei unterstützt, die Sicherheits- und Compliance-Konfiguration eines Microsoft-Fabric-Tenants systematisch zu analysieren.

### Kernfunktionen im Überblick

| Modul | Funktion | Schreibzugriff auf Tenant |
|---|---|---|
| **Gesamt-Übersicht** | Tenant-Einstellungen mit einer Sicherheits-Baseline abgleichen, Sicherheitsscore berechnen | Ja — optional, nach Bestätigung |
| **DSGVO** | Einstellungen mit DSGVO-Empfehlungen abgleichen (vier Profile: none / personal / special / separated) | Ja — optional |
| **DORA** | Einstellungen mit DORA-Anforderungen abgleichen | Ja — optional |
| **EU AI Act** | KI-relevante Einstellungen prüfen | Ja — optional |
| **ISO 27001** | Einstellungen gegen ISO-27001-Controls mappen | Ja — optional |
| **Purview** | Sensitivity-Label-Konfiguration prüfen | Nein — rein lesend |
| **Azure** | Azure-Infrastruktur rund um die Fabric-Kapazität prüfen (optional, Opt-in) | Nein — rein lesend |
| **Overview** | Kapazitäten, Workspaces, Admins, Gateways anzeigen | Nein — rein lesend |

### Wichtige Eigenschaften

- **Kein Cloud-Backend:** Die Anwendung läuft vollständig lokal auf dem Rechner des Administrators. Es gibt keinen externen Server, keine Telemetrie, keine Datenweitergabe an Dritte.
- **Kein automatisches Polling:** Alle API-Abfragen erfolgen ausschließlich nach manuellem Auslösen durch den Benutzer (Schaltfläche „Jetzt scannen"). Es gibt keine Hintergrundprozesse.
- **Direkte Änderungen sind optional:** Die App kann Tenant-Einstellungen auf Wunsch des Administrators direkt über die offizielle Microsoft-API korrigieren. Voraussetzung ist immer ein Dry-Run (Vorschau) und eine explizite Bestätigung.

---

## 2. Welche Daten werden abgerufen?

Alle API-Abfragen erfolgen im Namen des angemeldeten Benutzers (delegierte Berechtigung, kein Service Principal). Es werden ausschließlich lesende Abfragen gestellt, sofern der Administrator keine Änderungen aktiv anordert.

### 2.1 Fabric Admin API — Tenant-Einstellungen

**Endpunkt:** `GET https://api.fabric.microsoft.com/v1/admin/tenantsettings`

Liefert alle konfigurierten Tenant-Einstellungen des Microsoft-Fabric-Tenants: Name, Aktivierungsstatus, ggf. zugewiesene Sicherheitsgruppen. Es werden **keine Inhalte** (Lakehouse-Daten, Reports, Notebooks, persönliche Daten von Endnutzern) abgerufen — ausschließlich administrative Konfigurationsdaten.

### 2.2 Fabric Admin API — Workspaces

**Endpunkt:** `GET https://api.fabric.microsoft.com/v1/admin/workspaces`

Name, Typ (PersonalGroup / Workspace), Status (Active / Deleted), Kapazitätszuordnung, Erstellungsdatum. Keine Workspace-Inhalte (Artefakte, Dateien, Daten).

### 2.3 Power BI / Fabric Admin API — Kapazitäten

**Endpunkt:** `GET https://api.powerbi.com/v1.0/myorg/admin/capacities`

Name, SKU (z. B. F4, F64), Region, Status (Active / Paused), Kapazitätsadministratoren (E-Mail-Adressen).

### 2.4 Fabric API — Gateways

**Endpunkte (Fallback-Kette):**
1. `GET https://api.fabric.microsoft.com/v1/gateways`
2. `GET https://api.powerbi.com/v1.0/myorg/admin/gateways`

Name und Typ (Virtual Network / On-Premises / Personal) der Gateway-Cluster.

### 2.5 Microsoft Graph — Fabric-Administratoren

**Endpunkt:** `GET https://graph.microsoft.com/v1.0/directoryRoles(roleTemplateId='...')/members`

Mitglieder der Entra-ID-Rolle „Fabric Administrator": Anzeigename, E-Mail-Adresse, Object-ID. Wird nur abgerufen, wenn die Berechtigung `Group.Read.All` vorhanden ist. Andernfalls erfolgt ein Fallback auf die in der Kapazitätskonfiguration eingetragenen Admin-E-Mail-Adressen.

### 2.6 Microsoft Graph — Sicherheitsgruppen (bei Einstellungsänderungen)

**Endpunkt:** `GET https://graph.microsoft.com/v1.0/groups?$search="displayName:..."` (Suche)  
**Endpunkt:** `POST https://graph.microsoft.com/v1.0/directoryObjects/getByIds` (Typ-Auflösung)

Wird nur beim Zuweisen von Sicherheitsgruppen zu einer Tenant-Einstellung benötigt. Es werden ausschließlich `id` und `displayName` der Gruppen übertragen.

### 2.7 Azure Resource Manager — Azure-Modul (optional, Opt-in)

**Endpunkte:**
- `GET https://management.azure.com/subscriptions`
- `GET .../resourceGroups/.../resources`
- `POST .../providers/Microsoft.CostManagement/query`
- `GET .../providers/Microsoft.Security/pricings`

Dieses Modul wird **nur aktiviert, wenn der Benutzer explizit** auf „Azure-Modul aktivieren" klickt und einen Azure-Token erteilt. Es werden Azure-Ressourcen (Storage Accounts, Fabric-Kapazitäten, Policy-Assignments), Kosten (Cost Management) und Diagnostic Settings gelesen. Keine Inhaltsdaten.

### Zusammenfassung: Was wird NICHT abgerufen

| Datenkategorie | Wird abgerufen? |
|---|---|
| Lakehouse-Dateien, Tabellen, Delta-Daten | ❌ Nein |
| Notebook-Code oder Pipeline-Definitionen | ❌ Nein |
| Power-BI-Report-Inhalte oder Semantic-Model-Daten | ❌ Nein |
| Endnutzer-Aktivitätsprotokolle / Audit-Logs des Tenants | ❌ Nein |
| Persönliche Daten von Workspace-Mitgliedern (Endnutzer) | ❌ Nein |
| Passwörter, Secrets, Key-Vault-Inhalte | ❌ Nein |

---

## 3. Welche Daten werden gespeichert?

Alle Daten werden **ausschließlich lokal** auf dem Rechner des Administrators gespeichert — in einer verschlüsselten SQLite-Datenbank.

| Pfad | Inhalt |
|---|---|
| `%LOCALAPPDATA%\FabricKeeper\fabric_analyzer.db` | Verschlüsselte SQLite-Datenbank (SQLCipher) |
| `%LOCALAPPDATA%\FabricKeeper\fabrickeeper.log` | Anwendungslog (lokal, kein Remote-Logging) |

### Gespeicherte Inhalte

| Kategorie | Beschreibung |
|---|---|
| **Baseline-Konfiguration** | Empfehlungswerte je Modul (aus dem Lieferumfang der App, kein Tenant-Bezug) |
| **Overrides** | Vom Administrator definierte Ausnahmen für einzelne Einstellungen (mit Begründung) |
| **Score-Historie** | Zeitreihe der berechneten Compliance-Scores pro Modul |
| **Snapshots** | Zustand einer Einstellung vor einer Änderung (Grundlage für Rollback) |
| **Audit-Log** | Welcher Benutzer hat wann welche Einstellung auf welchen Wert gesetzt |
| **Token-Cache** | MSAL-Token zwischengespeichert im Windows Credential Manager (nicht in der DB) |

### Verschlüsselung

Die Datenbank ist mit **SQLCipher** verschlüsselt. Der Datenbankschlüssel wird über die **Windows Data Protection API (DPAPI)** erzeugt und im Windows Credential Store gespeichert — nie als Klartext auf der Festplatte. Ein Zugriff auf die Datenbank ist nur von demselben Windows-Benutzerkonto aus möglich.

### Datenlöschung

Jedes Kundenprofil (Tenant) kann in der Anwendung einzeln gelöscht werden. Ein vollständiger Reset ist durch Löschen der Datenbankdatei möglich.

---

## 4. Welche Berechtigungen werden benötigt?

### 4.1 Berechtigungsübersicht

Alle Berechtigungen sind **delegiert** — sie werden nur genutzt, wenn ein Benutzer aktiv angemeldet ist und eine Aktion auslöst. Es gibt keinen Service Principal mit dauerhaftem Zugriff.

| API | Berechtigung | Typ | Zweck | Pflicht |
|---|---|---|---|---|
| **Power BI Service** | `Tenant.Read.All` | Delegiert | Tenant-Einstellungen lesen | ✅ Ja |
| **Power BI Service** | `Tenant.ReadWrite.All` | Delegiert | Tenant-Einstellungen schreiben (nur bei aktiver Korrektur) | ✅ Ja¹ |
| **Microsoft Graph** | `User.Read` | Delegiert | Benutzerprofil des angemeldeten Accounts lesen | ✅ Ja |
| **Microsoft Graph** | `Group.Read.All` | Delegiert | Sicherheitsgruppen anzeigen und Fabric-Admins auflisten | ✅ Ja² |
| **Azure Service Management** | `user_impersonation` | Delegiert | Azure-Ressourcen und Kosten lesen (Azure-Modul) | ❌ Optional³ |

¹ `Tenant.ReadWrite.All` ist technisch immer registriert, wird aber nur genutzt, wenn der Administrator eine Einstellungsänderung explizit bestätigt.  
² Ohne `Group.Read.All` funktioniert die App vollständig für alle Kernmodule; die Anzeige der vollständigen Fabric-Admin-Liste und die Gruppen-Suchfunktion sind eingeschränkt.  
³ Der Azure-Token wird erst angefordert, wenn der Benutzer das Azure-Modul aktiv öffnet.

### 4.2 Welche Entra-Rolle benötigt der Benutzer?

| Rolle in der App | Entra-ID-Voraussetzung | Kann lesen | Kann schreiben |
|---|---|---|---|
| **Fabric Administrator** | Entra-Rolle „Fabric Administrator" oder „Power Platform Administrator" | ✅ | ✅ |
| **Compliance Reviewer** | Normaler Entra-Account (keine Admin-Rolle erforderlich) | ✅ Nur Baseline | ❌ |

Die Rolle wird automatisch erkannt: Die App prüft beim Login, ob ein Test-Call auf `GET /v1/admin/tenantsettings` mit HTTP 200 antwortet. Bei HTTP 403 wird der Account als Compliance Reviewer eingestuft.

### 4.3 Admin-Consent

Die registrierten Berechtigungen erfordern einmalig einen **Admin-Consent** durch einen Entra-Administrator des jeweiligen Tenants. Nach der Freigabe können sich Fabric-Administratoren und Compliance-Reviewer ohne weitere IT-Beteiligung anmelden.

---

## 5. Einmalige Einrichtung — App-Registrierung

### Voraussetzungen

- **Azure CLI** (Version 2.x): [https://aka.ms/install-azure-cli](https://aka.ms/install-azure-cli)
- **PowerShell 7** oder neuer
- **Entra-Rolle für App-Registrierung:** `Application Administrator`, `Cloud Application Administrator` oder `Global Administrator`
- **Entra-Rolle für Admin-Consent:** `Global Administrator` oder `Privileged Role Administrator`

### Schritt-für-Schritt

#### Schritt 1 — Azure CLI installieren und anmelden

```powershell
# Azure CLI installieren (falls noch nicht vorhanden)
winget install Microsoft.AzureCLI

# Im Kunden-Tenant anmelden
az login --tenant <KUNDEN-TENANT-ID>
```

#### Schritt 2 — App-Registrierungsskript ausführen

Das mitgelieferte Skript `onboarding\Register-FabricApp.ps1` ist **idempotent** — es kann beliebig oft ausgeführt werden, ohne Duplikate zu erzeugen.

```powershell
# Empfohlen für Kunden-Admins, die die App selbst betreiben (Single-Tenant):
.\onboarding\Register-FabricApp.ps1

# Für Consultants, die die App mit mehreren Kunden-Tenants verbinden (Multi-Tenant):
.\onboarding\Register-FabricApp.ps1 -Mode MultiTenant
```

Das Skript erledigt automatisch:
- App-Registrierung in Entra ID anlegen
- Public-Client-Flow aktivieren (kein Secret, kein Certificate erforderlich)
- API-Berechtigungen (Graph, Power BI Service, ARM) hinzufügen
- Admin-Consent erteilen (sofern der ausführende Account die Berechtigung hat)
- Am Ende werden `FABRIC_APP_CLIENT_ID` und `FABRIC_TENANT_ID` für die `.env`-Datei ausgegeben

#### Schritt 3 — `.env`-Datei anlegen

Im Installationsverzeichnis der App eine `.env`-Datei mit folgendem Inhalt erstellen:

```env
FABRIC_APP_CLIENT_ID=<App-ID aus Schritt 2>
FABRIC_TENANT_ID=<Kunden-Tenant-ID>
```

#### Schritt 4 — Lizenzdatei ablegen

Die vom Hersteller bereitgestellte Datei `license.lic` in folgendes Verzeichnis kopieren:

```
%LOCALAPPDATA%\FabricKeeper\license.lic
```

Ohne gültige Lizenzdatei zeigt die App nach dem Login einen Sperrbildschirm. Die Lizenz wird ausschließlich lokal geprüft — kein Verbindungsaufbau zu einem Lizenzserver.

#### Schritt 5 — Admin-Consent manuell erteilen (falls Schritt 2 fehlschlägt)

Falls der automatische Consent nicht funktioniert, kann er manuell über den Browser erteilt werden:

```
https://login.microsoftonline.com/<TENANT-ID>/adminconsent
  ?client_id=<CLIENT-ID>
  &redirect_uri=http://localhost
```

Diese URL wird am Ende des Skripts angezeigt.

### App-Registrierung im Entra Admin Center prüfen

Nach der Ausführung ist die Registrierung unter folgendem Pfad sichtbar:

```
Entra Admin Center → Anwendungen → App-Registrierungen → Alle Anwendungen → "Fabric Keeper"
```

Zu prüfen:
- **API-Berechtigungen**: Power BI Service (Tenant.Read.All, Tenant.ReadWrite.All), Microsoft Graph (User.Read, Group.Read.All)
- **Authentifizierung**: Öffentliche Client-Flows aktiviert, Redirect-URI `http://localhost`
- **Admin-Consent**: Grünes Häkchen bei allen Berechtigungen

---

## 6. Authentifizierungsablauf

```
Benutzer startet App
        │
        ▼
App prüft: MSAL-Token-Cache vorhanden und gültig?
        │
   Ja ──┼──► Token ohne erneuten Login verwenden
        │
   Nein ▼
        │
Microsoft-Login-Popup (MSAL Interactive Flow)
  → Entra-ID-Authentifizierung (inkl. MFA falls konfiguriert)
  → Benutzer erteilt Scope-Zustimmung (einmalig, falls nicht bereits Admin-Consented)
        │
        ▼
App liest Benutzername + Tenant aus dem JWT-Token
        │
        ▼
Rollenprüfung: Test-Call GET /v1/admin/tenantsettings
  HTTP 200 → Fabric Administrator
  HTTP 403 → Compliance Reviewer
        │
        ▼
Dashboard wird geladen
```

**Token-Speicherung:** Das MSAL-Token wird im Windows Credential Manager gespeichert (verschlüsselt, DPAPI). Bei Schreibfehlern (z. B. bei sehr langen Token-Caches) bleibt das Token für die aktuelle Sitzung im Speicher aktiv; beim nächsten Start ist ein erneuter Login erforderlich.

---

## 7. Datenschutz und Datensicherheit

| Aspekt | Umsetzung |
|---|---|
| **Datenspeicherort** | Ausschließlich lokal auf dem Rechner des Administrators |
| **Datenbankschutz** | SQLCipher-Verschlüsselung, Schlüssel via Windows DPAPI |
| **Netzwerkkommunikation** | Primär zu Microsoft-Endpunkten (api.fabric.microsoft.com, graph.microsoft.com, login.microsoftonline.com). Einmalig beim App-Start: Update-Check gegen `accvolker.github.io/fabric-keeper-releases/latest.json` (GitHub Pages, nur Versionsnummer, keine Nutzerdaten). |
| **Keine Telemetrie** | Die App sendet keine Nutzungsdaten, keine Fehlerberichte an externe Server |
| **Kein KI-Backend zur Laufzeit** | Die Baseline-Empfehlungen sind vorberechnet und in der App enthalten — kein API-Call an Claude oder andere KI-Dienste während der Nutzung |
| **Authentifizierung** | Delegierter OAuth 2.0 Flow (kein Service Principal, kein dauerhafter Zugriff) |
| **Zugriffsnachweis** | Jede Tenant-Änderung wird mit Zeitstempel, Benutzer, Vorwert und Neuwert im lokalen Audit-Log protokolliert |
| **Rollback** | Vor jeder Änderung wird ein Snapshot gespeichert; Rollback auf den Vorwert ist jederzeit möglich |

### Sicherheitsempfehlung: MFA per Conditional Access

Da Fabric Keeper ein administratives Tool ist, wird empfohlen, MFA für alle Benutzer dieser App über eine Conditional-Access-Policy zu erzwingen:

```
Entra Admin Center → Sicherheit → Bedingter Zugriff → Neue Richtlinie

  Name:              Fabric Keeper – MFA erforderlich
  Benutzer:          Alle Benutzer (oder gezielte Gruppe)
  Zielanwendung:     Fabric Keeper (Client-ID aus App-Registrierung)
  Zugriffssteuerung: Mehrstufige Authentifizierung erforderlich
```

---

## 8. Fragen und Antworten

**Greift die App dauerhaft auf unseren Tenant zu?**  
Nein. Es gibt keinen Service Principal und keinen geplanten Hintergrundjob. Zugriffe erfolgen ausschließlich, wenn ein Administrator die App geöffnet hat und aktiv eine Aktion auslöst (z. B. „Jetzt scannen").

**Werden Tenant-Einstellungen ohne unser Wissen geändert?**  
Nein. Jede Änderung erfordert drei explizite Schritte: (1) Dry-Run starten, (2) Vorschau prüfen, (3) Änderung im Bestätigungsdialog mit Ist- und Sollwert aktiv bestätigen. Ein versehentliches Schreiben ist durch das UI-Design ausgeschlossen.

**Welche Einstellungen kann die App ändern?**  
Ausschließlich Tenant-Einstellungen, die über den offiziellen Endpunkt `POST /v1/admin/tenantsettings/{name}/update` der Microsoft Fabric Admin API zugänglich sind — dieselben Einstellungen, die auch im Fabric Admin Portal unter „Tenant-Einstellungen" sichtbar sind.

**Verlassen Daten unseren Tenant?**  
Nein. Alle abgerufenen Daten werden lokal auf dem Rechner des Administrators gespeichert. Die App kommuniziert ausschließlich mit Microsoft-Endpunkten.

**Was passiert, wenn die App deinstalliert wird?**  
Die App hinterlässt die Datenbank unter `%LOCALAPPDATA%\FabricKeeper\`. Diese kann manuell gelöscht werden. In Entra ID bleibt die App-Registrierung bestehen und muss ggf. manuell entfernt werden.

**Kann der Kunden-Admin den Zugriff jederzeit widerrufen?**  
Ja. Die App-Registrierung kann im Entra Admin Center unter „App-Registrierungen" jederzeit gelöscht oder der Admin-Consent entzogen werden. Alternativ kann unter „Enterprise-Anwendungen" die Zuweisung der App deaktiviert werden.

**Welche Microsoft-APIs werden verwendet?**  
- `https://api.fabric.microsoft.com/v1/admin/` (Fabric Admin API)
- `https://api.powerbi.com/v1.0/myorg/admin/` (Power BI Admin API, für Kapazitäten/Gateways)
- `https://graph.microsoft.com/v1.0/` (Microsoft Graph, für Benutzer und Gruppen)
- `https://management.azure.com/` (Azure Resource Manager, nur Azure-Modul, Opt-in)
- `https://login.microsoftonline.com/` (Entra ID, für Authentifizierung)

---

*Dieses Dokument richtet sich an IT-Administratoren und Datenschutzverantwortliche des Kunden-Tenants. Bei Fragen wenden Sie sich an Ihren Fabric-Keeper-Ansprechpartner.*
