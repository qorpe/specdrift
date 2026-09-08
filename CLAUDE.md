# SpecDrift — working agreement

Deterministic spec lint for manifest-driven golden paths. One executable, one test project,
no service, no state. Read `README.md` for what it does; this file is what must stay true
while you change it.

## The invariants

These are not preferences. A change that breaks one of them is a conversation, not a commit.

**1. It never calls an LLM — LLMs call it.** No network, no model, no clock in any output.
Same inputs must give a byte-identical report. This is the entire reason the tool is trusted
inside an agent loop: an agent that asks SpecDrift gets the same answer this run and next.

**2. The engine never guesses.** An unknown schema assertion keyword is a hard fail. An
unknown manifest schema version is a hard fail. An unknown `when` op is a hard fail. Guessing
forward is how a lint tool starts lying quietly, and a quiet lie in a gate is worse than no
gate.

**3. Exit codes are the public contract.** `0` clean · `1` findings · `2` usage or IO error.
Callers branch on these — CI jobs, the GitHub Action, agents through MCP. Changing what an
exit code means is a breaking change even when no signature moved.

**4. Profiles are data; the engine is generic.** SpecDrift knows nothing about any particular
platform. The schema, the invariant rules and the drift profile are DATA each golden path
ships in its own repository. Never special-case a consumer's field names in the engine — if
Goldpath needs something SpecDrift cannot express, the gap is in the rule language, and that
is where to fix it.

**5. Detection is textual, and the reports say so.** Drift detection reads files as text. It
reports, it never auto-fixes. Overstating the strength of the check in a message is a defect.

**6. Dependencies are earned.** The JSON-Schema evaluator is in-tree because every candidate
library failed this repository's own gates: one ships a maintenance-fee EULA in its NuGet
binaries, one compiles code at runtime, one silently skips `if/then`. `scripts/license-gate.py`
enforces the first of those, and it runs in CI. Adding a package means answering it.

## Where the contract lives

There is no `PublicAPI.Shipped.txt` here — the surface a consumer touches is not a class
library, it is:

- the **CLI**: verbs, flags, exit codes (`src/SpecDrift/Program.cs`)
- the **report shape**: `--format json` output, rule ids, severities
- the **MCP tools**: `spec_validate`, `spec_drift` over stdio
- the **rule and profile languages**: `rules.yaml` and `.specdrift/drift.yaml`
- the **embedded schema**: `Resources/goldpath-manifest.schema.v1.json`, version-stamped with
  the tool

Each of those is documented in `README.md`, and `scripts/docs-freshness.sh` is what stops the
README from drifting away from them. That script is this repository's answer to `cycle.md` §6:
**it is the contract check.**

## The gates

CI runs four, and so should you before offering a change:

```
dotnet build specdrift.sln -c Release
dotnet test specdrift.sln -c Release
python3 scripts/license-gate.py          # no unacceptable licence reaches the package graph
dotnet stryker                           # mutation score, break at 70
./scripts/docs-freshness.sh              # the README still describes the engine
```

The mutation gate is the one that matters most here. A lint tool's tests are the only thing
standing between a wrong report and a user who believes it, so "the tests pass" is not the
claim — "the tests would notice" is.

## Releasing

Tag `v<version>` matching `<Version>` in `src/SpecDrift/SpecDrift.csproj` on green `main`.
Publication is **trusted publishing**: the workflow exchanges its GitHub OIDC token for a
short-lived nuget key. `user:` in the login step is the USERNAME of the policy creator, not the
org that owns the package — this has been got wrong once already.

Bumping `<Version>` changes what the README's Docker and Action pins must say. The docs
freshness gate enforces that; it caught the README sitting two releases behind.

## The delivery cycle

`.claude/cycle.md` carries the nine steps. `.claude/skills/specdrift-change/` is the path
through them for this repository. Neither restates the rules above — they point here.
