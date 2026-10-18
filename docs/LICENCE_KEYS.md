# Licence keys

Offline-verifiable keys for the paid cloud plans (Pro, Team). Plan decision #4 in `docs/PLAN-PHASE2.md`, Phase E.

**What a key never does:** unlock, limit or change anything that runs on the Mac. Local features are free forever (BUILD.md §9b). A key only feeds the cloud `Entitlements` gate, which is read only in `Sources/Cloud` and `Sources/Wheel/CloudSegments.swift`. `scripts/check-entitlements.sh` (run by `make test`) enforces that.

Code: `Sources/Cloud/Licence/` (`LicenceKey`, `LicenceBase32`, `LicenceVerifier`, `LicenceStore`, `LicenceEntitlements`). Issuing: `scripts/licence-tool.swift`. Tests: `Tests/Unit/App/Cloud/Licence*Tests.swift`.

## Format

```
HALO1-01GQP-8K5F1-R24EK-…-H58HG-2
```

- `HALO1` = format version 1.
- The rest is **Crockford base32** (alphabet `0-9 A-Z` without `I L O U`, no padding), in groups of five for readability, of:

  ```
  UInt16 big-endian payload length  ||  payload (JSON bytes)  ||  Ed25519 signature (64 bytes)
  ```

  The length prefix makes the split unambiguous; the total must be exactly `2 + length + 64` bytes. Leftover base32 bits must be zero.
- Parsing ignores dashes, whitespace and case, and reads Crockford's aliases (`O` → `0`, `I`/`L` → `1`). The store keeps the canonical spelling.

### Payload

Compact JSON, keys sorted, no spaces. This exact byte string is what gets signed:

```json
{"eh":"973dfe463ec85785","exp":1823874097,"iat":1792338097,"kid":"kid-2026-1","lid":"L-4B3R6543N4","plan":"pro","seats":1,"v":1}
```

| key | meaning |
|---|---|
| `v` | payload version, `1` |
| `kid` | signing key id, picks the public key |
| `lid` | licence id (ours, for support and server-side revocation) |
| `plan` | `"pro"` or `"team"` (`"free"` is rejected) |
| `seats` | 1 – 100 000 |
| `iat` | issued at, Unix seconds |
| `exp` | expiry, Unix seconds, or `null` = perpetual. Always present |
| `eh` | optional email hint: first 8 bytes of SHA-256 of the trimmed, lowercased address, as hex. Never the address |

A key is ~300 characters. That's fine for paste; nobody types it.

## Verification (`LicenceVerifier.verify(_:now:)`)

In order, all offline:

1. Decode the string → `malformed` if the prefix, symbols, length or JSON are wrong, or a field is out of range.
2. Look up `kid` in `LicenceTrustedKeys.all` → `unknownKey(kid)`.
3. Ed25519 check (CryptoKit `Curve25519.Signing`) over the payload bytes → `badSignature`.
4. `iat` more than 5 minutes in the future → `notYetValid` (tolerates a slightly slow clock).
5. `now >= exp` → `expired`.
6. Otherwise `valid(Licence)`.

`expired` and `notYetValid` still carry the signed `Licence`, so the UI can say "expired on 3 Mar". Every result has a one-sentence `message`.

## Storage (`LicenceStore`)

- Login Keychain, service `dev.aiwithaj.halo.licence`, account `licence-key`, through the existing `KeychainStore` (not synced to iCloud).
- `activate(_ key) throws -> Licence`: only a key that is **valid now** is stored; anything else throws `LicenceActivationError` (with the verification and a message) and the previously stored key stays.
- `deactivate()`: local removal. A best-effort server revoke when signed in is the caller's job (Phase E).
- `status`, `current` (signed, even if out of date), `active` (valid now), `entitlements`.
- The stored key is re-verified on every read against an injectable clock. A key that later expires, or whose `kid` a later build stops trusting, **stays stored but contributes nothing**.
- `observe(_:)` / `removeObserver(_:)` fire after an activate or deactivate that changed something.
- `connect(to: CloudState)` keeps `CloudSnapshot.licence` in step.

## What changes in the entitlements (and what doesn't)

`CloudSnapshot.entitlements` is now `serverEntitlements.merging(snapshot.licence)`. While the licence is in date:

| | Changes? |
|---|---|
| `plan` | **Yes**: the better of the server's plan and the licence's (free < pro < team). Never lowered |
| `licenceSeats` / `licence` | **Yes**: seat count and licence id, for display |
| `isSignedIn` | No. A key never signs you in |
| `features` / `can(_:)` | No. Still exactly what the server's account payload says. Signed out, every `can(_:)` is false |
| `quotas`, `customDomains`, `usageLine` | No |
| Network | No. A key makes no request and never opens the network gate |

