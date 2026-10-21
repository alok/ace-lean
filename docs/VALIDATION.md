# Validation record

Checked on an Apple Silicon Mac with the installed Lean release:

```text
Lean 4.35.0, arm64-apple-darwin24.6.0
Lean commit eb6cafb7290e8bd5f2937522d8d804f58f02bafc
mathlib commit 56a005855ea17e0b0958f73ec801ae140b0a1679 (v4.35.0)
```

Local checks for the initial release:

| Command/check | Result |
| --- | --- |
| `LAKE_ARTIFACT_CACHE=false lake build` | Passed; implementation, tests, import-conflict fixtures and examples/audit |
| `AceLean/Tests.lean` in that build | 33 definitional-equality formula comparisons, one generic proof example, four parser/UTF-8 assertions |
| `python3 scripts/check_diagnostics.py` | All 42 expected-failure cases passed, including exact Unicode/multiline source positions |
| `lake env lean examples/Audit.lean` | All eight named mathematical examples passed the axiom allowlist |
| README core example with plain `import AceLean` | Compiled without mathlib imports |
| `git diff --cached --check` | Passed |
| Publication file inspection | Only this project's source/docs/license/manifest/workflow; build caches ignored; no credential or unrelated-private-context findings |

The failure suite covers unknown vocabulary, inaccessible references across
conjunction/disjunction/conditionals/negation, shadowing, unmatched definites and
pronouns, wrong data types/function domains, unsupported relative clauses/modals,
trailing text, punctuation/arithmetic, missing delimiters, escapes/raw strings,
wrong vocabulary arities/categories, duplicate phrases, local carrier conflicts,
an intentionally invalid mathematical proof, imported vocabulary conflicts,
registration rollback, and unresolved carrier types.

Named example dependencies:

| Example | Axioms |
| --- | --- |
| unboundedNaturals | none |
| arbitrarilyLargePrimes | propext, Classical.choice, Quot.sound |
| primesArePositive | propext |
| nonnegativeSquares | propext, Classical.choice, Quot.sound |
| noMembersOfEmptySet | none |
| subsetsAreReflexive | none |
| genericReflexivity | none |
| genericOrderReflexivity | none |

No named example depends on `sorryAx` or a custom axiom. The frontend-to-English
correspondence is tested and documented, not formally proved. The kernel checks
the generated propositions and their supplied Lean proofs.

GitHub Actions is configured to repeat the build, diagnostics and axiom audit on
Linux. This local record does not assert a remote CI result; consult the
repository's Actions checks for the corresponding commit.
