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

**System** uses Fedora DNF for the current OpenJDK and CMake. Anaconda 2025.12-2 lives
under `/opt/anaconda3`, with `/usr/local/bin/conda` and `/etc/profile.d`
integration.

**User** still uses Fedora DNF for the current OpenJDK and CMake, because Fedora owns
their alternatives and system integration. Only Anaconda is placed under
`~/.local/opt`, with a command link in `~/.local/bin`. It installs a reviewed
`~/.config/sysrc.d/development-toolchain.rc` file so Bash and Zsh expose those
tools after the existing shared shell configuration is installed. Ninja,
Rust/Cargo, Python development packages, Node.js, Go, GCC, Clang and Build
tools are also Fedora DNF system packages in both modes.

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
| OpenJDK / Javac | 25.0.3 (recorded snapshot) | Fedora DNF: `java-latest-openjdk-headless`, `java-latest-openjdk-devel` |
| CMake | 4.3.0 | Fedora DNF: `cmake` |
| Ninja | 1.13.2 | Fedora DNF |
| Rust / Cargo | 1.96.1 | Fedora DNF |
| Python | 3.14.6 | Fedora DNF |
| Anaconda | 25.11.1 | Official Anaconda archive 2025.12-2 |
| Node.js | 22.22.2 | Fedora DNF |
| Go | 1.26.5 | Fedora DNF |
| GCC | 16.1.1 | Fedora DNF |
| Clang | 22.1.8 | Fedora DNF |

The recorded versions are a Fedora 44 snapshot, not immutable locks. The Java
manifest deliberately uses Fedora's `java-latest-openjdk*` packages, so a
future rerun follows the current official Fedora OpenJDK. CMake likewise stays
on Fedora's unpinned `cmake` package. Java alternatives are owned by Fedora
RPM packages: never manually add `javac` as a slave to the `java` alternatives
entry. If a prior custom JDK left alternatives broken, use the documented
Fedora repair path:

```bash
sudo dnf reinstall java-latest-openjdk-headless java-latest-openjdk-devel
```

Anaconda is the only upstream archive left in this module. It is fetched over
HTTPS into a temporary directory and never retained in Git. The module never
touches `~/temp`.