So what a key proves offline is: "this Mac holds a paid Pro/Team licence with N seats". The Settings badge can show the plan without a server. Uploads, share links, sync, inbox and cloud jobs still need sign-in, and the server enforces its own entitlements on every call. A key alone can't upload anything.

When the licence expires, the merge drops it (checked at read time against the wall clock), and the plan falls back to the server's. `CloudSession` republishes on its next state change.

### Exactly what changed in existing files

- `Sources/Cloud/CloudEntitlements.swift`: one stored property, `var licence: LicenceEntitlements? = nil`. Optional, so cached accounts written before it still decode (tested).
- `Sources/Cloud/CloudState.swift`: `CloudSnapshot` gains `var licence: LicenceEntitlements? = nil`, and `entitlements` ends with `.merging(licence)`. With no licence it returns exactly what it did before.
- Not wired yet (others own these): calling `LicenceStore().connect(to: services.state)` once at launch (e.g. in `CloudServices.init` or `CloudIntegration.start`), and the activation UI (onboarding, Settings › Account).

## Key rotation (`kid`)

- Each signing key has an id `kid-YYYY-N`. Public keys live in `LicenceTrustedKeys.all` (`Sources/Cloud/Licence/LicenceVerifier.swift`), base64 raw 32-byte Ed25519.
- Rotate: `swift scripts/licence-tool.swift keygen --kid kid-2027-1`, paste the printed line into `LicenceTrustedKeys.all`, ship, then issue with `--kid kid-2027-1`.
- Keep old entries until every key they signed has expired (perpetual keys: forever).
- To revoke a whole batch (e.g. a leaked private key), delete its entry. Stored keys from it then report `unknownKey` and contribute nothing. Individual licences are revoked server-side by `lid`.

## The development key

`kid-2026-1` is a real key pair made for development and test keys.

- **Public key:** committed in `LicenceTrustedKeys.all`.
- **Private key:** never committed. It's in the login Keychain of the machine that made it, as a generic password, service `dev.aiwithaj.halo.licence-signing`, account `kid-2026-1`, value = base64 of the raw 32-byte key.
- Export it (to move it to another Mac or a password manager):

  ```sh
  security find-generic-password -s dev.aiwithaj.halo.licence-signing -a kid-2026-1 -w
  ```

- Import it on another Mac:

  ```sh
  security add-generic-password -s dev.aiwithaj.halo.licence-signing -a kid-2026-1 \
    -l "Halo licence signing key (kid-2026-1)" -w '<base64>'
  ```

- Or skip the Keychain: `HALO_LICENCE_SIGNING_KEY='<base64>' swift scripts/licence-tool.swift issue …`.
- Before selling real licences, make a production key on a machine you trust (`keygen --kid kid-2027-1`), keep its private half offline, and drop `kid-2026-1` from the table in the release build.

## Issuing keys

```sh
swift scripts/licence-tool.swift issue --plan pro --seats 1 --days 365
swift scripts/licence-tool.swift issue --plan team --seats 10 --days 365 --email buyer@example.com
swift scripts/licence-tool.swift issue --plan pro --perpetual
swift scripts/licence-tool.swift issue --plan pro --days 30 --issued-at 1790000000 --lid L-SUPPORT-1   # fixed test key
swift scripts/licence-tool.swift verify 'HALO1-…'     # prints valid / expired / … and the payload; exit 0 only when valid
```

`--kid` defaults to `kid-2026-1`. The tool reads the private key through `/usr/bin/security` (the item's creator, so there's no Keychain prompt) and reads public keys from `LicenceVerifier.swift`, so there is one table. Its encoder mirrors `LicenceKey`; the golden key in `LicenceKeyTests` (made by the tool) keeps them in step.

## Threat model, honestly

- **A cracked binary can bypass this.** Anyone can patch the verifier, or (it's AGPL) build Halo from source with their own public key in the table. That's acceptable by design:
  - Nothing local is gated, so there is nothing local to steal.
  - Every cloud feature is enforced **server-side** on every request. A forged or patched licence changes a badge on the forger's own Mac and nothing else.
- What the signature does protect: an honest user can't be handed a fake key that looks real in an unmodified build, and keys can't be edited (seats, plan, expiry) without failing verification.
- No secret ships in the app. Only public keys. Extracting them gives nobody the ability to issue keys.
- Private keys are the only thing worth protecting. If one leaks, remove its `kid` and reissue (see rotation).
- Clock: a user can set their clock back to keep an expired key "valid". Same answer: it only affects the local plan badge; the server decides.
- The email hint is a truncated hash, so a key doesn't leak the buyer's address, though a guessed address can be confirmed against it.
