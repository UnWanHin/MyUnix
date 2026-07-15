# Development Toolchain

This optional module reproduces the Fedora development environment recorded
from the reference setup. It is not included in one-click installation.

```bash
./scripts/myunix install --module development-toolchain
```

The custom installer asks about input methods first, then offers a separate
Development Toolchain step. In that step, select any combination of Build
tools, JDK, CMake, Ninja, Rust/Cargo, Python development packages, Anaconda,
Node.js, Go, GCC and Clang.

## Scope

**System** mirrors the reference installation: Fedora packages use DNF; JDK
26.0.1, CMake 4.4.0 and Anaconda 2025.12-2 live under `/opt`. JDK uses Fedora
`alternatives`; CMake and Conda receive `/usr/local/bin` links and
`/etc/profile.d` integration.

**User** places only JDK, CMake and Anaconda under `~/.local/opt`, with command
links in `~/.local/bin`. It installs a reviewed
`~/.config/sysrc.d/development-toolchain.rc` file so Bash and Zsh expose those
tools after the existing shared shell configuration is installed. Ninja,
Rust/Cargo, Python development packages, Node.js, Go, GCC, Clang and Build
tools remain Fedora DNF system packages in both modes.

For a deterministic module invocation:

```bash
MYUNIX_TOOLCHAIN_SCOPE=user \
MYUNIX_TOOLCHAIN_COMPONENTS=jdk,cmake,anaconda \
./scripts/myunix install --module development-toolchain
```

Omit `MYUNIX_TOOLCHAIN_COMPONENTS` to select all components with the given
scope. Run the module verifier at any time:

```bash
modules/development-toolchain/verify.sh
```

## Recorded versions and sources

| Tool | Recorded version | Installation source |
| --- | --- | --- |
| OpenJDK / Javac | 26.0.1 | Official OpenJDK GA archive |
| CMake | 4.4.0 | Official Kitware GitHub release installer |
| Ninja | 1.13.2 | Fedora DNF |
| Rust / Cargo | 1.96.1 | Fedora DNF |
| Python | 3.14.6 | Fedora DNF |
| Anaconda | 25.11.1 | Official Anaconda archive 2025.12-2 |
| Node.js | 22.22.2 | Fedora DNF |
| Go | 1.26.5 | Fedora DNF |
| GCC | 16.1.1 | Fedora DNF |
| Clang | 22.1.8 | Fedora DNF |

Official references: <https://jdk.java.net/26/>,
<https://cmake.org/download/>, and <https://repo.anaconda.com/archive/>.

The DNF versions are a verified Fedora 44 snapshot, not immutable locks; a
future Fedora repository can provide newer versions. OpenJDK and CMake use
pinned official SHA-256 values before installation. Anaconda's official archive
listing for this release does not publish an adjacent SHA-256 file, so the
module fetches it only from `repo.anaconda.com` over HTTPS; this limitation is
intentional and documented rather than hidden. All archives use a temporary
directory and are never retained in Git. The module never touches `~/temp`.
