# SETUP — taking trunk-workshop from State 0 to Final state

This repo ships in **State 0**: the app, tests, CI workflows, and PR automation all exist, but Trunk
is not yet configured. The steps below are **human-only** — they happen in the GitHub and Trunk UIs
(and involve secrets/tokens) and cannot be done by Claude Code. Work top to bottom.

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
   **organization API token**.
4. **Add repo secrets** (Settings → Secrets and variables → Actions → Secrets):
   - `TRUNK_ORG_URL_SLUG` — the org slug from step 3
   - `TRUNK_API_TOKEN` — the org API token from step 3

   This activates the (previously inert) upload steps in the CI workflows.

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

## Re-demoing setup later

Filming the live setup permanently configures this repo. For a pristine "from scratch" take again,
fork the repo (or spin up a throwaway copy) and run the setup there.
