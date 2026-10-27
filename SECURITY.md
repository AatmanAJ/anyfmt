# Security

anyfmt runs on your Mac and converts files that come from anywhere, so bugs in how it reads files
matter. If you find one that could let a crafted file run code, read or write files it shouldn't,
or reach the network, please report it privately.

**Report it here:** [Report a vulnerability](https://github.com/AatmanAJ/anyfmt/security/advisories/new)
(GitHub's private reporting). Only the maintainer sees it. Please include the anyfmt version, your
macOS version, the file or steps that trigger it, and what happens.

You'll get a reply within a week. Fixes ship as a normal release, and the advisory is published
once most people have updated. Please don't open a public issue for it first.

Bugs in a bundled engine (FFmpeg, x264, x265, libvpx, resvg and the others in
`Engines/VERSIONS.md`) are welcome here too; we'll update the pinned version and tell upstream.
