# Direct RPM applications

`apps.tsv` manages optional applications distributed as RPMs, such as QQ or WeChat when their publishers provide an official Linux RPM and a matching SHA-256 checksum. `--all` installs every valid optional record; guided installation asks before each optional record. Each record is checked with `rpm -q` before downloading, so rerunning the installer skips applications that are already installed.

Every managed record is re-checked against its publisher whenever this registry changes: GitHub-hosted entries are compared with the repository's latest release tag, and rolling URLs are re-downloaded and re-hashed. The check on 2026-10-01 refreshed the rolling WeChat lock and moved FlClash and Tabby to their latest releases.

Each non-comment line has seven `|`-separated fields:

```text
id|display_name|https_url|sha256|default_or_optional|verification_command|verification_argument
```

The installer downloads with `wget` to a temporary directory, verifies SHA-256, uses `dnf install`, then deletes the download. It rejects HTTP URLs, missing checksums, and shell expressions in verification fields. Do not add unverified third-party mirrors. Downloads show an attempt counter, retry three times by default and have a 10-minute timeout; use `MYUNIX_DOWNLOAD_TIMEOUT_SECONDS` only for a one-run adjustment.

For now the verifier is `rpm`; the installer runs it as `rpm -q <verification_argument>` after installation.

## Managed applications

- **AMD GPU Top** is the AMD GPU monitor the DMS `amdGpuMonitor` widget shells out to. Fedora does not package it, so it is locked to the official `Umio-Yasuno/amdgpu_top` GitHub Release `v0.11.5` x86_64 RPM. It is optional because it is only useful on a machine with an AMD GPU, but `--all` installs it so the widget works on a restored workstation. `modules/niri-dms` configures the widget and never installs this RPM itself.
- **WeChat** is locked to the x86_64 RPM published on the official Tencent Linux download site. The URL is a rolling URL; its lock was refreshed on 2026-10-01 for Tencent build `4.1.13.23-1`, which replaced the previously pinned build in place. Refresh the lock again before use if its SHA-256 no longer matches.
- **FlClash** is locked to the official `chen08209/FlClash` GitHub Release `v0.8.98` x86_64 RPM.
- **Tabby** is locked to the official `Eugeny/tabby` GitHub Release `v1.0.237` x86_64 RPM. Its installed RPM package is `tabby-terminal`; verify it with `rpm -q tabby-terminal`.
- **QQ** is intentionally not enabled yet. Its official Linux QQ page currently resolves to Tencent CDN links that return HTTP 403 to unattended `wget` in this environment, so a reproducible checksum could not be generated. Do not replace it with a third-party mirror; add it when Tencent provides an automatable official download or checksum.
- **Feishu** uses a short-lived signed official CDN URL. It is documented as a
  verified manual RPM workflow rather than added to `apps.tsv`, because an
  expiring URL would make one-click installation unreliable. See
  [Feishu](feishu.md).
