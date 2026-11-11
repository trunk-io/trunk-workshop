# trunk-workshop

A small demo repo for the Trunk PlatformCon workshop covering
**Merge Queue** and **Flaky Tests**. It's a Next.js + TypeScript app with Vitest unit tests and
Playwright e2e tests. Both suites emit JUnit XML for Trunk to ingest, and each suite contains one
**intentionally flaky** test so the Flaky Tests dashboard has something real to detect and quarantine.

## App

- `app/` — Next.js App Router pages (`/` home, `/cart`).
- `lib/money.ts` — `formatCurrency(cents, currency)`.
- `lib/cart.ts` — `cartTotal(items)` reducer + `CartItem` type.

## Hermetic toolchain (Node + npm via Trunk)

This repo manages its own Node/npm hermetically with [Trunk](https://docs.trunk.io/cli), so you
don't need a matching Node installed — everyone (and CI) uses the exact version pinned in
[`.trunk/trunk.yaml`](.trunk/trunk.yaml) (Node `22.16.0`). It's wired through
[direnv](https://direnv.net): on entering the repo, `.envrc` puts Trunk's `node`/`npm`/`npx` shims
on your `PATH`.

One-time setup:

```bash
# 1. Install the Trunk CLI
curl https://get.trunk.io -fsSL | bash

# 2. Install direnv and hook it into your shell (bash/zsh/fish):
#    https://direnv.net/docs/hook.html

# 3. From the repo root, approve the .envrc:
direnv allow
```

After that, `node` and `npm` resolve to the Trunk-managed versions automatically (the first run
downloads Node on demand). Verify with:

```bash
which node      # → .trunk/tools/node
node --version  # → v22.16.0
```

> Not using direnv? You can still get the same tools on `PATH` manually: run `trunk install` once
> (generates the shims in `.trunk/tools/`), then add `.trunk/tools` to your `PATH`. CI uses
> `actions/setup-node` pinned to the same version.

## Running tests

```bash
npm install   # node/npm are Trunk-managed once direnv is set up (above)

# Unit (Vitest) → writes test-results/unit-junit.xml
npm run test:unit

# E2E (Playwright) → writes test-results/e2e-junit.xml
npx playwright install chromium   # first time only
npm run test:e2e                  # boots `next dev` automatically
```

JUnit reports land in `test-results/`. The CI workflows clear that directory before each run so a
reused runner can't re-upload stale results (which would corrupt flake detection).

### Flaky tests (on purpose)

`tests/unit/flaky.test.ts` and `tests/e2e/flaky.spec.ts` each fail ~30% of the time via a random
roll. They are isolated and never affect real app behavior — they exist only to produce a flake
signal for the workshop. Playwright is configured with `retries: 0` so Trunk sees the true
pass/fail signal.

## Opening PRs (filling the queue)

`scripts/open-prs.ts` opens throwaway PRs against `main` to fill the Merge Queue. It uses the
[`gh` CLI](https://cli.github.com/), which must be installed and authenticated (`gh auth login`, or
a `GITHUB_TOKEN` / `GH_TOKEN` env var).

```bash
# Open 6 PRs (leave them for a manual `/trunk merge` in the demo)
npm run open-prs -- --count 6

# Open 3 PRs and post `/trunk merge` on each so they enter the queue automatically
npm run open-prs -- --count 3 --queue
```

Each PR branches off the latest `main` and makes a tiny safe change scoped to one target — a unique
`frontend/notes-*.md` or `backend/notes-*.md` file (alternating, see *Graph mode* below) — with a
realistic conventional-commit title. Branch names are timestamped so reruns don't collide.

## Graph mode (impacted targets)

The repo defines two merge-queue **targets**, [`frontend/`](frontend/) and [`backend/`](backend/).
Each PR alternates which target it touches, and `.github/workflows/impacted-targets.yml` computes the
impacted target from the PR's changed files and uploads it to Trunk
(`POST /v1/setImpactedTargets`, via [`scripts/upload-impacted-targets.sh`](scripts/upload-impacted-targets.sh)).

Impacted targets are uploaded on **every** PR, regardless of queue mode — the queue only *uses* them
in graph mode. So you can:

1. Queue ~5 PRs with the queue in **linear** mode → they merge one at a time.
2. Flip the queue to **graph** mode in Trunk and re-run the same thing → PRs impacting disjoint
   targets (`frontend` vs `backend`) merge in **parallel** lanes.

## CI workflows

- `.github/workflows/unit-tests.yml` / `e2e-tests.yml` — run on push + PR, execute the suites with
  `continue-on-error: true` (so quarantine can keep CI green), then upload to Trunk via
  `trunk-io/analytics-uploader@main` into the test collection named by `TRUNK_TEST_COLLECTION_ID`.
  The upload step is guarded so it no-ops until the Trunk secrets exist (the token is lifted into a
  job `env` var and the step's `if` checks it), so CI is green before setup and active once the
  secrets are added.
- `.github/workflows/impacted-targets.yml` — runs on PR; uploads the PR's impacted targets for graph
  mode (above). Same `TRUNK_API_TOKEN` guard, so it's inert until secrets exist.
- `.github/workflows/generate-traffic.yml` — scheduled + manual; runs `open-prs --queue`. Gated on
  the `TRAFFIC_ENABLED` repo variable, so it's **off by default**.

See [`SETUP.md`](./SETUP.md) for the steps to wire up Trunk and reach the Final state.
