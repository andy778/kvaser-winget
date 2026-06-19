# Kvaser Drivers — winget packaging

Tooling and [WinGet](https://learn.microsoft.com/windows/package-manager/) manifests for
packaging the **Kvaser Drivers for Windows** (CANlib driver setup) so they can be installed with:

```powershell
winget install Kvaser.CANDrivers
```

The Kvaser download page lists every released driver version. The script in this repo scrapes
that page, verifies each installer against Kvaser's published **MD5**, and prepares the
**SHA256**-based metadata that `wingetcreate` / the winget manifest format requires.

> **Note:** Kvaser's drivers are **proprietary** (Kvaser AB EULA — free to download, not open
> source). This repository contains only packaging metadata and tooling; it does **not** host or
> redistribute the installers themselves. See [License](#license).

## Contents

| Path | What it is |
|------|------------|
| [`Prepare-KvaserWinget.ps1`](Prepare-KvaserWinget.ps1) | Scrapes the Kvaser download page, verifies MD5, emits/runs `wingetcreate`. |
| [`manifests/`](manifests/) | The winget manifest (`Kvaser.CANDrivers`, version 5.52.559). |
| [`installers.csv`](installers.csv) | Snapshot of every version found: `Version,File,Url,Md5`. |

## Requirements

- Windows 10/11, PowerShell 5.1+
- [`winget`](https://learn.microsoft.com/windows/package-manager/winget/) (App Installer)
- [`wingetcreate`](https://github.com/microsoft/winget-create) — `winget install Microsoft.WingetCreate`
- (Optional) Windows Sandbox, to test installs — see below.

## Usage

```powershell
# List all installer URLs + MD5s, write installers.csv, print the wingetcreate
# command for the LATEST version (default = `update`):
.\Prepare-KvaserWinget.ps1

# Same, but for every version on the page:
.\Prepare-KvaserWinget.ps1 -All

# Download the latest installer, verify it against Kvaser's published MD5,
# and compute its SHA256:
.\Prepare-KvaserWinget.ps1 -Download

# FIRST-TIME publish of a new package (emits `wingetcreate new`):
.\Prepare-KvaserWinget.ps1 -Create -Run

# Bump an EXISTING winget package to the latest version (emits `wingetcreate update`):
.\Prepare-KvaserWinget.ps1 -Run
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `-DownloadId` | Kvaser `download_id` to scrape (default `1011691573` = Kvaser Drivers for Windows). |
| `-PackageIdentifier` | winget PackageIdentifier (default `Kvaser.Drivers`). |
| `-All` | Operate on every version, not just the latest. |
| `-Download` | Download the installer(s), verify MD5, compute SHA256. |
| `-Create` | Emit `wingetcreate new` (first publish) instead of `update`. |
| `-Run` | Actually invoke `wingetcreate` instead of only printing the command. |

`-All` cannot be combined with `-Run` or `-Create` (you publish one version at a time).

### MD5 vs SHA256

- **MD5** is what Kvaser publishes on the download page. The script uses it only to **verify the
  download** is intact/authentic.
- **SHA256** is what the winget manifest schema requires (`InstallerSha256`). The script computes
  this for the manifest. MD5 has no valid place in a winget manifest.

## Testing in Windows Sandbox

Microsoft ships an official tester in the `winget-pkgs` repo. It is **not** vendored here (so it
always matches upstream); download it on demand:

```powershell
# 1. Enable Windows Sandbox once (elevated PowerShell), then reboot:
Enable-WindowsOptionalFeature -FeatureName "Containers-DisposableClientVM" -All -Online

# 2. Get Microsoft's tester:
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/Tools/SandboxTest.ps1" -OutFile SandboxTest.ps1

# 3. Validate + install the manifest in a clean, disposable VM:
.\SandboxTest.ps1 -Manifest "manifests\k\Kvaser\CANDrivers\5.52.559"
```

It validates the manifest, installs winget inside a throwaway sandbox, runs
`winget install -m` against the manifest (downloading the real installer and checking the SHA256),
and diffs the installed-programs table to confirm success.

## Submitting to winget-pkgs

The manifests under `manifests/` can be submitted to
[microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs):

```powershell
wingetcreate submit "manifests\k\Kvaser\CANDrivers\5.52.559" --token <github-pat>
```

## License

- **This repository** (the `Prepare-KvaserWinget.ps1` script, manifests, and docs):
  [MIT](LICENSE).
- **`SandboxTest.ps1`**: © Microsoft, MIT — from
  [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs); not included here.
- **Kvaser drivers**: proprietary, © Kvaser AB, Mölndal, Sweden —
  [License and Copyright](https://kvaser.com/canlib-webhelp/page_license_and_copyright.htm).
  Not redistributed by this repository.
