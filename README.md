# WillowEPS

A PowerShell module for managing printer configurations across Epic Willow EPS servers.  
Designed to support consistent configuration management in multi-environment Epic EPS deployments, while remaining flexible enough for use in any EPS-based infrastructure.

---

## Overview

WillowEPS provides a structured approach to managing and standardizing printer configurations across multiple EPS servers.

The module is built to:
- Centralize printer configuration management
- Improve consistency across environments (Prod / Non-Prod / Testing)
- Reduce manual configuration drift
- Support automation in EPS-related workflows

Although designed for Epic Willow EPS environments, it can be used with any system requiring coordinated printer configuration management across multiple servers. [1](https://github.com/figueroadavid/WillowEPS)  

---

## Features

- Centralized printer configuration management
- Multi-server coordination
- Environment-aware design (supports segmented environments)
- Scriptable and automation-friendly
- Modular PowerShell architecture

---

## Repository Structure


```mermaid
flowchart LR
    Root[WillowEPS Repository]

    Root --> Data[data/]
    Root --> Docs[docs/]
    Root --> Public[public/]
    Root --> Private[private/]
    Root --> PSD1[WillowEPS.psd1]
    Root --> PSM1[WillowEPS.psm1]
    Root --> License[LICENSE]

    Data --> DataDesc[Configuration and data files]

    Docs --> DocsDesc[Documentation and supporting material]

    Public --> PublicDesc[Exported functions available to users]

    Private --> PrivateDesc[Internal helper functions and logic]

    PSD1 --> PSD1Desc[Module manifest and metadata]

    PSM1 --> PSM1Desc[Core module implementation]

    License --> LicenseDesc[Apache 2.0 license]
```

---

## Requirements

- PowerShell 5.1 (assumed baseline)
- Administrative privileges (for printer and service operations)
- Access to target EPS servers

---

## Installation

Clone the repository:

```powershell
git clone https://github.com/figueroadavid/WillowEPS.git
```
