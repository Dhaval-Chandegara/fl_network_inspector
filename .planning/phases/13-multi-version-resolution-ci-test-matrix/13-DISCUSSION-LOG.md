# Phase 13: Multi-Version Resolution & CI Test Matrix - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-11-21
**Phase:** 13-Multi-Version Resolution & CI Test Matrix
**Areas discussed:** CI Matrix Dimensions & Runners, Consumer Pub Resolution Simulation Strategy, Pana Analysis & Packaging Gate Automation, CI Workflow Concurrency & Branch Triggers

---

## CI Matrix Dimensions & Runners

### Question 1: Which Flutter SDK channels and versions should the GitHub Actions CI test matrix run across?

| Option | Description | Selected |
|--------|-------------|----------|
| Flutter stable, beta, and pinned minimum SDK (3.10.0 / 3.22.0) | Fast and thorough coverage of current stable, future beta, and minimum baseline without matrix bloat | ✓ |
| Exhaustive Flutter matrix (stable, beta, plus explicit 3.22, 3.24, 3.27 versions) | Runs tests across multiple explicit historical Flutter versions | |
| You decide | Let the planner choose the optimal balance of version coverage and CI execution time | |

**User's choice:** Flutter stable, beta, and pinned minimum SDK (3.10.0 / 3.22.0)
**Notes:** Balances thoroughness with CI runner economy.

### Question 2: Which operating system runners should execute the CI test jobs?

| Option | Description | Selected |
|--------|-------------|----------|
| ubuntu-latest for all Flutter matrix jobs + dedicated macOS/Windows smoke test job for SQLite FFI | Fast Linux builds for the main matrix with targeted desktop FFI verification | ✓ |
| ubuntu-latest exclusively | Keeps CI runtime fast and minimizes GitHub Actions runner minutes; tests Linux SQLite FFI engine headlessly | |
| Full multi-OS matrix (Linux, macOS, Windows across all channels) | Maximum platform verification at the cost of higher runner queue times and billing minutes | |
| You decide | Choose the most reliable setup for SQLite FFI and Flutter testing | |

**User's choice:** ubuntu-latest for all Flutter matrix jobs + dedicated macOS/Windows smoke test job for SQLite FFI
**Notes:** Ensures SQLite FFI native desktop bindings are verified on macOS and Windows without multiplying full matrix duration.

### Question 3: How should tool/verify_lowest_bounds.sh be integrated into the GitHub Actions CI workflow?

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated standalone CI job on ubuntu-latest (Flutter stable) | Isolates lowest-bounds dependency downgrade verification cleanly without slowing down the standard test matrix | ✓ |
| Run as a subsequent step within the minimum Flutter version matrix job | Bundles lowest-bounds tests together with the minimum SDK runner | |
| You decide | Let the planner configure the cleanest pipeline organization | |

**User's choice:** Dedicated standalone CI job on ubuntu-latest (Flutter stable)
**Notes:** Makes lowest-bounds regression triage immediate and distinct from normal test matrix failures.

### Question 4: Should beta channel test failures block CI builds or run as non-blocking alerts?

| Option | Description | Selected |
|--------|-------------|----------|
| continue-on-error: true for beta channel | Surfaces upcoming Flutter framework breaks early in CI logs without blocking current PR merges on upstream regressions | ✓ |
| continue-on-error: false for beta channel (blocking) | Requires strict zero-failure builds across both stable and beta channels before merging | |
| You decide | Let the planner choose the optimal policy | |

**User's choice:** continue-on-error: true for beta channel
**Notes:** Prevents unreleased upstream Flutter regressions from halting day-to-day development while providing early visibility.

---

## Consumer Pub Resolution Simulation Strategy

### Question 1: How should consumer pub resolution tests be structured and executed?

