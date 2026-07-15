# Input-Method Application Adapters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make known Qt/Electron application input-method launchers reproducible through MyUnix.

**Architecture:** `modules/input-method/app-profiles.tsv` is an explicit allowlist. The installer copies an installed system desktop file into the XDG user applications directory and rewrites only `Exec=` with the selected compatibility profile. It leaves all unregistered apps and global GTK behavior unchanged.

**Tech Stack:** Bash, freedesktop desktop-entry files, existing MyUnix shell tests.

## Global Constraints

- Profiles: `qt-fcitx` for WeChat, `electron-wayland-ime` for QQ.
- Use user overrides in `~/.local/share/applications`; never edit `/usr/share/applications`.
- Skip absent applications successfully; back up an existing user override before replacement.
- Keep profiles explicit, tested, and documented; never apply a generic override to every app.

---

### Task 1: Add a failing compatibility-launcher test and registry

**Files:**

- Create: `modules/input-method/app-profiles.tsv`
- Modify: `tests/test_input_method.sh`

- [ ] **Step 1: Add test desktop files for WeChat, QQ, and a missing app.** Run `install_input_method_app_overrides` with a temporary applications source and XDG data directory. Assert the generated WeChat `Exec=` is `env XMODIFIERS=@im=fcitx QT_IM_MODULE=fcitx QT_IM_MODULES=fcitx /usr/bin/wechat %U`; assert QQ has `ELECTRON_OZONE_PLATFORM_HINT=auto`, `--enable-wayland-ime`, and `%U`; assert missing desktop files create no override.

- [ ] **Step 2: Run `bash tests/test_input_method.sh`; expect failure because the function and registry are missing.**

- [ ] **Step 3: Create `app-profiles.tsv` with four columns: id, desktop filename, profile, executable.** Add WeChat and QQ only.

### Task 2: Implement profile transforms and installer integration

**Files:**

- Modify: `modules/input-method/install.sh`
- Modify: `tests/test_input_method.sh`

- [ ] **Step 1: Implement `input_method_app_profiles_path`, `input_method_system_applications_dir`, `input_method_user_applications_dir`, `backup_input_method_launcher`, `render_input_method_launcher`, and `install_input_method_app_overrides`.**

`render_input_method_launcher` rewrites each non-comment `Exec=` line using only the two named profiles. It rejects an unknown profile with `die`. It uses `awk` and copies all non-Exec desktop-entry lines unchanged. A profile is applied only when its source launcher exists.

- [ ] **Step 2: Call `install_input_method_app_overrides` at the end of `install_input_methods`.**

- [ ] **Step 3: Extend tests to rerun the installer and verify only one compatibility prefix appears plus a backup of a pre-existing user launcher.**

- [ ] **Step 4: Run `bash tests/test_input_method.sh && bash tests/run.sh && bash -n modules/input-method/install.sh`; expect exit 0.**

### Task 3: Record the migration behavior

**Files:**

- Modify: `docs/modules/input-method.md`
- Modify: `docs/records/2026-07-14-niri-dms-cangjie.md`
- Modify: `README.md`

- [ ] **Step 1: Document the app profiles, rerun command, XDG user-launcher location, backup path, no-global-GTK policy, and exclusions.**

- [ ] **Step 2: Link the Cangjie incident to the Qt/Electron launcher layer and add the input-method rerun command to the README.**

- [ ] **Step 3: Run the complete suite, all Bash syntax checks, ShellCheck if installed, and `git diff --check`; report branch and status.**
