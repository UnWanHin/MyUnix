# ToDesk direct-RPM design

## Goal

Add the official ToDesk Linux x86_64 RPM to MyUnix as a reproducible optional
desktop application, and install the verified package on this Fedora workstation.

## Scope and placement

- Keep ToDesk in the existing `rpm` module; do not create a separate module.
- Offer it only in custom installation as an optional desktop application. It
  is not part of the one-click baseline.
- Use ToDesk's versioned official HTTPS RPM URL and a pinned SHA-256 in
  `modules/rpm/apps.tsv`.
- Download into a temporary directory, verify the checksum, install with DNF,
  run `rpm -q todesk` as verification, then remove the downloaded RPM.

## Download constraint

The official CDN may return a browser-verification HTML document to unattended
`wget`. The installer must never treat this as an RPM or bypass the challenge.
It will fail safely and explain that the user must obtain the identical
versioned RPM through the official download page before retrying. The manifest
remains checksum-pinned so a browser-provided file can be verified before any
installation.

## Validation

- Extend RPM tests to cover the ToDesk manifest record, optional prompt
  metadata, HTTPS URL, 64-character SHA-256, and safe failure on an invalid
  download.
- Run the project suite, Bash syntax checks, and ShellCheck where available.
- Confirm the installed package with `rpm -q todesk`.

## Security boundary

No RPM binary, account data, browser cookie, or challenge token is committed.
Only the public versioned URL and SHA-256 are retained in Git.