| Option | Description | Selected |
|--------|-------------|----------|
| Automated shell script (tool/verify_consumer_resolution.sh) generating ephemeral consumer projects in tempdir | Keeps repo clean, tests path dependency resolution in isolation, and runs identically locally and in CI | ✓ |
| Static fixture directory (test/fixtures/consumer_projects/) with checked-in sample pubspec files | Visible in tree, but requires git-tracking mock apps and pub artifacts | |
| Dart unit test harness (test/resolution/consumer_resolution_test.dart) invoking dart pub via Process.run | Integrated into standard flutter test runner | |
| You decide | Choose the cleanest approach for local development and CI execution | |

**User's choice:** Automated shell script (tool/verify_consumer_resolution.sh) generating ephemeral consumer projects in tempdir
**Notes:** Avoids tracking dummy project directories in git and prevents lockfile clutter.

### Question 2: Which consumer application dependency scenarios should the simulation script test?

| Option | Description | Selected |
|--------|-------------|----------|
| Core 4 representative scenarios: Modern Consumer, Legacy Floor (dio 5.2, share_plus 11.0, intl 0.18), Mid-Tier Dio/Http consumer, and Strict Flutter Localization (intl conflict probe) | Covers primary collision vectors without excess solver time | ✓ |
| Exhaustive permutations (8-10 scenarios testing pairwise variations of each core dependency) | Maximum edge-case validation at the expense of longer script execution | |
| You decide | Let the planner define the scenario breakdown based on known pubgrub failure modes | |

**User's choice:** Core 4 representative scenarios
**Notes:** Directly targets the highest-risk version combination archetypes.

### Question 3: How deeply should each simulated consumer scenario be validated beyond pub get?

| Option | Description | Selected |
|--------|-------------|----------|
| Compile & analyze check (dart analyze on a minimal consumer entrypoint referencing flutter_network_inspector) | Confirms both pubgrub resolution and absence of compile-time type incompatibilities | ✓ |
| Pub resolution only (verify exit code 0 on pub get) | Fastest execution, strictly validates solver satisfaction without running analyzer on each scenario | |
| Full test execution (run flutter test inside each consumer scenario) | Maximum validation, but increases simulation runtime significantly | |
| You decide | Choose the best balance of speed and confidence | |

**User's choice:** Compile & analyze check (dart analyze on minimal consumer entrypoint referencing flutter_network_inspector)
**Notes:** Verifies genuine Dart API consumption without the heavyweight overhead of full Flutter widget test bootstrapping.

### Question 4: When should tool/verify_consumer_resolution.sh run in the GitHub Actions workflow?

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated step in the main CI workflow (runs on all PRs and pushes to main) | Guarantees consumer compatibility is enforced before merging any changes | ✓ |
| Scheduled nightly CI job and release tags only | Runs periodically to save PR runner minutes | |
| You decide | Let the planner choose the right trigger frequency | |

**User's choice:** Dedicated step in the main CI workflow (runs on all PRs and pushes to main)
**Notes:** Enforces consumer resolution gating before merge.

---

## Pana Analysis & Packaging Gate Automation

### Question 1: How should pana score verification and publish dry-run validation be implemented?

| Option | Description | Selected |
|--------|-------------|----------|
| Standalone tool script (tool/verify_pana.sh) combining pana score threshold (140/140) and publish --dry-run | Run identically by developers locally and as a CI quality gate | ✓ |
| Inline steps in GitHub Actions CI workflow only | Keeps tooling minimal by configuring pana activation and dry-run purely inside YAML | |
| You decide | Let the planner choose the most developer-friendly structure | |

**User's choice:** Standalone tool script (tool/verify_pana.sh) combining pana score threshold (140/140) and publish --dry-run
**Notes:** Empowers local verification prior to pushing commits.

### Question 2: What score threshold policy should tool/verify_pana.sh enforce?

| Option | Description | Selected |
|--------|-------------|----------|
| Strict 140/140 score threshold (--exit-code-threshold 140) | Guarantees pub.dev maximum score compliance and zero packaging regressions | ✓ |
| Slight tolerance threshold (e.g. 130/140) | Allows minor informational warnings while failing on dependency or platform deductions | |
| You decide | Align strictly with MATRIX-03 requirement | |

**User's choice:** Strict 140/140 score threshold (--exit-code-threshold 140)
**Notes:** Matches requirement MATRIX-03 verbatim.

