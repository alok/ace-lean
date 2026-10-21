module

import examples.Mathematics
meta import Lean.Util.CollectAxioms

open Lean Elab Command

-- Fail the audit if any checked mathematical example acquires sorryAx or a
-- project-defined axiom. These three are Lean/mathlib's standard foundations.
run_cmd do
  let allowed := #[``propext, ``Classical.choice, ``Quot.sound]
  let theorems := #[
    ``AceLean.Examples.unboundedNaturals,
    ``AceLean.Examples.arbitrarilyLargePrimes,
    ``AceLean.Examples.primesArePositive,
    ``AceLean.Examples.nonnegativeSquares,
    ``AceLean.Examples.noMembersOfEmptySet,
    ``AceLean.Examples.subsetsAreReflexive,
    ``AceLean.Examples.genericReflexivity,
    ``AceLean.Examples.genericOrderReflexivity]
  for name in theorems do
    let axioms ← collectAxioms name
    for dependency in axioms do
      unless allowed.contains dependency do
        throwError "Forbidden axiom {dependency} in {name}"
    logInfo m!"{name}: checked; axioms = {axioms}"
