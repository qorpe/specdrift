---
name: specdrift-change
description: Run a change to SpecDrift itself through the delivery cycle — the evaluator, a verb, a flag, the rule language, the drift profile, the MCP surface, a gate. Use when working inside the specdrift repository on an issue, a defect or a feature.
---

# specdrift-change — the path through the cycle here

This skill enforces the SEQUENCE in `.claude/cycle.md`. It carries no rules of its own: the
rules are in `CLAUDE.md`, which names the six invariants and where this repository's contract
lives. If a rule seems missing, that is a finding to report, not a gap to fill from taste.

## Before anything else

1. `CLAUDE.md` — the invariants, the contract surface, the gates
2. `README.md` — what the tool promises its users, in their words
3. `.claude/cycle.md` — the nine steps

## What is different here, and why

**You are writing the thing other repositories trust.** SpecDrift's output is consumed by CI
jobs that block merges and by agents that stop guessing because they asked it. A wrong finding
is not a cosmetic bug — it teaches a whole repository to do the wrong thing, and the reader
has no reason to doubt it. Two failure modes deserve the same seriousness as a crash:

- a finding whose **message** teaches the wrong fix
- a check that **passes** when the artifacts really did diverge

**The tests are the product.** The mutation gate breaks at 70 for a reason: for a lint engine,
"the tests pass" and "the tests would notice" are different claims, and only the second one is
worth anything. Cycle §4 — write the test, then put the fault back and watch it go red — is
not ceremony here, it is the only evidence that a rule is actually being checked.

**Determinism is testable, so test it.** If a change adds anything that could vary between
runs — enumeration order, a dictionary walk, a path separator, a timestamp — the test for it
is running twice and comparing bytes, not reading the code and deciding it looks fine.

**Reports carry rule ids.** A new check without a stable id is a message nobody can suppress,
search or point at in a review. Give it an id and a message that names the fix.

**The engine stays generic.** A change that makes Goldpath's manifest work by naming a Goldpath
field in `src/` is the wrong fix, however small. The right fix extends the rule language or the
profile schema so any consumer can express it. See `CLAUDE.md` invariant 4.

## Step 6, concretely

`cycle.md` §6 says run this repository's own contract check. Here that is:

```
dotnet build specdrift.sln -c Release
dotnet test specdrift.sln -c Release
./scripts/docs-freshness.sh              # the README still describes the engine
python3 scripts/license-gate.py          # only if the package graph changed
dotnet stryker                           # if you touched evaluator or rule-engine paths
```

Docs freshness is not paperwork. The README is the tool's manual, its Docker tag, its Action
ref and its rule-language reference in one file; when the engine moves and the README does
not, every consumer copies a stale line. The gate has already caught the README sitting two
releases behind on its published pins.

## Step 7, concretely

There is no screen to open. "Run it for real" means running the built tool as a user runs it —
not only through the test host:

```
dotnet run --project src/SpecDrift -- validate <a real manifest> --rules <real rules>
echo "exit=$?"                                     # the exit code IS the contract
dotnet run --project src/SpecDrift -- drift --repo <a real repository>
```

For an MCP change, start `specdrift mcp` and call the tool over stdio. A verb that works in a
unit test and not from a shell has not been delivered.

## Never

- Guess forward past an unknown keyword, version or op to make an input work. Hard-fail is the
  design, not a limitation to route around.
- Change what an exit code means without treating it as a breaking change.
- Add a dependency without answering `CLAUDE.md` invariant 6 in the merge request.
- Bump `<Version>` and leave the README's pins behind.
- Close a defect you could not reproduce.