### Question 3: Where should code formatting (dart format) and linter verification be positioned in CI?

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated Lint & Quality CI job (dart format check, flutter analyze, verify_pana.sh) | Fails fast on formatting or lint before running the full multi-OS test matrix | ✓ |
| Bundle formatting check inside verify_pana.sh | Centralizes all packaging and formatting checks in the single verify_pana script | |
| You decide | Choose the fastest CI pipeline structure | |

**User's choice:** Dedicated Lint & Quality CI job (dart format check, flutter analyze, verify_pana.sh)
**Notes:** Fast-failing gate saves developer time.

### Question 4: How should tool/verify_pana.sh handle environments where network access to pub.dev is offline or restricted?

| Option | Description | Selected |
|--------|-------------|----------|
| Graceful network diagnostic check: attempt dart pub global activate pana, but output actionable failure guidance if offline/unreachable while dry-run checks proceed | Developer experience preserved in offline/sandboxed environments | ✓ |
| Strict failure: immediately exit non-zero if dart pub global activate pana fails for any reason | Strict enforcement everywhere | |
| You decide | Let the planner handle offline/online behavior cleanly | |

**User's choice:** Graceful network diagnostic check
**Notes:** Prevents unhelpful crash traces when developing offline.

---

## CI Workflow Concurrency & Branch Triggers

### Question 1: Which git events and branch filters should trigger the GitHub Actions workflow?

| Option | Description | Selected |
|--------|-------------|----------|
| Push to main + Pull Requests targeting main + workflow_dispatch (manual trigger) | Standard open-source pattern ensuring all PRs and main commits are verified with manual run capability | ✓ |
| Push to all branches + all pull requests | Triggers CI runs on every commit across all remote branches (higher runner usage) | |
| You decide | Configure standard GitHub Actions trigger filters | |

**User's choice:** Push to main + Pull Requests targeting main + workflow_dispatch (manual trigger)
**Notes:** Standard GitHub flow filtering.

### Question 2: How should workflow concurrency and in-progress job cancellation be configured?

| Option | Description | Selected |
|--------|-------------|----------|
| Cancel obsolete PR runs, preserve main branch runs (cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}) | Saves runner queue time on rapid PR commits without canceling main branch builds | ✓ |
| Never cancel in-progress runs | Runs every commit to completion, retaining complete build histories for all pushes | |
| You decide | Configure standard GitHub Actions concurrency settings | |

**User's choice:** Cancel obsolete PR runs, preserve main branch runs
**Notes:** Standard resource optimization.

### Question 3: Which GitHub Action should be used to install Flutter and Dart in CI?

| Option | Description | Selected |
|--------|-------------|----------|
| subosito/flutter-action@v2 with pub-cache caching (cache: true) | Industry-standard action supporting channel/version matrices and built-in caching for fast CI execution | ✓ |
| Custom Flutter installation step via curl/git clone | Avoids third-party action dependency at the expense of longer setup time and manual cache management | |
| You decide | Use the most standard and reliable action available | |

**User's choice:** subosito/flutter-action@v2 with pub-cache caching (cache: true)
**Notes:** Official Flutter Community action with integrated caching.

### Question 4: Should the workflow include a single aggregate gate job for GitHub branch protection rules?

| Option | Description | Selected |
|--------|-------------|----------|
| Aggregate gate job (all-checks-passed) depending on all matrix and verification jobs | Exposes a single stable required check for GitHub branch protection settings | ✓ |
| Individual job statuses only without an aggregate gate | Branch protection requires selecting individual matrix slice names | |
| You decide | Configure standard CI completion reporting | |

**User's choice:** Aggregate gate job (all-checks-passed) depending on all matrix and verification jobs
**Notes:** Avoids breakage when changing matrix slice dimensions.

---

## the agent's Discretion

- Script error handling and temp directory cleanup logic in `tool/verify_consumer_resolution.sh` and `tool/verify_pana.sh`.
- Cache key formatting and job naming conventions in `.github/workflows/ci.yml`.

## Deferred Ideas

None — discussion remained strictly within the scope of Phase 13.
