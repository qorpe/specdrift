#!/usr/bin/env bash
# Docs freshness: the README must not drift from the engine it documents.
#
# SpecDrift's whole thesis is that the space BETWEEN artifacts rots silently.
# This gate applies that thesis to SpecDrift's own repository, in the one place
# the tool cannot check itself: prose. Every claim below is one the README makes
# and the code answers.
#
# Exit 0 clean, 1 stale. Each block reports every finding it has before the
# script exits, so one run tells you everything that is stale.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATUS=0

python3 - "$ROOT" <<'PY'
import pathlib, re, sys

root = pathlib.Path(sys.argv[1])
readme = (root / "README.md").read_text()
csproj = (root / "src/SpecDrift/SpecDrift.csproj").read_text()
program = (root / "src/SpecDrift/Program.cs").read_text()
rules = (root / "src/SpecDrift/Validation/RuleEngine.cs").read_text()
stryker = (root / "stryker-config.json").read_text()

bad = []


def fail(gate, message):
    bad.append(f"  [{gate}] {message}")


# G1 — every version pin in the README is the version the csproj ships.
version = re.search(r"<Version>([^<]+)</Version>", csproj)
if not version:
    fail("G1", "src/SpecDrift/SpecDrift.csproj has no <Version> element")
else:
    v = version.group(1).strip()
    pins = set()
    pins.update(re.findall(r"ghcr\.io/qorpe/specdrift:([0-9][^\s`]*)", readme))
    pins.update(re.findall(r"qorpe/specdrift@v([0-9][^\s`]*)", readme))
    stale = sorted(p for p in pins if p != v)
    if stale:
        fail(
            "G1",
            f"README pins specdrift {', '.join(stale)} but the csproj ships {v} — "
            "the published image and action tags moved and the README did not.",
        )
    if not pins:
        fail("G1", "README pins no specdrift version at all — the run-it-anywhere table lost its tags.")

# G2 — the verbs the CLI dispatches are exactly the verbs the README documents.
dispatched = set(re.findall(r'args\[0\]\s*==\s*"([a-z][a-z-]*)"', program))
dispatched.update(re.findall(r'args\[0\]\s*!=\s*"([a-z][a-z-]*)"', program))
documented = set(re.findall(r"^\s*-\s+\*\*`([a-z][a-z-]*)`\*\*", readme, re.M))
missing = sorted(dispatched - documented)
invented = sorted(documented - dispatched)
if missing:
    fail("G2", f"the CLI dispatches {', '.join(missing)} but the README's 'What it does' list does not.")
if invented:
    fail("G2", f"the README documents {', '.join(invented)} but the CLI dispatches no such verb.")

# G3 — --help names every verb. A verb added without touching Usage is invisible.
usage = re.search(r'Usage = """(.*?)""";', program, re.S)
if not usage:
    fail("G3", "Program.cs has no Usage block to check")
else:
    body = usage.group(1)
    silent = sorted(v for v in dispatched if not re.search(rf"specdrift\s+{re.escape(v)}\b", body))
    if silent:
        fail("G3", f"--help never mentions {', '.join(silent)} — the verb exists but nothing tells a user so.")

# G4 — the `when` ops the README lists are the ops the rule engine accepts.
accepted = set(re.findall(r'"([a-z]+)"', re.search(r"op is not \(([^)]*)\)", rules).group(1)))
listed = set(re.findall(r"`([a-z]+)`", re.search(r"Supported `when` ops:([^\n]*)", readme).group(1)))
if accepted != listed:
    fail(
        "G4",
        f"README lists `when` ops {sorted(listed)} but RuleEngine accepts {sorted(accepted)} — "
        "a rule author would be told to write an op the engine rejects, or would never learn about one it takes.",
    )

# G5 — a mutation threshold quoted in prose is the threshold the config enforces.
configured = re.search(r'"break"\s*:\s*([0-9]+)', stryker)
for doc in ("README.md", "CLAUDE.md"):
    path = root / doc
    if not path.exists():
        continue
    for quoted in re.findall(r"mutation score[^.\n]*?\b([0-9]{2})\b", path.read_text(), re.I):
        if configured and quoted != configured.group(1):
            fail("G5", f"{doc} quotes a mutation break of {quoted}, stryker-config.json enforces {configured.group(1)}.")

if bad:
    print("docs-freshness: STALE")
    print("\n".join(bad))
    sys.exit(1)
print("docs-freshness: README matches the engine (5 gates).")
PY
STATUS=$(( STATUS + $? ))

exit $(( STATUS > 0 ? 1 : 0 ))
