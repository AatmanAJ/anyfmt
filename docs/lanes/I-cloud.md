# Lane I: cloud client

Client side of BUILD.md §9b: sign-in, Keychain, entitlements, the network
gate, share links, cloud jobs, sync, inbox and their UI, all tested end to end
against a local Node mock of `Server/openapi.yaml`. **The server itself is not
built** (AJ's separate build; see `Server/README.md`).

## What was built

| File | Public surface |
|---|---|
| `Server/openapi.yaml` | OpenAPI 3.1 contract: 31 operations (auth with PKCE, me/entitlements, resumable uploads, share links + stats, jobs + SSE + cancel, files, sync with conditional PUT/409, inbox, devices), `Error` schema, Bearer scheme, rate-limit headers |
| `Server/README.md` | Stack options + trade-offs, storage, self-host (compose, env vars, Server URL), security notes, build order for AJ |
| `Tests/Mock/server.mjs`, `README.md` | In-memory implementation of the contract, Node built-ins only, fault injection and test-control endpoints |
| `Sources/Cloud/CloudConfig.swift` | `CloudConfig.defaultServer` (placeholder), client id, redirect URI, chunk size; `CloudServerAddress` (parse/normalise, origin, per-server account key); `CloudLocked` |
| `CloudNetworkGate.swift` | `CloudTrigger` (`user`, `signIn`, `sync`, `inbox`), `CloudAccess`, `CloudNetworkGate.check` |
| `CloudAPIClient.swift` | `actor CloudAPIClient`: the only code that sends HTTP. `send`, `download`, typed endpoints for the whole contract, 401 → single-flight refresh → one retry, error mapping, request logging. `CloudSessionFactory` (injectable URLSession/config) |
| `CloudAuth.swift` | `CloudAuth`: `start()` (opens browser via NSWorkspace), `handleCallback(_ url: URL) -> Bool`, `completeSignIn(callbackURL:)`, `completeSignIn(code:)`, `refreshAccount`, `signOut()`; `CloudPKCE` |
| `KeychainStore.swift` | `KeychainStore` (SecItem generic password, service `"\(Brand.bundleID).cloud"`, account per server, injectable service), `CloudCredentialVault` |
| `CloudEntitlements.swift` | `CloudEntitlements: Entitlements` (Sendable snapshot; signed out → not signed in, `.free`, `can()` false), quotas helpers, `CloudAccount` |
| `CloudState.swift` | `CloudState` (thread-safe snapshot + observers), `CloudPreferences` (UserDefaults: server URL, toggles, cached account, sync bases, notice acknowledgements) |
| `CloudSession.swift` | `@MainActor CloudSession: ObservableObject`: server URL, status, email, plan, entitlements, last error, sync/inbox toggles + folder, server check, sync notices |
| `CloudUploader.swift` | `CloudUploader` (8 MiB chunks, resume from `HEAD` offset, SHA-256 verify, retries with backoff), `CloudUploadLedger` (cross-launch resume), `CloudRetryPolicy` |
| `ShareLinkService.swift` | `ShareLinkService.share(files:options:progress:) -> ShareLinkOutcome`, `links()`, `revoke(_:)`; `ShareLinkOptions`; `CloudUploadNoticeGate` (once per server); `CloudUploadConsent`, `CloudPasteboardWriting` |
| `CloudJob.swift` | `final class CloudJob: Job` (`resourceClass .network`), `CloudJobOperation` (`.convert`, `.tool`, `.transcribe()`, `.upscale()`, `.removeBackgroundHQ`, `forTool(_:options:)`, `wantsCloud(_:)`), `CloudJobPhases` |
| `SyncEngine.swift` | `actor SyncEngine` (`syncNow`, `noteLocalChange`, `resolve`, `reset`), `SyncNamespace`, `SyncDocumentSource` (the app provides/applies local JSON), `SyncConflictNotice` |
| `InboxService.swift` | `actor InboxService` (`refreshSchedule`, `start`, `stop`, `checkNow`) |
| `CloudServices.swift` | `@MainActor CloudServices` composition root: `.shared`, `Environment` for tests, `entitlements`, `handleCallback`, `setSyncSource`, `makeCloudJob` |
| `UI/AccountSettingsView.swift` | Settings › Account |
| `UI/ProExplainerView.swift` | The one calm screen for a Pro segment tapped while signed out (or not in plan) |
| `UI/ShareLinkOptionsView.swift`, `UI/UploadNoticeView.swift` | Link options; the once-per-server "This uploads to {server}" note |
| `UI/CloudStyle.swift` | Token colours (light/dark/increased contrast), `CloudPlanBadge`, `CloudProChip` (Palette.proGold) |
| `UI/CloudPanels.swift` | AppKit glue: `showProExplainer(for:)`, `askShareLinkOptions`, `runShareLink(files:)`, `CloudPanelConsent` |

Screens (offscreen, light/dark/increased-contrast): `docs/screens/cloud-*.png`.

## Decisions (ready for DECISIONS.md)

**D-I1 Sign-in: browser magic link + OAuth 2.0 authorization code with PKCE,
returning via `<scheme>://auth/callback`.** The app opens
`{server}/v1/auth/authorize?…code_challenge…&state…` in the default browser;
the server's page emails a magic link; opening it redirects to
`anyfmt://auth/callback?code&state`, which macOS hands to the app's URL scheme
(already declared). The app checks `state` (constant-time), redeems the code
with its verifier, stores tokens in the Keychain. Why not the alternatives:
- *Sign in with Apple* needs the `com.apple.developer.applesignin` entitlement
  and a provisioning profile on AJ's team, and the server must validate Apple
  identity tokens issued to our bundle/services id. Forks and self-hosters
  would need their own Apple Developer accounts. It ties a self-hostable AGPL
  product to Apple.
- *In-app passkeys* need the Associated Domains entitlement listing every
  relying-party domain at signing time: impossible for arbitrary self-hosted
  servers.
- The browser page belongs to the server, so the server can add passkeys
  (WebAuthn in the browser), Sign in with Apple/Google, or Team SSO later
  with **zero app changes**. The app never sees a password.
- `ASWebAuthenticationSession` doesn't fit magic links: the link opens from
  the mail app in the user's default browser, not in the auth session, so the
  callback has to come through the registered URL scheme anyway.
- If the link is opened on another device, the page shows the code and the
  user types it in (`completeSignIn(code:)`); the verifier still never leaves the Mac.
This mirrors Cap's desktop flow (browser sign-in, deep link back). Cost: a
browser round trip and macOS's "Open anyfmt?" prompt the first time.

**D-I2 One network choke point.** `CloudAPIClient.send`/`download` are the
only places a request can start (a test scans Sources/Cloud to keep it so).
Every call names a `CloudTrigger`; `CloudNetworkGate` allows signed-out
traffic for exactly two user actions: the **Validate** button
(`GET /v1/health`) and redeeming a sign-in the user started. `.sync`/`.inbox`
need the toggle on. The URLSession is created lazily on the first allowed
request; signed out it never exists (tested). Ephemeral configuration, no
cookies, no URL cache.

**D-I3 No request at launch.** Plan/features/quotas are cached per server
(UserDefaults; no secrets) and refreshed only at sign-in, on the Refresh
button, and at the start of each cloud action (fresh quota before
uploading). The only background traffic is what the user opted into: the
inbox poller and sync.

**D-I4 Tokens.** Keychain generic password per server (account =
`host[:port][/path]`), `kSecAttrSynchronizable = false`. Access tokens
refresh 30 s early or on a 401 (single-flight across concurrent requests,
one retry). Refresh tokens rotate; `invalid_grant` signs out locally with a
calm message. Bearer tokens go only to the server's origin; a redirect
delegate strips `Authorization` on cross-origin redirects and refuses http
off-loopback. Credentials' `description` is redacted. Logs carry method,
host+path, status, ms and request id only: never headers, bodies, query
strings or tokens (tested).

**D-I5 Uploads.** Contract is tus-like JSON: declare size + SHA-256, PUT
`Content-Range` chunks of `min(8 MiB, maxChunkSize)`, always resume from the
server's `Upload-Offset` (HEAD) so a drop mid-chunk costs only the lost
bytes; `409 offset_mismatch` carries the real offset; `complete` verifies
the hash. 8 MiB clears S3 multipart's 5 MiB part minimum. A ledger in
Application Support (`anyfmt/Cloud/uploads.json`, ids only) lets a later
attempt or launch resume. A user cancel deletes the server upload (respecting
intent); a network failure keeps it for resume.

**D-I6 Cloud jobs poll** (`pollAfterMs`, floor 500 ms) rather than SSE:
robust across sleep/proxies, one code path; SSE stays optional in the
contract. Progress phases upload 0–45 %, processing 45–90 %, download
90–100 %, monotonic. `clientReference` = job UUID for idempotent create.
Cancel cancels local tasks and posts `/cancel` from a detached task. Results
are downloaded into the job's temp dir, SHA-checked, then placed by
`OutputPlacer` (never overwrites: `clip 2.mp4`; tools get their suffix:
`talk-transcript.srt`). The client strips its own `cloud` option before sending.

**D-I7 Sync** stores opaque JSON per namespace (`favourites`, `wheel-order`,
`presets`, `recipes`, `settings`). Change detection is a SHA-256 of the
key-sorted JSON; the engine keeps the last agreed `(version, hash)` per
namespace per server+user and decides three-way. Writes are conditional
(`If-Match` / `If-None-Match: *`); a 409's body is the server copy, so no
extra GET. Conflict → per-namespace policy (default: keep the server copy)
plus a `SyncConflictNotice` holding the other version for one-click
"Use this Mac's version". Pushes debounce 2 s. Off by default.

**D-I8 Inbox** polls every `max(5 min, server pollIntervalSeconds)` only
while on; downloads to a temp file, verifies SHA-256, sanitises the name
(last path component, no leading dots or control characters), places it with
`OutputNamer.place` (`RENAME_EXCL`, Finder-style `name 2.ext`), then acks.
Delivered ids are remembered so a lost ack never saves a file twice.

**D-I9 Server URL.** https required; http only for loopback (self-host dev
boxes, the mock). Path prefixes kept (reverse proxies). Each server keeps
its own sign-in. Validate requires `api == "1"`.

**D-I10 Mock in Node, built-ins only.** Quickest to write, independent of
the client code (so tests can't share a bug with it), and it doubles as an
executable reference for the real server. Tests skip with `XCTSkip` if Node
is missing.

**D-I11 Calm UI.** Pro chips only on server-backed features; the explainer
appears only when someone taps a Pro feature and says what uploads, where,
and that everything local stays free; "Not now" closes it. The usage line is
neutral ("3 of 5 share links left this month · renews 1 Nov"). Copy says
"the server", not "our servers", so it's true for self-hosters.

**D-I12 Suggested free tier** (what the mock serves): share links only, 5 per
month, 72 h maximum expiry, 50 downloads per link.

## How the app should integrate (Phase 3)

1. **URL callback (App lane / orchestrator).** In `AppDelegate`:
   ```swift
   func application(_ application: NSApplication, open urls: [URL]) {
       for url in urls { _ = CloudServices.shared.handleCallback(url) }
   }
   ```
   Also touch `CloudServices.shared` once after launch (skip when
   `AppDelegate.isRunningTests`) so an opted-in inbox starts polling. Creating
   it reads the Keychain and UserDefaults only; it makes no request.
2. **Settings (Settings lane).** Add an "Account" tab hosting
   `AccountSettingsView(session: CloudServices.shared.session)`. If the tab's
   own file needs entitlements, name it `Sources/Settings/AccountSettings*.swift`
   (the only Settings path `check-entitlements.sh` allows).
   Implement `SyncDocumentSource` over favourites / wheel order / presets /
   recipes / settings JSON, call `CloudServices.shared.setSyncSource(_:)` at
   launch and `await CloudServices.shared.sync.noteLocalChange(.favourites)`
   (etc.) whenever local data changes.
3. **Wheel (lane B, `Sources/Wheel/CloudSegments.swift`).** Show cloud
   segments with the cloud glyph + `CloudProChip()` always (they upload).
   On activation: if `CloudServices.shared.entitlements.can(feature)` run it,
   else `CloudPanels.showProExplainer(for: feature)`. Never consult
   entitlements anywhere else.
4. **Share link action (lane H).** `ActionIDs.shareLink` →
   `try await CloudPanels.runShareLink(files: urls)` (explainer if needed,
   options sheet, once-per-server notice, upload, link copied). For a
   convert-then-share target, convert first and pass the outputs. Show the
   returned `ShareLinkOutcome` as a brief "Link copied" state.
5. **Cloud jobs (lane C queue).** When a conversion's options have
   `cloud = true` (`CloudJobOperation.wantsCloud(options)`), enqueue
   `CloudServices.shared.makeCloudJob(input:operation: .convert(target:options:))`
   instead of the local job; for tools with `cloudFeature != nil` use
   `CloudJobOperation.forTool(spec.id, options:)`. They're `Job`s with
   `resourceClass .network` (suggest 2 concurrent), report progress through
   `Progress`, honour cancel, and throw `CloudError` (`LocalizedError` +
   `technicalDetails`) for the progress window.

## Shipped / not shipped

Shipped: everything in the brief's list: contract, README, mock, sign-in,
Keychain, session, entitlements, gate, client, share links (with resume,
SHA-256, options, pasteboard, quota), cloud jobs (convert, transcribe → SRT/VTT,
upscale, HQ background removal, cancel), sync, inbox, the four views + badge
and chip, screenshots, tests.

Not shipped (small, client APIs exist where noted):
- A "Your links" list / revoke / stats UI (`ShareLinkService.links()`,
  `revoke`, `CloudAPIClient.linkStats` exist).
- A devices list UI (`CloudAPIClient.devices()` exists).
- SSE progress (contract + mock have it; client polls by design, D-I6).
- The PKCE verifier lives in memory only, so a magic link opened after the
  app was quit and relaunched is refused with "start again" (one extra click,
  never a silent failure). Persisting the pending sign-in in the Keychain would
  remove that; not worth the extra secret at rest for now.
- The SHA-256 pass before an upload reads the whole file synchronously on the
  uploading task (not measured on multi-GB files yet); move it to a dedicated
  thread if very large uploads become common.
- Options for the Pro tools need a shared-schema change; see Contract changes.

## Contract change requests

`docs/contract-changes/I-cloud.md`: option schemas for the three cloud tools
(transcribe format + language, upscale factor). Non-blocking; the client
already reads those options when present.

## Tests

`Tests/Unit/App/Cloud/` (target AppTests, hosted by the app): 66 cloud tests + the existing smoke
test = 67, all passing in about 13 s:

| Class | Covers |
|---|---|
| `CloudGateTests` | Signed out: every public entry point (session, auth, share, uploads, all cloud job kinds, sync, inbox, raw client) makes **zero requests**: recording URLProtocol on the injected config **and** a globally registered one, plus a session-counting factory proving no URLSession is created. Signed in with sync/inbox off: zero. Control test proving the recorder catches requests. Gate rules. Static scan: only `CloudAPIClient.swift` touches URLSession |
| `CloudAuthTests` | Sign-in via simulated browser + callback → entitlements (Pro/Free/Team); authorize URL shape (PKCE S256, state, no personal data); forged state and denied callbacks make no request; manual code; single-use codes; expired token → one refresh → retry; concurrent requests share one refresh; revoked session signs out locally; sign-out clears the real Keychain (test service) and revokes on the server; sign-in survives relaunch with no request; logs never contain secrets; Validate; per-server sign-ins; URL parsing; RFC 7636 test vector |
| `ShareLinkTests` | Upload dropped mid-chunk (mock commits 10 000 bytes then resets) resumes from the server offset: exact Content-Range sequence asserted; SHA-256 verified; password/expiry/downloads; pasteboard; notice asked once per server; declining sends nothing; cross-attempt resume via the ledger; multi-file links, list, revoke; free plan can't use custom domains (refused before any request); Team custom domain; free quota and expiry clamp; stale cache refreshed before sharing; server enforces plans too |
| `CloudJobTests` | Convert end to end: result beside the original as `clip 2.mp4` (existing file untouched), progress monotonic through all three phases; operation sent without the `cloud` switch; signed download on another origin got no bearer token; transcribe → `-transcript.srt`/`.vtt`; upscale/HQ cutout names; cancel stops the server job; failures are human; every Pro tool maps to a job |
| `SyncEngineTests` | Create with `If-None-Match: *`, pull from another Mac, debounced push with `If-Match`, idle sync is one index call, conflict keeps server + notice + one-click reversal, conflict on push resolved from the 409 body (no extra GET), first sync on a second Mac, off/free = zero requests, canonical hashing |
| `InboxServiceTests` | Collision-safe, sanitised names (`photo 2.jpg`, `../../evil.txt` → `evil.txt`), never overwrites, acks; poller picks up items and stops when turned off (then zero requests); disabled = zero requests; failed download not saved or acked, retried next time |
| `KeychainStoreTests`, `CloudEntitlementsTests` | Real Keychain round trip under a throwaway service (cleaned up); vault per server; signed-out entitlements; unknown plans/features from a newer server; human errors; runs `scripts/check-entitlements.sh` |
| `CloudScreenshotTests` | Renders every screen in light/dark/increased contrast; writes `docs/screens/cloud-*.png` with `TEST_RUNNER_HALO_WRITE_SCREENS=1` |

Run: `xcodebuild … test -only-testing:AppTests` (note: the target is
`AppTests`; `AnyfmtAppTests` is only its product name).
`./scripts/check-entitlements.sh` → ✓.

Increased contrast: AppKit resolves `NSAppearance(named: .accessibilityHighContrast*)`
to plain Aqua when set on a view, so the offscreen "contrast" screenshots
switch our token colours with `CloudStyle.increasedContrastPreview`; system
controls render as normal there. With the real system setting,
`bestMatch(from:)` picks the high-contrast variants.

## Blockers needing a human

1. **The hosted server and its URL.** `CloudConfig.defaultServer` is
   `https://cloud.example.invalid` (reserved TLD, never resolves). Replace that
   one constant once the server from `Server/README.md` is deployed, and
   register OAuth client `anyfmt-mac` with redirect `anyfmt://auth/callback`
   (both derive from `Brand`; re-register on rename).
2. **Magic-link email** needs a sending provider (Postmark/SES/SMTP) on the server side.
3. **Strings catalog.** Cloud strings use `String(localized:)` in the app
   module; open the project in Xcode once (or run the string extraction) so
   they land in `Sources/App/Resources/Localizable.xcstrings`, which this lane
   doesn't own.
4. **Dev-build Keychain prompts.** Ad-hoc signatures change on every
   rebuild, so a rebuilt debug app may ask to use its existing "anyfmt Cloud"
   Keychain item. Developer ID builds keep a stable identity, so release users
   won't see this.
