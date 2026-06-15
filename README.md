# Fabric Keeper

**Security & Compliance Analyzer für Microsoft Fabric**

Fabric Keeper ist ein Windows-Desktop-Tool für Fabric-Administratoren und Compliance-Teams.
Es liest die Tenant-Einstellungen eines Microsoft-Fabric-Mandanten, vergleicht sie mit
konfigurierbaren Compliance-Baselines und zeigt Handlungsbedarf strukturiert auf.

---

## Module

| Modul | Inhalt |
|---|---|
| **Security** | Tenant-Einstellungen scannen, Baseline-Abgleich, Compliance-Score, Direkt-Korrekturen mit Rollback |
| **DSGVO** | Vier Risikoprofile (keine / personenbezogen / besonders schützenswert / technisch getrennt) |
| **DORA** | Baseline für digitale Betriebsresilienz nach DORA-Anforderungen |
| **EU AI Act** | KI-Governance: Fabric-Einstellungen gegen EU AI Act geprüft |
| **ISO 27001** | Mapping auf ISO 27001:2022 Annex A Controls (A.5–A.8) |
| **Purview** | Sensitivity Labels (Graph API) + Schutzmaßnahmen-Abdeckung (Scanner API) |
| **Fabric Übersicht** | Kapazitäten, Workspaces, Admins, Gateways, Lakehouse-Rollen (read-only) |
| **Azure** | ARM-Ressourcen, Netzwerksicherheit, Cost Management (opt-in) |

---

## Systemvoraussetzungen

- Windows 10 / 11 (64-Bit)
- Microsoft Entra ID — Fabric-Administrator-Konto oder Compliance-Reviewer-Account
- Internetzugang zur Microsoft Fabric Admin API

---

## Download & Installation

1. Aktuelle Version unter [Releases](../../releases) herunterladen
2. `FabricKeeper_Setup_<version>.exe` ausführen
3. App-Registrierung einmalig im eigenen Tenant durchführen (siehe unten)
4. Lizenzdatei `license.lic` in `%LOCALAPPDATA%\FabricKeeper\` ablegen

### App-Registrierung (einmalig)

Vor dem ersten Start muss die App als Entra-ID-Applikation registriert werden.
Das mitgelieferte PowerShell-Script `Register-FabricApp.ps1` erledigt dies automatisch:

```powershell
# Azure CLI muss installiert sein (https://aka.ms/install-azure-cli)
az login
.\Register-FabricApp.ps1 -Mode SingleTenant   # Kunden-Admin betreibt die App selbst
.\Register-FabricApp.ps1 -Mode MultiTenant    # Consultant-Modell: eine App, viele Tenants
```

Das Script gibt `FABRIC_APP_CLIENT_ID` und `FABRIC_TENANT_ID` aus.
Diese Werte beim ersten App-Start eingeben.

---

## Rollen & Berechtigungen

| Rolle | Kann |
|---|---|
| **Fabric Administrator** | Scannen, Einstellungen lesen und schreiben, Overrides setzen |
| **Compliance Reviewer** | Baseline lesen, reviewen, genehmigen, HTML/Excel-Export |

Die Rollenerkennung erfolgt automatisch über einen API-Probe-Call — keine zusätzlichen Entra-Gruppen erforderlich.

---

## Sicherheit & Datenschutz

- Alle Daten bleiben **lokal** auf dem Rechner des Administrators (SQLite, verschlüsselt)
- Kein Cloud-Backend, kein Telemetrie, kein Callback nach Hause
- Jede Tenant-Änderung erfordert Dry-Run + Bestätigungsdialog + automatischen Snapshot
- Rollback jeder Änderung jederzeit möglich

---

## Lizenz

Fabric Keeper ist kommerziell lizenzierte Software.
Ohne Lizenzdatei läuft die App im Trial-Modus (voller Funktionsumfang, Banner-Hinweis).

Lizenzanfragen: [volker.daniel.unihalle@gmail.com](mailto:volker.daniel.unihalle@gmail.com)

---

## Support

Bei Fragen oder Problemen bitte ein [Issue](../../issues) öffnen oder direkt per E-Mail melden.
