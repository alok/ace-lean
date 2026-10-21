#!/usr/bin/env python3
"""Integration tests of Lean JSON diagnostics, including exact source locations.

Runs each rejection in a fresh file, preventing error recovery or one failed
registration from concealing a later regression. Uses only Python's stdlib.
"""

import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
HEADER = "module\nimport AceLean.Mathlib\n\n"

# name, source, required diagnostic fragment, exact token (or None)
CASES = [
    ("unknown-noun", '#check ace% "Every dragon d is prime."', "Unknown noun", "dragon"),
    ("unknown-property", '#check ace% "Every natural number n is shiny."', "Unknown property", "shiny"),
    ("unbound", '#check ace% "x is prime."', "Unknown or inaccessible reference 'x'", "x is"),
    ("sibling-leak", '#check ace% "Every natural number n is prime and n is positive."', "Unknown or inaccessible", "n is positive"),
    ("conditional-leak", '#check ace% "If a natural number n is prime then n is positive."', "Unknown or inaccessible", "n is positive"),
    ("negation-leak", '#check ace% "Not (a natural number n is prime) and n is positive."', "Unknown or inaccessible", "n is positive"),
    ("disjunction-leak", '#check ace% "A natural number n is prime or n is positive."', "Unknown or inaccessible", "n is positive"),
    ("definite-no-antecedent", '#check ace% "The natural number is prime."', "no matching accessible antecedent", "natural number"),
    ("pronoun-no-antecedent", '#check ace% "It is prime."', "no accessible antecedent", "It is"),
    ("shadow", '#check ace% "For every natural number n, for every integer n, n equals n."', "Shadowing is rejected", "every integer"),
    ("local-shadow", '#check fun (n : Nat) => ace% "Every natural number n is prime."', "Shadowing is rejected", "Every natural"),
    ("wrong-carrier", '#check ace% "Every real number x is prime."', "ACE type mismatch", "Every real"),
    ("mixed-equality", '#check ace% "Every natural number n equals some real number x."', "ACE type mismatch", "some real"),
    ("wrong-function-domain", '#check ace% "Every real number x equals successor of x."', "ACE type mismatch", "x."),
    ("relative-clause", '#check ace% "Every natural number n that is prime is positive."', "Relative clauses", "that"),
    ("trailing-text", '#check ace% "Two is prime. Two is even."', "Only one sentence", "Two is even"),
    ("arithmetic", '#check ace% "Two equals 1 + 1."', "Unsupported character", "+"),
    ("question", '#check ace% "Two is prime?"', "Unsupported character", "?"),
    ("global-comma", '#check ace% "For every natural number n n is prime."', "Expected ','", "n is prime"),
    ("global-such-that", '#check ace% "There is a natural number n, n is prime."', "Expected 'such'", ","),
    ("unclosed", '#check ace% "Not (two is prime."', "Expected ')'", "."),
    ("unsupported-modal", '#check ace% "Two can be prime."', "Expected 'is'", "can"),
    ("escape", '#check ace% "Two is\\nprime."', "do not support escape sequences", None),
    ("raw-string", '#check ace% r#"Two is shiny."#', "raw string literals are unsupported", None),
    ("utf8-column", '#check ace% "For every natural number α, β is prime."', "Unknown or inaccessible reference 'β'", "β"),
    ("multiline-column", '#check ace% "For every natural number n,\n  n is shiny."', "Unknown property", "shiny"),
    ("registration-wrong-type", 'ace_type "bad carrier" := (3 : Nat)', "ace_type expects a type", None),
    ("registration-prop", 'ace_type "proposition" := True', "not Prop", None),
    ("registration-wrong-arity", 'ace_adjective "bad" := Nat.add', "result Prop", None),
    ("registration-binary-arity", 'ace_relation "bad relation" := Nat.Prime', "2 explicit", None),
    ("registration-function", 'ace_function "bad function" := Nat.Prime', "not a type or proposition", None),
    ("registration-proof", 'ace_constant "proof" := Nat.prime_two', "not a type or proof", None),
    ("registration-duplicate", 'ace_type "natural number" := Int', "already registered", None),
    ("registration-capitals", 'ace_type "New type" := Nat', "lowercase", None),
    ("registration-keyword", 'ace_type "every number" := Nat', "reserved grammar word", None),
    ("local-prop", '#check ace% "Every element x equals x." with ("element" := True)', "not Prop", None),
    ("local-duplicate", '#check ace% "Every element x equals x." with ("element" := Nat) with ("element" := Int)', "Duplicate local carrier", None),
    ("local-category-conflict", '#check ace% "Every prime number x equals x." with ("prime number" := Nat)', "override only ace_type", None),
    ("false-proof", 'example : ace% "Every natural number n is prime." := by\n  intro n\n  exact Nat.prime_two', "Type mismatch", None),
    ("import-conflict", 'import AceLean.Tests.ImportLeft\nimport AceLean.Tests.ImportRight\n#check ace% "Two is contested."', "Conflicting imported vocabulary", None),
    ("registration-rollback", 'ace_adjective "fresh" := Nat.add\nace_adjective "fresh" := Nat.Prime\n#check ace% "Two is fresh."', "result Prop", None),
    ("unresolved-carrier", 'ace_type "unspecified" := fun {α : Type} => α\n#check ace% "Every unspecified x equals x."', "unresolved type", None),
]


def main():
    directory = ROOT / ".lake" / "diagnostic-tests"
    directory.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, LAKE_ARTIFACT_CACHE="false")
    failed = []
    for index, (name, body, fragment, token) in enumerate(CASES, 1):
        source = HEADER + body + "\n"
        path = directory / f"{name}.lean"
        path.write_text(source)
        result = subprocess.run(
            ["lake", "env", "lean", "--json", str(path)],
            cwd=ROOT, env=env, text=True, capture_output=True, timeout=30,
        )
        messages = []
        for line in result.stdout.splitlines():
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                continue
            if message.get("severity") == "error":
                messages.append(message)
        matching = [m for m in messages if fragment in m.get("data", "")]
        reason = None
        if result.returncode == 0 or not matching or len(messages) != 1:
            reason = f"expected failure containing {fragment!r}: {result.stdout}{result.stderr}"
        elif token:
            # Lean JSON columns count Unicode code points, not UTF-8 bytes.
            offset = source.index(token, len(HEADER))
            line = source.count("\n", 0, offset) + 1
            column = len(source[:offset].rsplit("\n", 1)[-1])
            if not any(m.get("pos") == {"line": line, "column": column} for m in matching):
                reason = f"expected {line}:{column}, got {[m.get('pos') for m in matching]}"
        if reason:
            failed.append((name, reason))
            print(f"FAIL {name}: {reason}", flush=True)
        elif index % 10 == 0:
            print(f"Checked {index}/{len(CASES)} diagnostic cases", flush=True)
    if failed:
        print(f"{len(failed)}/{len(CASES)} diagnostic tests failed")
        return 1
    print(f"PASS {len(CASES)} diagnostic tests (including exact Unicode/multiline source positions)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
