# CLA vs DCO: what Cap and comparable projects use, and what Halo should do

Research date: 2026-10-18. **This is not legal advice.** Have a lawyer read the final agreement before relying on it for a paid or App Store release.

## The constraint

Halo is AGPL-3.0, apart from the MIT packages `Packages/DragSense` and `Packages/RadialMenu`. The owner wants to keep two options open: a future **paid desktop licence** and a **Mac App Store build**. The App Store's terms add usage restrictions that the GPL family forbids. The FSF's 2010 [GNU Go enforcement](https://www.fsf.org/news/2010-05-app-store-compliance/) ended with Apple pulling the app. So an App Store build is only possible if **every copyright holder** licenses the code to the publisher under other terms.

Today the owner holds all the copyright. The moment an outside contribution is merged under plain AGPL, that contribution can only be shipped under AGPL. The cost of fixing that afterwards is real. VideoLAN spent years contacting contributors to relicense libVLC from GPL to LGPL ([LWN, 2012](https://lwn.net/Articles/525718/)). **So the agreement has to be in place before the first external PR is merged.** It can't cover contributions merged before it was adopted.

## What Cap uses

**Nothing.** Cap has no CLA and no DCO; outside contributions come in under the project's licence, as with any default GitHub contribution.

- `CONTRIBUTING.md` covers dev setup only. Its commit history goes back to 2024 and no commit title mentions a CLA.
- `.github/` has no PR template, no CLA or DCO workflow, and no CLA config.
- A recent external PR (#2684, merged) ran about 50 checks. None was a CLA or DCO check. The "Contributor trust" check comes from superagent.sh and is a security scan, not an agreement.
- `LICENSE`: Copyright Cap Software, Inc. The `cap-camera*` and `scap-*` crates are MIT; everything else is AGPLv3. Halo's split mirrors this.
- Commercially, Cap sells a "Desktop License" for commercial use ($29 a year or $58 lifetime, per [cap.so/pricing](https://cap.so/pricing)) and a hosted Pro plan. Without a CLA, though, Cap can't relicense outside contributors' code: any build that includes it stays bound by AGPL terms. **Halo shouldn't copy Cap on this point.**

convt (AGPL, sells signed builds) is in the same position: no CONTRIBUTING file and no CLA, and 106 of its 114 commits are by the owner.

## Comparable projects

I checked each project's repo files and PR bots (GitHub API, 2026-10-18). For the CLA Assistant projects I read the agreement text through CLA Assistant's public API.

| Project | Licence | Mechanism | Keeps relicensing right? | Source |
|---|---|---|---|---|
| **Cap** | AGPL-3.0, MIT for `cap-camera*` / `scap-*` | None (no CLA, no DCO) | **No** | [CONTRIBUTING.md](https://github.com/CapSoftware/Cap/blob/main/CONTRIBUTING.md), [LICENSE](https://github.com/CapSoftware/Cap/blob/main/LICENSE) |
| **convt** | AGPL-3.0-only; paid signed builds | None | **No** for outside code (owner wrote nearly all of it) | [README licence section](https://github.com/opencoredev/convt#license) |
| **Grafana** | AGPL-3.0 (relicensed from Apache-2.0 in 2021) | CLA based on the Apache ICLA, enforced by CLA Assistant (more than 4,000 bot comments on PRs) | **Yes.** The broad licence grant includes sublicensing, and it made the Apache→AGPL move possible. | [CONTRIBUTING.md](https://github.com/grafana/grafana/blob/main/CONTRIBUTING.md), [CLA](https://grafana.com/docs/grafana/latest/developers/cla/), [relicensing post](https://grafana.com/blog/grafana-loki-tempo-relicensing-to-agplv3/) |
| **Plausible Analytics** | AGPL-3.0 | CLA via CLA Assistant | **Yes, explicitly.** Contributions may be licensed on any terms, and the agreement names proprietary and commercial licences outright. | [CLA Assistant page](https://cla-assistant.io/plausible/analytics) |
| **Element (Synapse)** | AGPL-3.0 or commercial (moved from Apache-2.0 in Nov 2023) | Apache-based CLA, v2.1 of March 2025, via CLA Assistant | **Yes, explicitly, with a guarantee.** Element may ship contributions under its proprietary licence only if it also makes them available under an OSI-approved licence. | [Element blog](https://element.io/blog/element-to-adopt-agplv3/), [CLA Assistant page](https://cla-assistant.io/element-hq/synapse) |
| **Mattermost** | AGPL-3.0 source; compiled binaries under MIT; commercial licence | CLA through an online form; approved contributors are listed | **Yes.** The page says the CLA keeps the option to relicense more permissively, and it already ships its binaries under MIT. | [Contributor Agreement](https://mattermost.com/mattermost-contributor-agreement/), [LICENSE.txt](https://github.com/mattermost/mattermost/blob/master/LICENSE.txt) |
| **Cal.com** | AGPL-3.0 plus a commercial `/ee` until April 2026; the public repo is now MIT ("Cal.diy") and the product is closed source | CLA via CLA Assistant: an Apache-style copyright and patent grant that includes sublicensing | **Yes.** It was used to relicense the public repo from AGPL to MIT in April 2026. | [README before the change: "Requires CLA"](https://github.com/calcom/cal.diy/blob/a17f28e9ab44d34a24840cff70082470d775b9b1/README.md#license), [CLA Assistant page](https://cla-assistant.io/calcom/cal.diy), [Cal.com blog](https://cal.com/blog/cal-diy-open-source-to-closed-source) |
| **Twenty** | AGPL-3.0, with commercial `@license Enterprise` files and MIT packages | CLA in `.github/CLA.md` (the same template as Cal.com's). It used CLA Assistant until late 2023; now opening a PR is taken as agreement, and a Danger bot tells first-timers so. | **Yes** (sublicensing grant). The implied-acceptance method is weaker evidence than a recorded signature. | [CLA.md](https://github.com/twentyhq/twenty/blob/main/.github/CLA.md), [CONTRIBUTING.md](https://github.com/twentyhq/twenty/blob/main/.github/CONTRIBUTING.md) |
| **Documenso** | AGPL-3.0 | CLA in `CLA.md`, signed through Documenso's own signing link and checked by maintainers by hand | **Partly.** It grants a sublicensable licence, but only for the project's purposes, which is narrower. The manual check causes friction: one contributor said they had filled in the form twice. | [CLA.md](https://github.com/documenso/documenso/blob/main/CLA.md), [PR #3307 thread](https://github.com/documenso/documenso/pull/3307) |
| **Nextcloud** | AGPL-3.0 | DCO (`Signed-off-by` on every commit, real names) | **No.** Inbound licence equals outbound licence. | [.github/CONTRIBUTING.md](https://github.com/nextcloud/server/blob/master/.github/CONTRIBUTING.md) |
| **Penpot** | MPL-2.0 | DCO (`Signed-off-by` on code patches) | **No** | [CONTRIBUTING.md](https://github.com/penpot/penpot/blob/develop/CONTRIBUTING.md) |
| **Sentry** | FSL-1.1-Apache-2.0 | No CLA or DCO found (checked CONTRIBUTING, workflows and CLA-bot comments) | Not documented (unverified) | [.github/CONTRIBUTING.md](https://github.com/getsentry/sentry/blob/master/.github/CONTRIBUTING.md) |

Context outside the table: GitLab [moved from a CLA to a DCO in 2017](https://about.gitlab.com/blog/gitlab-switches-to-dco-license/) to lower friction. GitLab's core is MIT, so it never needed relicensing rights.

### The pattern

- **Every AGPL open-core project above that kept the ability to relicense uses a CLA:** Grafana, Plausible, Element, Mattermost, Cal.com, Twenty and Documenso. Most use CLA Assistant.
- **Projects on a DCO (Nextcloud, Penpot) or on nothing (Cap, convt) cannot relicense outside contributions.**
- **Two of them have actually used the right:** Grafana (Apache→AGPL) and Cal.com (AGPL→MIT). VLC is the cautionary tale of relicensing without a CLA.

## Options for Halo

| Option | Friction | Keeps App Store or paid-licence path? | Notes |
|---|---|---|---|
| A. Nothing (Cap, convt) | Lowest | **No**, once anyone else contributes | Not compatible with the goal. |
| B. DCO only (Nextcloud, Penpot) | `git commit -s` on every commit; the DCO bot blocks unsigned commits and forces a rebase | **No** | The DCO certifies origin under the project's own licence, which means inbound equals outbound. |
| C. DCO plus a relicensing clause in CONTRIBUTING | Same as B | Probably, but weakly | In the DCO text, the contributor certifies the work under the project's own open-source licence. Putting an extra grant beside it contradicts what a sign-off normally signals. A DCO bot only checks the sign-off string, so there's no record that the person saw the clause or which version they saw. |
| **D. Short licence-style CLA with explicit relicensing, enforced by CLA Assistant** | **One click per contributor, once, for all future PRs** | **Yes** | Recorded signature: GitHub identity, date and the exact Gist revision of the text. This is the peer norm for AGPL open core. |

## Recommendation: option D

Use a **short CLA that grants a licence (not an assignment) with an explicit relicensing permission and an open-source guarantee**. Enforce it with **CLA Assistant** ([cla-assistant.io](https://cla-assistant.io), the hosted service run by SAP; Apache-2.0, actively maintained).

Why D:

1. **It's the only option that clearly preserves the goal.** It names relicensing, proprietary terms and app-store terms outright. A licence grant that only says "sublicense" (Cal.com, Twenty, Grafana) worked for those companies, but an explicit clause leaves less room for argument.
2. **Friction is low, and lower than a DCO in practice.** A first-time contributor clicks once on the PR check and is covered from then on. A DCO needs every commit signed. Forgotten sign-offs are the classic first-PR stumble, and CLA Assistant has no equivalent.
3. **The record is better.** CLA Assistant stores who signed, when, and which revision, and it re-checks every committer on each PR. Option C leaves no record of agreement to the extra clause. Twenty's implied acceptance and Documenso's manual check are weaker or slower.
4. **It answers the usual objection to CLAs.** The contributor keeps ownership, and the Element-style guarantee promises that their code stays available under AGPL or another OSI licence even if it also ships under other terms. That's the main worry people have about a CLA for an AGPL project.
5. **It's a peer norm.** Contributors to AGPL open-core projects are used to it: Grafana, Plausible, Element, Cal.com and Twenty all ask for one.

**Tooling note.** The "CLA Assistant Lite" GitHub Action, which stored signatures in the repo, was [archived](https://github.com/contributor-assistant/github-action) in 2026. Use the hosted cla-assistant.io, or self-host the open-source [cla-assistant](https://github.com/cla-assistant/cla-assistant) server if third-party hosting becomes a concern.

## Recommended agreement text

Original wording. Replace the bracketed placeholders. Keep the text as `CLA.md` in the repo **and** in a public GitHub Gist, because CLA Assistant serves the Gist.

> **Halo Contributor Licence Agreement, version 1.0**
>
> This agreement is between you and [OWNER LEGAL NAME] (the "Maintainer"), who runs the Halo project at [https://github.com/OWNER/REPO]. It covers everything you submit to Halo.
>
> **1. Words used here.** A "Contribution" is any code, documentation, artwork, translation or other material that you submit to a repository, issue tracker or discussion run for Halo, with the intention that it be included in Halo. To "submit" means to send it by pull request, patch, commit, attachment or any other channel the project uses. "Halo" means the software, documentation and packages the Maintainer publishes as part of the project, including the separately licensed MIT packages.
>
> **2. You keep ownership.** You keep the copyright and every other right you have in your Contribution. This agreement is a licence. It does not transfer ownership.
>
> **3. Copyright licence, including the right to relicense.** You grant the Maintainer a worldwide, perpetual, irrevocable, non-exclusive, royalty-free licence to use, reproduce, modify, adapt, publicly display, publicly perform, distribute and sublicense your Contribution and works based on it. This includes the right to license your Contribution, as part of Halo or on its own, under terms other than the licence Halo used when you contributed. Those terms may be other open-source licences, or proprietary or commercial licences, including the terms required for distribution through app stores such as the Mac App Store.
>
> **4. Your Contribution stays open source.** If the Maintainer distributes your Contribution, or a work that contains it, under terms that are not an open-source licence, the Maintainer will also make your Contribution available to the public under the GNU Affero General Public License version 3, or under another licence approved by the Open Source Initiative. Section 3 lets the Maintainer offer additional terms. It can never be used to withdraw the open-source availability of your Contribution.
>
> **5. Patent licence.** You grant the Maintainer, and everyone who receives Halo from the Maintainer, a worldwide, perpetual, non-exclusive, royalty-free licence to make, have made, use, sell, offer for sale, import and otherwise transfer your Contribution. This covers any patent claims you are able to license that would necessarily be infringed by your Contribution, either alone or combined with the version of Halo you submitted it to. If any person or organisation starts patent litigation alleging that your Contribution, or Halo, infringes a patent, the patent licence this section gives to that person or organisation ends on the date the litigation is filed.
>
> **6. What you confirm.** By accepting this agreement, you confirm that:
>
> - (a) each Contribution is your own original work, or you otherwise have the right to submit it under this agreement;
> - (b) if your employer or anyone else could claim rights in a Contribution, they have allowed you to submit it under these terms;
> - (c) you have clearly identified any part of a Contribution that comes from someone else, together with its source and licence, and you have not knowingly included material that cannot be licensed as described here.
>
> **7. No other promises.** You provide your Contributions "as is", with no warranties beyond those in section 6, and you have no duty to support them. The Maintainer has no obligation to use any Contribution.
>
> **8. Successors.** The Maintainer may transfer this agreement, and the rights it grants, to a company or other organisation that takes over Halo. Anyone it is transferred to is bound by section 4.
>
> **9. Acceptance and scope.** You accept this agreement by agreeing to it through the CLA Assistant check on a pull request, or in writing to the Maintainer. It applies to every Contribution you have submitted or will submit to Halo. You can end it for future Contributions by telling the Maintainer in writing. Contributions you submitted before then stay covered.

Notes for the lawyer review: whether to add a governing-law clause (deliberately left out here); whether to offer a separate corporate version for employer-owned contributions; and whether the section 4 promise is worded the way the owner wants.

### Text for `CONTRIBUTING.md`

> **Licence of contributions.** Halo is AGPL-3.0, and `Packages/DragSense` and `Packages/RadialMenu` are MIT. Before we can merge your first pull request, we ask you to accept the short [Halo Contributor Licence Agreement](CLA.md); the CLA Assistant check on your PR walks you through it, and you only do it once. You keep ownership of your work. The agreement lets the maintainer also offer Halo under other terms, such as a paid licence or a Mac App Store build, which the AGPL alone doesn't allow. In return, it guarantees that your contribution always stays available under the AGPL or another OSI-approved licence.

### Fallback if the owner insists on a DCO (option C)

Not recommended, for the reasons above. If chosen, use this text in CONTRIBUTING.md and require the DCO app:

> By adding a `Signed-off-by:` line to a commit, you certify the [Developer Certificate of Origin 1.1](https://developercertificate.org/) for that commit, and you also grant [OWNER LEGAL NAME] the licences and accept the terms in sections 2 to 8 of the Halo Contributor Licence Agreement (CLA.md), as it stood on the date of the commit.

## Setup checklist

1. Commit `CLA.md` (text above) and put the identical text in a public Gist under the owner's account.
2. Sign in at cla-assistant.io with GitHub and link the repo to the Gist. Allowlist bots such as `dependabot[bot]`, `github-actions[bot]` and `renovate[bot]`.
3. Add the CLA Assistant status check as **required** in branch protection on `main`.
4. Add the CONTRIBUTING.md paragraph above.
5. Treat any edit to the Gist as a new version (v1.1, …): CLA Assistant tracks which revision each person signed, so expect to collect signatures again.
6. Known snag: CLA Assistant checks every commit author. A commit made with an email that isn't linked to a GitHub account shows up as an unsigned "unknown" author. Mention in CONTRIBUTING.md that contributors should link their commit email.
7. Do all of this **before** merging the first outside PR.

Related, but separate from the licence: a sandboxed Mac App Store build also loses some drag-pasteboard abilities (see `PRIOR_ART.md`, "Technique discussions and platform risks"). The CLA keeps that build *legally* possible; technically it will still need the drop-onto-ring path.
