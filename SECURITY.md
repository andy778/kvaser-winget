# Security Policy

## Scope

Tooling repo only — scrapes Kvaser's download page, verifies checksums, generates winget manifests. No drivers hosted here.

**In scope:** script executing unexpected code, compromised GitHub Action, checksum bypass, accidentally committed secrets.  
**Out of scope:** bugs in Kvaser drivers, winget/wingetcreate, Kvaser's download infrastructure.

Kvaser driver vulnerabilities → [kvaser.com/contact](https://kvaser.com/contact/).

## Supported Versions

`main` only. No older commits supported.

## Reporting

Do not open a public issue.

Use [GitHub private vulnerability reporting](https://github.com/andy778/kvaser-winget/security/advisories/new) or email **andreas.back778@gmail.com** (subject: `[kvaser-winget] Security`).

Include: what, where (file/line), steps to reproduce, impact.

## Response

Personal repo, best-effort.

## Disclosure

Fix ships as a [GitHub Security Advisory](https://github.com/andy778/kvaser-winget/security/advisories). Reporter credited unless anonymous preferred.
