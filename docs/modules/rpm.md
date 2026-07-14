# Direct RPM applications

`apps.tsv` manages optional applications distributed as RPMs, such as QQ or WeChat when their publishers provide an official Linux RPM and a matching SHA-256 checksum.

Each non-comment line has seven `|`-separated fields:

```text
id|display_name|https_url|sha256|default_or_optional|verification_command|verification_argument
```

The installer downloads with `wget` to a temporary directory, verifies SHA-256, uses `dnf install`, then deletes the download. It rejects HTTP URLs, missing checksums, and shell expressions in verification fields. Do not add unverified third-party mirrors.

For now the verifier is `rpm`; the installer runs it as `rpm -q <verification_argument>` after installation.
