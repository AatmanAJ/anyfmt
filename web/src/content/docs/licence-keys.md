---
title: Licence keys
description: What an anyfmt ANYFMT1 licence key is, how to activate or remove one, how it's checked offline, and why it never switches on or limits anything on your Mac.
---

A licence key is a signed string that proves, offline, that this Mac holds a paid Pro or Team licence and for how many seats. It never switches on, limits or changes anything that runs on your Mac: every local conversion, tool and action is free without one.

## What a key does, and doesn't

| | With a valid key |
|---|---|
| Plan shown in Settings | **Changes.** The better of your account's plan and the key's plan: free, then Pro, then Team. Never lowered |
| Seat count and licence id | **Shown**, for reference |
| Signed in | No. A key never signs you in |
| Cloud features | No change. They still need sign-in, and the server checks your account on every request |
| Quotas and usage | No change |
| Network | None. Checking a key makes no request |
| Local features | No change, ever. They're free with or without a key |

So a key alone can't upload anything. Share links, sync, the inbox and cloud jobs need you to sign in. See [What Pro adds](/docs/pro).

## Activate a key

1. Open **Settings › Account**, or choose **Pro Licence & Account…** from the menu bar icon.
2. Under **Pro licence key**, paste the key, or choose **Paste**.
3. Choose **Activate**.

You can also paste a key on the last page of the welcome window. Only a key that's valid right now is stored. If a key is invalid, expired or not yet valid, it isn't stored, any key you already had stays, and anyfmt tells you why in one sentence.

To take a key off this Mac, choose **Remove Licence…**. Everything local keeps working.

## What a key looks like

```text
ANYFMT1-01GQP-8K5F1-R24EK-…-H58HG-2
```

- `ANYFMT1` is the format version.
- The rest is Crockford base32 in groups of five, about 300 characters in all. Paste it rather than typing it.
- Dashes, spaces and letter case don't matter, and the look-alikes `O`, `I` and `L` are read as `0`, `1` and `1`.

Inside is a small JSON payload and an Ed25519 signature over it:

| Field | Meaning |
|---|---|
| `v` | Payload version, `1` |
| `kid` | Which signing key signed it |
| `lid` | The licence id, for support and server-side revocation |
| `plan` | `pro` or `team` |
| `seats` | 1 to 100 000 |
| `iat` | When it was issued |
| `exp` | When it expires, or `null` for a perpetual key |
| `eh` | Optional: a short hash of the buyer's email, never the address itself |

## How it's checked

Everything happens on your Mac, offline, in this order:

1. The key decodes: the right prefix, valid symbols, the right length, and a valid payload.
2. The signing key id (`kid`) is one the app trusts.
3. The Ed25519 signature matches the payload.
4. It isn't issued more than 5 minutes in the future, which allows for a slightly slow clock.
5. It hasn't expired.

The stored key is checked again every time it's read. A key that later expires, or whose signing key a later build stops trusting, stays stored but no longer counts. Settings can still say when it expired.

## Where it's stored

In your login Keychain, under the service `app.anyfmt.licence`. It isn't synced to iCloud.

## Honest limits

- anyfmt is open source, so anyone can patch the check or build the app with their own key in the trusted list. That's acceptable by design: nothing local is gated, and every cloud feature is enforced by the server. A forged key changes a badge on the forger's own Mac and nothing else.
- What the signature does protect: an unmodified app can't be fooled by a fake key, and a key's plan, seats or expiry can't be edited without failing the check.
- The app ships only public keys, so nothing in it can be used to make keys.
- Setting your clock back can keep an expired key looking valid, but it only affects the plan badge. The server decides what you can use.
- The email hint is a truncated hash, so a key doesn't reveal the buyer's address, though someone who guesses an address can confirm it.
