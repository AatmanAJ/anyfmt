# Onboarding: 5-minute hand check

Run on the dev Mac, ideally on a spare user account so your own anyfmt setup is
untouched. Everything here is also covered offscreen
(`OnboardingPermissionPathsTests`, `OnboardingModelTests`, renders in
`docs/screens/onboarding/`) and by the UI test (`make uitest`, which needs
Automation Mode, see BLOCKERS B-003). This checklist covers what only a person can
judge: real TCC prompts and how the flow feels.

## 0. Reset (30 s)

```bash
scripts/reset-first-run.sh          # dry run: read what it will do
scripts/reset-first-run.sh --yes    # do it (app data goes to the Trash, not deleted)
make build && open build/DerivedData/Build/Products/Debug/anyfmt.app
```

## 1. Welcome → demo (1 min)

- [ ] Onboarding opens by itself on the first launch.
- [ ] Welcome reads well and says local is free with no account. Continue.
- [ ] Demo: drag Sample.heic, press ⇧ (tap *and* hold both open the wheel), drop on a
      segment. Press ⌘ and ⌃ mid-drag: the wheel switches.
- [ ] Mid-drag, tap ⌥: the segment locks (outline, "· Locked"). Drift: it stays.

## 2. Permissions (2 min): try one path per run

- [ ] **Deny everything:** leave all switches off and Continue. No nagging.
- [ ] **Grant mid-flow:** on the permissions page, use a row's button. System Settings
      opens on the right pane. Flip the switch, come back: the row turns granted
      within a second, with no restart.
- [ ] **Revoke later:** after finishing, switch Accessibility off in System Settings.
      With the Finder Return shortcut on, pressing Return in Finder now does nothing
      harmful, the next launch explains which grant is missing (once), and drag + key
      wheels still work.

## 3. Launch at login, updates (30 s)

- [ ] The launch-at-login switch really adds anyfmt to System Settings › General › Login Items.
- [ ] Updates are off unless you turn them on. With them off, `make netcheck` style:
      anyfmt opens no sockets.

## 4. Optional activation (1 min)

- [ ] The last page says it's optional. **Start Using anyfmt** finishes without a key.
- [ ] Paste a test key (`swift scripts/licence-tool.swift issue --plan pro --seats 1 --days 30`):
      it shows "Pro licence, valid until …". A garbled key shows a plain error and
      doesn't replace a good one.
- [ ] Settings › Account shows the key and can remove it. The menu bar has
      "Pro Licence & Account…".
- [ ] After skipping: nothing nags, and every local conversion still works.

## 5. Replay

- [ ] Menu bar › Show Onboarding… (or `--reset-onboarding`) starts again at Welcome.
