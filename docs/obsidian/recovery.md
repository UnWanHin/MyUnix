# Migration and recovery

Start from [[workstation]] and use the repository commands rather than copying
unreviewed files between machines.

```bash
./scripts/myunix doctor
./scripts/myunix export
./scripts/myunix install --guided
./scripts/myunix install --module niri-dms
./scripts/myunix install --module input-method
./scripts/myunix retry
```

`export` writes only public configuration into the owning module. Review the
Git diff before committing. Package and repository changes are intentionally
separate from user-session settings; an input-method or Niri change should not
need `sudo` after package installation is complete.

For phone support, run the separate [[../modules/phone-connect|Phone Connect]]
module and pair the phone again on the new computer. For the layout and
shortcut boundaries, see [[session]] and [[modules]].

#recovery #export #install #doctor
