# ToDesk Main Window Mode Experiment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Test whether ToDesk's undocumented new main-window mode removes the fixed-size restriction without changing system display-manager or Niri configuration.

**Architecture:** The experiment changes exactly one ToDesk-private INI value after making a timestamped backup. The client is restarted and inspected through Niri IPC. A failed startup or unchanged fixed-size behavior restores the backup immediately. Neither the backup nor the private INI is committed to MyUnix.

**Tech Stack:** Bash, `sed`, Niri IPC, ToDesk RPM.

## Global Constraints

- Change only `/opt/todesk/config/config.ini` key `settingnewmaindlgmode`.
- Preserve the backup outside the repository under `~/.local/state/myunix/backups/todesk/`.
- Do not change GDM, greetd, Niri KDL, ToDesk account data, or the packaged launcher.
- Never commit ToDesk private configuration or its backup.

---

### Task 1: Test the new ToDesk main-window mode

**Files:**
- Modify outside Git: `/opt/todesk/config/config.ini`
- Create outside Git: `~/.local/state/myunix/backups/todesk/config.ini.<timestamp>`
- Verify: running ToDesk window via `niri msg windows`

**Interfaces:**
- Consumes: `settingnewmaindlgmode=0` in the existing ToDesk configuration.
- Produces: either a running ToDesk client with a resizable main window, or a restored configuration with the original fixed-size client.

- [ ] **Step 1: Confirm the original package and setting**

Run:

```bash
rpm -V todesk
grep -x 'settingnewmaindlgmode          = 0' /opt/todesk/config/config.ini
```

Expected: no output from `rpm -V`; the `grep` command prints the original mode line.

- [ ] **Step 2: Back up the private configuration**

Run:

```bash
backup_dir="$HOME/.local/state/myunix/backups/todesk"
mkdir -p "$backup_dir"
backup="$backup_dir/config.ini.$(date +%Y%m%d-%H%M%S)"
cp -a /opt/todesk/config/config.ini "$backup"
printf '%s\n' "$backup"
```

Expected: a timestamped backup path outside the repository.

- [ ] **Step 3: Change only the main-window mode**

Run:

```bash
sed -i 's/^settingnewmaindlgmode[[:space:]]*=.*/settingnewmaindlgmode          = 1/' /opt/todesk/config/config.ini
grep -x 'settingnewmaindlgmode          = 1' /opt/todesk/config/config.ini
```

Expected: exactly one printed line showing mode `1`.

- [ ] **Step 4: Restart ToDesk and inspect its Niri state**

Run:

```bash
pkill -x ToDesk
gtk-launch todesk
sleep 3
niri msg windows
```

Expected: a ToDesk window appears. Manually test `Super` plus right-mouse drag; if the dimensions change, record success without exporting the private setting.

- [ ] **Step 5: Restore on failure**

If ToDesk fails to start or remains fixed-size, run:

```bash
cp -a "$backup" /opt/todesk/config/config.ini
pkill -x ToDesk || true
gtk-launch todesk
```

Expected: ToDesk returns to its original main-window mode.

- [ ] **Step 6: Commit only public record updates after verification**

Do not add `/opt/todesk/config/config.ini` or the backup. Commit the incident record and documentation only after the result is known.

```bash
git add docs/records docs/modules README.md docs/superpowers/specs docs/superpowers/plans
git diff --staged --check
git diff --staged | rg -i 'password|secret|api[_-]?key|token|private.?key'
git commit -m "docs: record Niri greeter recovery and ToDesk compatibility"
git push origin fedora
```
