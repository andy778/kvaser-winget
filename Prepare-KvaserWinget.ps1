<#
.SYNOPSIS
    Scrapes the Kvaser "single download" page for all driver installer URLs and
    prepares everything needed to publish/update the package with wingetcreate.

.DESCRIPTION
    The Kvaser download page (https://kvaser.com/single-download/?download_id=...)
    lists every released version of an installer. This script:

      1. Downloads the page HTML.
      2. Extracts every installer (.exe) URL plus its version.
      3. Picks the latest version (or --All for every version).
      4. Downloads the chosen installer(s), verifies them against Kvaser's
         published MD5, and computes the SHA256 for the manifest.
      5. Emits a ready-to-run `wingetcreate` command (and can run it with -Run).

    Output (installers.csv with Version/File/Url/Md5, plus the printed
    wingetcreate command) is written next to this script.

.PARAMETER DownloadId
    The download_id query parameter from the Kvaser page. Defaults to the
    Kvaser Drivers for Windows package (1011691573).

.PARAMETER PackageIdentifier
    WinGet PackageIdentifier to target. Default: Kvaser.Drivers

.PARAMETER All
    Emit a wingetcreate command for every version found, not just the latest.

.PARAMETER Download
    Download the selected installer(s) and compute SHA256 (needed for a real
    manifest; wingetcreate also does this itself when it runs).

.PARAMETER Create
    Build a `wingetcreate new` command instead of `update`. Use this for the
    FIRST submission of a package that does not yet exist in the winget repo
    (e.g. Kvaser.CANDrivers). `update` only works once the package is published,
    because it pulls the existing manifest from winget-pkgs to bump it.

.PARAMETER Run
    Actually invoke wingetcreate instead of only printing the command.
    Implies -Download is not required (wingetcreate downloads + hashes itself).

.EXAMPLE
    .\Prepare-KvaserWinget.ps1
    # Lists all URLs, prints the wingetcreate command for the latest version.

.EXAMPLE
    .\Prepare-KvaserWinget.ps1 -Create -Run
    # First-time publish: wingetcreate new <latest-url> --out <dir>

.EXAMPLE
    .\Prepare-KvaserWinget.ps1 -Run
    # Bump an existing package: wingetcreate update Kvaser.Drivers --version <v> --urls <url>
#>
[CmdletBinding()]
param(
    [string]$DownloadId       = '1011691573',
    [string]$PackageIdentifier = 'Kvaser.Drivers',
    [switch]$All,
    [switch]$Download,
    [switch]$Create,
    [switch]$Run
)

$ErrorActionPreference = 'Stop'
$ProgressPreference     = 'SilentlyContinue'   # speeds up Invoke-WebRequest

# -Run actually invokes wingetcreate for the target version. -All expands the
# target set to every version on the page. Combining them would fire one
# `wingetcreate update` per version (47+), which is never what you want -- you
# publish one version at a time. Reject the combination up front.
if ($All -and $Run) {
    throw "-All and -Run cannot be used together: -Run executes wingetcreate for a single target. " +
          "Use -All on its own to list/export every version, or -Run (without -All) to publish the latest."
}
# `new` creates one brand-new package from one installer; there is no sense in
# which you "create" all 47 historical versions at once.
if ($All -and $Create) {
    throw "-All and -Create cannot be used together: 'new' publishes a single new package. " +
          "Drop -All, or use -All on its own to list every version."
}
$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$pageUrl = "https://kvaser.com/single-download/?download_id=$DownloadId"
$ua      = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'

Write-Host "==> Fetching $pageUrl" -ForegroundColor Cyan
$html = (Invoke-WebRequest -Uri $pageUrl -UserAgent $ua -UseBasicParsing).Content

# --- Extract installer URLs -------------------------------------------------
# Kvaser stores assets at .../Product_Resources/<sku>/<version>/<file>.exe
# The <version> path segment is the clean version string (more reliable than
# parsing the filename, which mixes '_' and '.' separators).
$rx = [regex]'https?://[^"'']*?/Product_Resources/\d+/(?<ver>[^/"'']+)/(?<file>[^"'']+?\.exe)'
$matches = $rx.Matches($html)

if ($matches.Count -eq 0) {
    throw "No installer (.exe) URLs found on the page. The page layout may have changed."
}

$items = foreach ($m in $matches) {
    [pscustomobject]@{
        Version = $m.Groups['ver'].Value
        File    = $m.Groups['file'].Value
        Url     = $m.Value
    }
}
$items = $items | Sort-Object Url -Unique

# --- Map the MD5 checksums Kvaser publishes on the page ---------------------
# Each version block renders "MD5: <span>HASH</span>" shortly *before* its
# download URL. Walk MD5/URL tokens in document order, remembering the most
# recent MD5 and attaching it to the version of the next installer URL seen.
function Get-PageMd5Map([string]$html) {
    $map = @{}
    $rx  = [regex]'(?:MD5:\s*<span>\s*(?<md5>[0-9a-fA-F]{32})\s*</span>)|(?:/Product_Resources/\d+/(?<ver>[^/"'']+)/[^"'']+?\.exe)'
    $cur = $null
    foreach ($m in $rx.Matches($html)) {
        if ($m.Groups['md5'].Success) { $cur = $m.Groups['md5'].Value.ToUpperInvariant() }
        elseif ($m.Groups['ver'].Success -and $cur) { $map[$m.Groups['ver'].Value] = $cur }
    }
    return $map
}
$md5Map = Get-PageMd5Map $html
foreach ($it in $items) {
    $it | Add-Member -NotePropertyName Md5 -NotePropertyValue $md5Map[$it.Version]
}
Write-Host ("==> Parsed {0} published MD5 checksums" -f ($items | Where-Object Md5).Count) -ForegroundColor Green

# Sort by version (numeric where possible, falling back to string for tags
# like '4.6.0a'). Build a sortable key.
function Get-VersionKey([string]$v) {
    $parsed = $null
    if ([version]::TryParse(($v -replace '[^\d.]', ''), [ref]$parsed)) { return $parsed }
    return [version]'0.0'
}
$items = $items | Sort-Object @{ Expression = { Get-VersionKey $_.Version } }

Write-Host ("==> Found {0} installer URLs" -f $items.Count) -ForegroundColor Green

# --- Write outputs ----------------------------------------------------------
$csvFile = Join-Path $here 'installers.csv'
$items | Export-Csv -Path $csvFile -NoTypeInformation -Encoding utf8
Write-Host "    installers.csv -> $csvFile"
Write-Host "    (URLs: Import-Csv installers.csv | Select -Expand Url)"

# --- Select target version(s) ----------------------------------------------
$latest = $items[-1]
$targets = if ($All) { $items } else { @($latest) }

Write-Host ""
Write-Host ("==> Latest version: {0}" -f $latest.Version) -ForegroundColor Yellow
Write-Host ("    $($latest.Url)")
Write-Host ""

# --- Optionally download, verify MD5, and compute SHA256 -------------------
# Returns the SHA256 (for the winget manifest). The MD5 is used only to verify
# the download against the checksum Kvaser publishes on the page; the manifest
# itself must use SHA256 (the winget schema requires InstallerSha256).
function Get-InstallerHash($item) {
    $dest = Join-Path $here $item.File
    if (-not (Test-Path $dest)) {
        Write-Host "    downloading $($item.File) ..."
        Invoke-WebRequest -Uri $item.Url -UserAgent $ua -OutFile $dest -UseBasicParsing
    }
    # Verify download integrity against Kvaser's published MD5.
    if ($item.Md5) {
        $md5 = (Get-FileHash -Path $dest -Algorithm MD5).Hash
        if ($md5 -eq $item.Md5) {
            Write-Host "      MD5 OK ($md5)" -ForegroundColor Green
        } else {
            Write-Warning "MD5 MISMATCH for $($item.File): page=$($item.Md5) file=$md5 -- download may be corrupt or tampered."
        }
    } else {
        Write-Warning "No published MD5 found for $($item.File); skipping integrity check."
    }
    (Get-FileHash -Path $dest -Algorithm SHA256).Hash
}

# --- Emit / run wingetcreate ------------------------------------------------
Write-Host "==> wingetcreate command(s):" -ForegroundColor Cyan
foreach ($t in $targets) {
    $sha = $null
    if ($Download) { $sha = Get-InstallerHash $t }

    # Choose the verb:
    #   new    -> first-time publish of a package that isn't in winget yet.
    #             Installer URL is positional; metadata is prompted (or taken
    #             from --out manifests). No --version flag on `new`.
    #   update -> bump an existing package; pulls its manifest from winget-pkgs,
    #             swaps the URL, and recomputes the hash.
    # add '--submit' (and '--token <PAT>') to open a PR against winget-pkgs.
    if ($Create) {
        $cmdArgs = @('new', $t.Url, '--out', $here)
    } else {
        $cmdArgs = @('update', $PackageIdentifier, '--version', $t.Version, '--urls', $t.Url)
    }

    $display = "wingetcreate " + ($cmdArgs -join ' ')
    Write-Host "    $display"
    if ($sha) { Write-Host "      (SHA256: $sha)" -ForegroundColor DarkGray }

    if ($Run) {
        $wc = Get-Command wingetcreate -ErrorAction SilentlyContinue
        if (-not $wc) {
            Write-Warning "wingetcreate not found. Install it with: winget install Microsoft.WingetCreate"
            break
        }
        Write-Host "    running ..." -ForegroundColor Magenta
        & wingetcreate @cmdArgs
    }
}

Write-Host ""
Write-Host "Done. Tips: -Create (first publish, 'new') vs default 'update'; -All to list every version; -Download to verify MD5 + hash; -Run to execute." -ForegroundColor Green
