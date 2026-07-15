# Development Toolchain: DNF Migration

The development-toolchain module now uses Fedora official DNF packages for
OpenJDK and CMake. Its Java selection is intentionally unpinned so rerunning
the module follows Fedora's current supported OpenJDK:

- `java-latest-openjdk-headless` and `java-latest-openjdk-devel` provide Java
  and Javac from the current Fedora repository. The reference-machine snapshot
  was Java/Javac 25.0.3.
- `cmake` is Fedora's current CMake package. The reference-machine snapshot
  was CMake 4.3.0.

The prior upstream JDK 26/CMake 4.4 installs under `/opt`, their
`/usr/local/bin` links and manual Java alternatives management are no longer
part of MyUnix. Fedora RPM scripts own Java alternatives. Do not configure
`javac` as a manual slave of `java`; repair a legacy broken setup with:

```bash
sudo dnf reinstall java-latest-openjdk-headless java-latest-openjdk-devel
```

Anaconda remains separate because Fedora does not provide the full Anaconda
distribution. It stays at `/opt/anaconda3` for system scope or
`~/.local/opt/anaconda3` for user scope, without automatic base activation.

The user-maintained `~/temp/MIGRATION-TO-DNF.md` is the source observation for
this record and is intentionally not managed or modified by MyUnix.
