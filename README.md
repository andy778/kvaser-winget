# Kvaser Drivers — winget packaging

[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/andy778/kvaser-winget/badge)](https://scorecard.dev/viewer/?uri=github.com/andy778/kvaser-winget)

PowerShell tooling to scrape the Kvaser download page, verify installers, and generate
winget manifests for `Kvaser.CANDrivers`.

> Kvaser drivers are **proprietary** (Kvaser AB EULA). This repo contains tooling only —
> no installers are hosted or redistributed.

## Requirements

- Windows 10/11, PowerShell 5.1+
- [`winget`](https://learn.microsoft.com/windows/package-manager/winget/)
- [`wingetcreate`](https://github.com/microsoft/winget-create): `winget install Microsoft.WingetCreate`
- Windows Sandbox (for local install test): see [Testing](#testing-in-windows-sandbox)

## Generate a manifest

```powershell
# Latest version only:
.\Prepare-KvaserWinget.ps1 -GenerateManifests

# All versions (~1 GB download, local testing only — do NOT submit full history to winget-pkgs):
.\Prepare-KvaserWinget.ps1 -All -GenerateManifests
```

Output: `manifests\k\Kvaser\CANDrivers\<version>\` — three YAMLs (installer, locale, version).

The script does in one pass:
1. Fetches the Kvaser download page.
2. Extracts version, URL, and published MD5 for each release.
3. Downloads the installer and **verifies MD5** against Kvaser's published checksum.
4. Computes **SHA256** (required by winget — `InstallerSha256`).
5. Writes the three manifest YAMLs with correct metadata (see [Fixes](#fixes-applied-vs-raw-wingetcreate-output)).

## Validate

```powershell
winget validate "manifests\k\Kvaser\CANDrivers\5.52.559"
```

## Testing in Windows Sandbox

Enable Sandbox once (elevated PowerShell, then reboot):
```powershell
Enable-WindowsOptionalFeature -FeatureName "Containers-DisposableClientVM" -All -Online
```

Download Microsoft's official test script:
```powershell
Invoke-WebRequest "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/Tools/SandboxTest.ps1" -OutFile SandboxTest.ps1
```

Run the test (clean VM, installs winget inside, runs `winget install -m`, diffs ARP table):
```powershell
.\SandboxTest.ps1 -Manifest "manifests\k\Kvaser\CANDrivers\5.52.559"
```

GitHub token warning from SandboxTest is harmless — only affects API rate limits.
To silence: `$env:WINGET_PKGS_GITHUB_TOKEN = "your_pat"`.

## Submit to winget-pkgs

```powershell
wingetcreate submit "manifests\k\Kvaser\CANDrivers\5.52.559" --token <github-pat>
```

Branch name in winget-pkgs: `Kvaser.CANDrivers-5.52.559-<uuid>` (set automatically by wingetcreate).

## All script parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-DownloadId` | `1011691573` | Kvaser page `download_id`. |
| `-PackageIdentifier` | `Kvaser.CANDrivers` | winget package ID. |
| `-Architecture` | `x86` | Arch written into installer manifest. |
| `-All` | — | Target every version, not just latest. |
| `-Download` | — | Download + verify MD5 + compute SHA256 without writing manifests. |
| `-GenerateManifests` | — | Write the three YAML files per version. |
| `-Create` | — | Emit `wingetcreate new` (first publish) instead of `update`. |
| `-Run` | — | Execute `wingetcreate` instead of printing the command. |

Invalid combinations: `-All -Run`, `-All -Create` (rejected up front).

### MD5 vs SHA256

MD5 = Kvaser's published checksum, used only to verify the download is intact.  
SHA256 = what the winget schema requires (`InstallerSha256`). MD5 has no place in a winget manifest.

## Fixes applied vs raw `wingetcreate` output

`wingetcreate new` on this package produces several errors that the script corrects:

| Field | Raw output | Fixed value |
|-------|-----------|-------------|
| `PackageIdentifier` | `KvaserAB,Mölndal,Sweden.KvaserCANDrivers` (commas + non-ASCII — invalid) | `Kvaser.CANDrivers` |
| `PackageVersion` | `5.52` (truncated) | `5.52.559` (full path segment) |
| `License` | `MIT License` (wrong) | `Proprietary` |
| `Copyright` | `MÃ¶lndal` (PS 5.1 encoding bug) | `Mölndal` via `[char]0xF6` |
| `LicenseUrl` | missing | `https://kvaser.com/canlib-webhelp/page_license_and_copyright.htm` |
| `PublisherUrl` / `PackageUrl` | missing | `https://kvaser.com/` / `https://kvaser.com/download/` |

## Security

Report vulnerabilities via [GitHub private advisory](https://github.com/andy778/kvaser-winget/security/advisories/new).
See [SECURITY.md](SECURITY.md).

## License

- This repo (script + docs): [MIT](LICENSE)
- `SandboxTest.ps1`: © Microsoft, MIT — not included, fetched on demand from [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs)
- Kvaser drivers: proprietary, © Kvaser AB — [license text](https://kvaser.com/canlib-webhelp/page_license_and_copyright.htm)
