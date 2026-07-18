# Feishu

Feishu is installed on Fedora from the official Linux RPM download at
<https://www.feishu.cn/download>.

## Current verified package

- Package: `bytedance-feishu-stable-7.66.11-0.x86_64`
- RPM filename: `Feishu-linux_x64-7.66.11.rpm`
- SHA-256: `6a21cea401975588bf3f7c69eeb6ffb44c7aef6773483100e655a2a434c88001`
- Verification: `rpm -q bytedance-feishu-stable` and
  `sudo rpm -V bytedance-feishu-stable`

## Reinstallation

The publisher issues a short-lived signed CDN URL from its download page, so
there is no stable HTTPS artifact URL suitable for `modules/rpm/apps.tsv`.
Do not commit that signed URL or an RPM binary. Download the current Linux RPM
from the official page, calculate its SHA-256, then install it from a temporary
directory with DNF:

```bash
tmp="$(mktemp -d)"
cp "$HOME/Downloads/Feishu-linux_x64-<version>.rpm" "$tmp/feishu.rpm"
sudo dnf install -y "$tmp/feishu.rpm"
rm -rf -- "$tmp"
```

After installation, start **Feishu** from DMS or run
`bytedance-feishu-stable`.
