module

public import AceLean.Mathlib

public section

namespace AceLean.Examples

/-- Quantifiers lift in textual order: ∀ n, ∃ m, n < m. -/
theorem unboundedNaturals :
    ace% "Every natural number n is less than some natural number m." := by
  intro n
  exact ⟨n + 1, Nat.lt_succ_self n⟩

/-- A restricted noun is a mathematical predicate, not a new uninterpreted sort.
The generated proposition is ∀ n, ∃ p, Nat.Prime p ∧ n ≤ p. -/
theorem arbitrarilyLargePrimes :
    ace% "For every natural number n, there is a prime number p such that n is at most p." := by
  intro n
  obtain ⟨p, hn, hp⟩ := Nat.exists_infinite_primes n
  exact ⟨p, hp, hn⟩

theorem primesArePositive : ace% "Every prime number p is positive." := by
  intro p hp
  exact hp.pos

-- A new phrase can immediately use an existing mathlib definition.
ace_adjective "square-nonnegative" := fun x : Real => 0 ≤ x * x

theorem nonnegativeSquares : ace% "Every real number x is square-nonnegative." := by
  intro x
  exact mul_self_nonneg x

theorem noMembersOfEmptySet :
    ace% "No natural number n belongs to the empty set." := by
  intro n
  exact Set.notMem_empty n

theorem subsetsAreReflexive :
    ace% "Every natural set s is a subset of s." := by
  intro s
  exact Set.Subset.refl s

-- Universes and generic mathematical structures come from Lean's local context.
universe u

theorem genericReflexivity (α : Type u) :
    ace% "Every element x equals x." with ("element" := α) := by
  intro x
  rfl

ace_relation "precedes" := fun {α : Type u} [Preorder α] (x y : α) => x ≤ y

theorem genericOrderReflexivity (α : Type u) [Preorder α] :
    ace% "Every element x precedes x." with ("element" := α) := by
  intro x
  exact le_refl x

-- See the elaborated proposition without introducing an assumption:
#ace "Every prime number p is positive."
#ace "Every natural number n is less than some natural number m."

end AceLean.Examples
