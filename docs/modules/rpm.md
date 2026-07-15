# Direct RPM applications

`apps.tsv` manages optional applications distributed as RPMs, such as QQ or WeChat when their publishers provide an official Linux RPM and a matching SHA-256 checksum.

Each non-comment line has seven `|`-separated fields:

```text
id|display_name|https_url|sha256|default_or_optional|verification_command|verification_argument
```

The installer downloads with `wget` to a temporary directory, verifies SHA-256, uses `dnf install`, then deletes the download. It rejects HTTP URLs, missing checksums, and shell expressions in verification fields. Do not add unverified third-party mirrors. Downloads show an attempt counter, retry three times by default and have a 10-minute timeout; use `MYUNIX_DOWNLOAD_TIMEOUT_SECONDS` only for a one-run adjustment.

For now the verifier is `rpm`; the installer runs it as `rpm -q <verification_argument>` after installation.

## Managed applications

- **WeChat** is locked to the x86_64 RPM published on the official Tencent Linux download site. The URL is a rolling URL; refresh the lock before use if its SHA-256 no longer matches.
- **FlClash** is locked to the official `chen08209/FlClash` GitHub Release `v0.8.94` x86_64 RPM.
- **QQ** is intentionally not enabled yet. Its official Linux QQ page currently resolves to Tencent CDN links that return HTTP 403 to unattended `wget` in this environment, so a reproducible checksum could not be generated. Do not replace it with a third-party mirror; add it when Tencent provides an automatable official download or checksum.
