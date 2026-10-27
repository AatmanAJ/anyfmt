# Releasing anyfmt

A release is a `v<version>` tag. `.github/workflows/release.yml` builds the engines and the
Release app, signs and notarizes the DMG, packs the CLI for Homebrew, signs the Sparkle appcast and
publishes all of it as a GitHub release. The app's update feed is
`https://github.com/AatmanAJ/anyfmt/releases/latest/download/appcast.xml`, so publishing the
release is what ships the update.

## One-time setup

Repository secrets (Settings › Secrets and variables › Actions). The workflow's first step fails
fast and names any that are missing.

| Secret | What it is | Where it comes from |
|---|---|---|
| `DEVELOPER_ID` | `Developer ID Application: <Name> (<TEAMID>)` | Apple Developer account, after the certificate is made |
| `TEAM_ID` | 10-character team id | developer.apple.com › Membership |
| `DEVELOPER_ID_CERT_P12_BASE64` | The certificate and its private key, `base64 -i cert.p12` | Keychain Access › export "Developer ID Application" as .p12 |
| `DEVELOPER_ID_CERT_PASSWORD` | The password you gave the .p12 | You |
| `AC_API_KEY_ID` | App Store Connect API key id | App Store Connect › Users and Access › Integrations › Keys (Developer role) |
| `AC_API_ISSUER` | Issuer id shown on that page | Same page |
| `AC_API_KEY_P8` | Contents of `AuthKey_<id>.p8` | Downloaded once when the key is made |
| `SPARKLE_ED_PRIVATE_KEY` | The update-signing key | This Mac's Keychain, see below |

Export the Sparkle key (its Keychain account is still `halo-updates`, from before the rename) and
keep a copy in your password manager. Losing it means existing installs can't verify updates.

```bash
build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys --account halo-updates -x anyfmt-updates-private.key
gh secret set SPARKLE_ED_PRIVATE_KEY -R AatmanAJ/anyfmt < anyfmt-updates-private.key
rm anyfmt-updates-private.key
```

## Each release

1. In `Config/Base.xcconfig`, set `MARKETING_VERSION` (e.g. `1.0.0`) and raise
   `CURRENT_PROJECT_VERSION` by one. Sparkle compares the build number, and the workflow refuses a
   tag whose build number isn't above the previous release's.
2. Add the release to `web/src/data/changelog.ts`.
3. Commit, then tag and push:

   ```bash
   git tag v1.0.0 && git push origin main v1.0.0
   ```

4. Watch the run (`gh run watch -R AatmanAJ/anyfmt`). The first one builds the engines from source
   (about 10 minutes).
5. Download the DMG from the release and check it on a Mac that has never run anyfmt:
   it opens with no Gatekeeper warning (`spctl -a -t open --context context:primary-signature -v anyfmt-1.0.0.dmg`).
6. Homebrew: in the `AatmanAJ/homebrew-tap` repo, update `Casks/anyfmt.rb` and
   `Formula/anyfmt-cli.rb` from `packaging/homebrew/` with the new version and the two SHA-256s
   (`shasum -a 256` on the release's DMG and `anyfmt-cli-<version>-arm64.tar.gz`).
7. Website: set `SITE.version`, `SITE.released: true` and the sizes in `web/src/lib/site.ts`,
   then publish the Base44 app.

## Building a release locally

`make dmg` does the same build. Without `DEVELOPER_ID` it signs ad hoc, which is fine for testing
on this Mac but shows a Gatekeeper warning anywhere else. `packaging/homebrew/make-cli-tarball.sh`
then packs the CLI and prints both SHA-256s, and `packaging/sparkle/make-appcast.sh dist <url>`
writes a signed appcast.
