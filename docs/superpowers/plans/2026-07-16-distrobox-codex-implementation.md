# Distrobox Codex Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install a container-native Codex CLI for ROS work without storing credentials in MyUnix.

**Architecture:** A Fedora-side module dispatches one bootstrap script into an existing Distrobox. The bootstrap installs a checksum-verified Node.js archive and the official npm Codex package under `/opt/myunix`, then exposes a container-only `/usr/local/bin/codex` wrapper. Shared home-directory authentication remains untouched.

**Tech Stack:** Bash, Distrobox, Node.js release archives, npm.

## Global Constraints

- The container default is `ubuntu22`; override it only with `MYUNIX_CODEX_CONTAINER`.
- Do not read, print, copy, or commit Codex authentication files or API keys.
- Verify the Node archive with the upstream `SHASUMS256.txt` before extraction.
- Do not modify Fedora's Node.js or its `codex` executable.

---

### Task 1: Add the module contract and regression test

**Files:**
- Create: `modules/distrobox-codex/install.sh`
- Create: `tests/test_distrobox_codex.sh`

- [ ] **Step 1: Write the failing test**

Assert that `install_distrobox_codex` dispatches `distrobox enter ubuntu22 -- env`
and passes a bootstrap path, and that `distrobox_codex_container_name` respects
`MYUNIX_CODEX_CONTAINER`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_distrobox_codex.sh`

- [ ] **Step 3: Implement the module**

Provide `distrobox_codex_container_name`, validation for `distrobox`, and a
dispatcher that runs `container-bootstrap.sh` in the selected container.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/test_distrobox_codex.sh`

### Task 2: Add a checksum-verified container bootstrap

**Files:**
- Create: `modules/distrobox-codex/container-bootstrap.sh`
- Modify: `tests/test_distrobox_codex.sh`

- [ ] **Step 1: Extend the failing test**

Assert that the bootstrap downloads Node's `SHASUMS256.txt`, calls `sha256sum
--check`, installs `@openai/codex`, writes `/usr/local/bin/codex`, and exports
`CODEX_HOME=/opt/distrobox/ubuntu22/.codex` without copying `auth.json`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test_distrobox_codex.sh`

- [ ] **Step 3: Implement the bootstrap**

Resolve the newest Node 22 release from the official index, checksum-verify
the x64 archive, install it under `/opt/myunix`, install the npm CLI there,
and install a wrapper which executes the container-local Node runtime.

- [ ] **Step 4: Run focused validation**

Run: `bash tests/test_distrobox_codex.sh && bash -n modules/distrobox-codex/*.sh`

### Task 3: Register and document the public entry point

**Files:**
- Modify: `scripts/myunix`
- Modify: `README.md`
- Modify: `docs/modules/distrobox.md`

- [ ] **Step 1: Register the module**

Source `modules/distrobox-codex/install.sh` and add `distrobox-codex` to the
module dispatcher without adding it to the all-install path.

- [ ] **Step 2: Document safe authentication behavior**

Add the direct install command, container entry command, and the rule that
authentication is shared through `$HOME` and is never exported by MyUnix.

- [ ] **Step 3: Run regression checks**

Run: `bash tests/test_distrobox_codex.sh && bash -n scripts/myunix modules/distrobox-codex/*.sh && git diff --check`
