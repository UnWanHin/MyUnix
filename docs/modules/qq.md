# QQ on Fedora

QQ belongs in the direct-RPM application category, but it is not currently enabled in `modules/rpm/apps.tsv`.

## Official source observed

Tencent's Linux QQ page loads its current x86_64 RPM URL from this official configuration file:

- Page: <https://im.qq.com/linuxqq/>
- Release configuration: <https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/linuxConfig.js>

On 2026-07-14 the configuration pointed to a Tencent `qqdl.gtimg.cn` RPM URL. Both ordinary `wget` and `wget` with a browser User-Agent plus the QQ-page Referer received HTTP 403 in the automation environment. Therefore the repository has no pinned QQ checksum and will not install QQ from an unverified mirror.

## How to enable it safely

When Tencent provides a URL that works with unattended `wget`, download the exact x86_64 RPM once, calculate `sha256sum`, obtain its RPM package name with `rpm -qp --qf '%{NAME}\n' file.rpm`, and add a seven-column `qq` entry to `modules/rpm/apps.tsv`. Run the test suite, then update this document with the source version and date.
