# SETUP — taking trunk-workshop from State 0 to Final state

This repo ships in **State 0**: the app, tests, CI workflows, and PR automation all exist, but Trunk
is not yet configured. Some steps below are **human-only** — they happen in the GitHub and Trunk UIs
(and involve secrets/tokens) and cannot be scripted.

If you're **forking to run your own copy** (the common case), start with *Following along from a fork*
just below — it orchestrates the detailed sections that follow. If you're standing up the canonical
repo from scratch, work through *GitHub / Trunk account* onward top to bottom.

## Following along from a fork (recommended path)

Fork the canonical repo and configure your fork. Do these **in order** — several steps depend on
earlier ones, and one ordering gotcha will bite you otherwise (see the callout).

1. **Fork** `trunk-io/trunk-workshop` into your account, then clone it:
   ```bash
   gh repo fork trunk-io/trunk-workshop --clone
   cd trunk-workshop
   ```
2. **Set up the toolchain + install deps.** Node/npm are managed hermetically via Trunk + direnv
   (see [README → Hermetic toolchain](README.md#hermetic-toolchain-node--npm-via-trunk)): install the
   Trunk CLI and direnv, run `direnv allow`, then install dependencies — `open-prs` needs `tsx`, a
   devDependency, so a fresh clone **must** install before running it:
   ```bash
   npm ci
   ```
3. **Enable GitHub Actions on the fork** — forks ship with Actions disabled:
   ```bash
   gh api -X PUT repos/<you>/trunk-workshop/actions/permissions -F enabled=true -f allowed_actions=all
   ```
4. **Install the Trunk GitHub App** on the fork, **create a test collection** and **add the Trunk
   secrets** — see steps 2–4 under *GitHub / Trunk account*. Without the secrets, CI runs but nothing
   uploads to Trunk, so the Flaky Tests dashboard stays empty.
5. **Create the queue** in Trunk (Merge Queue → add repo, target `main`).
6. **Apply branch protection** with the helper script (resolves the `trunk-io` app id automatically):
   ```bash
   ./scripts/setup-merge-queue.sh        # detects the current repo; or pass <you>/trunk-workshop
   ```
7. **Fill the queue** with PRs — each gets a `/trunk merge` comment (queue must exist, step 5):
   ```bash
   npm run open-prs -- --count 10 --queue
   ```
8. **Turn on auto-quarantine** and confirm detection — see *Flaky Tests*. Flake classification needs
   the same test to both pass and fail across several runs, so let traffic accumulate (step 11).

> **Ordering gotcha:** once step 6 applies branch protection, direct pushes to `main` are blocked —
> which is the point, but it also means **`gh repo sync` stops working**. From then on, pulling
> upstream changes into your fork has to go through a PR + the queue. To reset, see
> *Resetting a fork to a clean slate* at the bottom.

## GitHub / Trunk account

1. **Create the GitHub repo** under the chosen org and push this code. Public is easiest for
   attendees to clone.
   ```bash
   git remote add origin git@github.com:<org>/trunk-workshop.git
   git push -u origin main
   ```
2. **Install the Trunk GitHub App** on the repo:
   https://docs.trunk.io/setup-and-administration/github-app-permissions
3. In **app.trunk.io → Settings → Organization → General**, copy the **org slug** and create an
   **organization API token**. Then, in **Flaky Tests**, create a **test collection** for this repo
   and copy its **ID**. Both suites upload to this one collection.
4. **Add ALL THREE repo secrets** (Settings → Secrets and variables → Actions → Secrets), or via `gh`:
   ```bash
   gh secret set TRUNK_ORG_URL_SLUG       --repo <you>/trunk-workshop --body "<your-org-slug>"
   gh secret set TRUNK_API_TOKEN          --repo <you>/trunk-workshop --body "<your-org-api-token>"
   gh secret set TRUNK_TEST_COLLECTION_ID --repo <you>/trunk-workshop --body "<your-test-collection-id>"
   ```
   - `TRUNK_ORG_URL_SLUG` — the org slug from step 3
   - `TRUNK_API_TOKEN` — the org API token from step 3
   - `TRUNK_TEST_COLLECTION_ID` — the test collection ID from step 3

   This activates the (previously inert) upload steps in the CI workflows.

   > **Gotcha — set ALL THREE.** The upload step only gates on `TRUNK_API_TOKEN`, so if you set the
   > token but forget the slug or the collection ID, the step runs and **fails** — but because the
   > upload step is `continue-on-error: true`, CI still shows **green** and **nothing is uploaded to
   > Trunk**. If your Test Runs / Uploads tab is empty, check that all three secrets exist.

## Merge Queue

5. In **Trunk → Merge Queue**, create a queue for the repo targeting `main`.
6. Set **branch protection** on `main` so merges go through the queue. Once the Trunk GitHub App is
   installed (step 2), run the helper script instead of clicking through the rulesets UI:

   ```bash
   scripts/setup-merge-queue.sh            # current repo, or pass owner/repo
   ```

   It enables squash merges and creates the two rulesets Trunk recommends — `merge-queue-branch-update`
   (Restrict updates; the `trunk-io` app bypasses as **Exempt** so the queue can push merges) and
   `merge-queue-mergeability` (require a PR + the `Unit Tests`/`E2E Tests` checks; Trunk intentionally
   not on its bypass). It's idempotent — re-run it to update the rulesets. Needs `gh` with admin rights
   on the repo.
7. For the batching segment: enable **Batching** (target size **4**, max wait **5 min** — the
   defaults).
7a. For the **graph-mode** segment: the repo already uploads each PR's impacted targets
   (`frontend` / `backend`) via `.github/workflows/impacted-targets.yml`, regardless of queue mode.
   So queue ~5 PRs with the queue in **linear** mode and watch them merge one at a time, then switch
   the queue to **graph** (parallel) mode in Trunk and re-run — PRs impacting disjoint targets merge
   in parallel. See *Graph mode* in [README.md](README.md#graph-mode-impacted-targets).

## Flaky Tests

8. Confirm uploads are landing in **Trunk → Uploads** after the first run on `main`.
9. Confirm the detection monitors (pass-on-retry is on by default) and turn on **auto-quarantine**
   so a flaky test can be shown going green.
10. _(Optional, nice for the demo)_ Connect the Jira/ticketing and Slack integrations so the
    "ticket + Slack alert" moment is real.

## Pre-bake for recording

11. Set the `TRAFFIC_ENABLED` repo **variable** (Settings → Secrets and variables → Actions →
    Variables) to `true`, then let `generate-traffic.yml` run for a day or two before recording so
    there's real queue depth and flake history to cut to. Flip it back to `false` (or unset it) to
    stop the traffic.

    For the traffic workflow to actually open **mergeable** PRs, two more things are needed:

    - **A `TRAFFIC_PAT` secret.** PRs opened with the built-in `GITHUB_TOKEN` don't trigger other
      workflows (GitHub blocks recursion), so they'd never run the required Unit/E2E checks and would
      stall in the queue. Create a PAT (classic: `repo` scope; or fine-grained: Contents + Pull
      requests read/write on the repo) and add it so the workflow pushes/creates PRs as a real user:
      ```bash
      gh secret set TRAFFIC_PAT --repo <you>/trunk-workshop --body "<your-pat>"
      ```
    - **Allow Actions to create PRs** (only needed for the `GITHUB_TOKEN` fallback, harmless to set):
      Settings → Actions → General → Workflow permissions → check *Allow GitHub Actions to create and
      approve pull requests*, or:
      ```bash
      gh api -X PUT repos/<you>/trunk-workshop/actions/permissions/workflow \
        -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true
      ```

    > Note: scheduled workflows are **disabled by default on forks** and auto-disable after 60 days
    > idle. Enable via the Actions tab (or `gh workflow enable generate-traffic.yml`); the traffic it
    > generates keeps the repo active. GitHub crons are also best-effort (often delayed), so for
    > on-demand traffic use `gh workflow run generate-traffic.yml` or run `open-prs` in a local loop.

## Resetting a fork to a clean slate

To start over (e.g. to re-record from scratch), the **order matters**: the rulesets block the sync
until they're removed, so delete them first, then sync, then reconfigure.

```bash
REPO=<you>/trunk-workshop
# 1. delete the rulesets (this is what unblocks the branch)
for id in $(gh api repos/$REPO/rulesets --jq '.[].id'); do gh api -X DELETE "repos/$REPO/rulesets/$id"; done
# 2. now the sync works — fast-forward main to upstream (picks up any script fixes)
gh repo sync $REPO --source trunk-io/trunk-workshop
# 3. (optional) close stale PRs and delete leftover branches for a truly clean slate
gh pr list --repo $REPO --json number --jq '.[].number' | xargs -I{} gh pr close {} --repo $REPO --delete-branch
# 4. re-run the setup from a fresh pull
git pull && ./scripts/setup-merge-queue.sh
```

## Re-demoing setup later

Filming the live setup permanently configures the repo. For a pristine "from scratch" take again,
fork the repo (or spin up a throwaway copy) and run the setup there — or use *Resetting a fork to a
clean slate* above.
