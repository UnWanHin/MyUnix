# Development Toolchain Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the verified Fedora development toolchain reproducible as an optional, scope-aware MyUnix module.

**Architecture:** `modules/development-toolchain` owns component manifests, installers, shell integration and verification. `scripts/myunix` only presents the sequential custom wizard and dispatches the module.

**Tech Stack:** Bash, DNF, curl, tar, Fedora alternatives, XDG user directories and MyUnix UI selectors.

## Global Constraints

- Do not touch, move or commit `~/temp` files.
- One-click installation excludes the development toolchain.
- User scope applies only to Anaconda; OpenJDK, CMake and Fedora compiler/runtime packages remain DNF system packages.
- Fixed upstream downloads use HTTPS and a temporary directory; never retain binaries in Git.
- The existing portal-login module remains independent and included in this synchronization.

---

### Task 1: Model toolchain components and paths

**Files:**
- Create: `modules/development-toolchain/packages.tsv`
- Create: `modules/development-toolchain/install.sh`
- Create: `tests/test_development_toolchain.sh`

- [ ] Add failing tests for component parsing/deduplication and scope validation.
- [ ] Implement a component registry covering build tools, JDK, CMake, Ninja,
  Rust, Python, Anaconda, Node, Go, GCC and Clang.
- [ ] Test the resolver and run Bash syntax validation.

### Task 2: Add portable installers and shell integration

**Files:**
- Create: `modules/development-toolchain/config/sysrc.d/development-toolchain.rc`
- Create: `modules/development-toolchain/verify.sh`
- Modify: `modules/development-toolchain/install.sh`
- Modify: `modules/shell-config/config/.sysrc`
- Modify: `modules/shell-config/install.sh`
- Modify: `modules/shell-config/export.sh`
- Modify: `tests/test_shell_config.sh`

- [ ] Test user-path rendering and backup behaviour.
- [ ] Implement system `/opt` and user `~/.local/opt` paths for Anaconda,
  retaining DNF for OpenJDK, CMake and the remaining components.
- [ ] Change `.sysrc` to source sorted `sysrc.d/*.rc` fragments and preserve
  managed-fragment export/import behaviour.
- [ ] Run focused tests and syntax checks.

### Task 3: Connect the custom wizard and document migration

**Files:**
- Modify: `scripts/myunix`
- Modify: `tests/test_install_flow.sh`
- Modify: `README.md`
- Create: `docs/modules/development-toolchain.md`

- [ ] Add post-input-method toolchain opt-in, component multi-select and
  system/user single-select screens.
- [ ] Add a noninteractive module interface with documented environment
  variables.
- [ ] Update README and toolchain documentation with sources and scope rules.
- [ ] Run full verification, review secrets and synchronize the verified
  local `fedora` branch.
