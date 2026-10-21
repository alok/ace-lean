# Contributing

Use the pinned Lean/mathlib versions and normal Lake dependencies. Keep the pure
surface parser, lexical scope resolution and Lean elaboration separate.

For a grammar change, update docs/GRAMMAR.md with its exact reading and unsupported
neighbors. Add semantic tests in AceLean/Tests.lean comparing the output to the
intended Lean formula by definitional equality. Include a case where a plausible
alternative interpretation differs. Add rejection/position tests in
scripts/check_diagnostics.py for bad scope, bad types and ambiguous input.

Run:

```sh
lake build
python3 scripts/check_diagnostics.py
lake env lean examples/Audit.lean
```

Use ordinary proofs in examples. Do not add custom axioms, `sorry`, opaque unsafe
translation shortcuts, network proof services, or implicit theorem assumptions.
Only original or license-compatible code belongs in the repository; preserve
upstream notices if code is ever incorporated. Explain material licensing changes
in the contribution.
