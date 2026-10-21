module

import AceLean.Mathlib
import examples.Mathematics

/-! `rfl` tests assert definitional equality to the intended Lean proposition.
They detect scope, negation and precedence bugs even if a wrong reading happens
to be mathematically provable. This file is built by the default Lake target. -/

namespace AceLean.Tests

example : (ace% "Every natural number n is less than some natural number m.") =
    (∀ n : Nat, ∃ m : Nat, n < m) := rfl

example : (ace% "Some natural number n is at most every natural number m.") =
    (∃ n : Nat, ∀ m : Nat, n ≤ m) := rfl

example : (ace% "Every prime number p is positive.") =
    (∀ p : Nat, Nat.Prime p → 0 < p) := rfl

example : (ace% "A prime number p is even.") =
    (∃ p : Nat, Nat.Prime p ∧ Even p) := rfl

example : (ace% "No prime number p is even.") =
    (∀ p : Nat, Nat.Prime p → ¬ Even p) := rfl

example : (ace% "Every natural number n is not prime.") =
    (∀ n : Nat, ¬ Nat.Prime n) := rfl

example : (ace% "Not (every natural number n is prime).") =
    (¬ ∀ n : Nat, Nat.Prime n) := rfl

example : (ace% "It is false that (every natural number n is prime).") =
    (¬ ∀ n : Nat, Nat.Prime n) := rfl

example : (ace% "Every natural number n does not divide some natural number m.") =
    (∀ n : Nat, ¬ ∃ m : Nat, n ∣ m) := rfl

example : (ace% "For every natural number n, n is prime and n is positive.") =
    (∀ n : Nat, Nat.Prime n ∧ 0 < n) := rfl

example : (ace% "There is a natural number n such that n is prime or n is even.") =
    (∃ n : Nat, Nat.Prime n ∨ Even n) := rfl

example : (ace% "There is no prime number p such that p is even.") =
    (∀ p : Nat, Nat.Prime p → ¬ Even p) := rfl

example : (ace% "For every natural number n, if n is prime then n is positive and n is at most n.") =
    (∀ n : Nat, Nat.Prime n → (0 < n ∧ n ≤ n)) := rfl

example : (ace% "Two is prime or zero is positive and two is even.") =
    (Nat.Prime 2 ∨ (0 < (0 : Nat) ∧ Even (2 : Nat))) := rfl

example : (ace% "(Two is prime or zero is positive) and two is even.") =
    ((Nat.Prime 2 ∨ 0 < (0 : Nat)) ∧ Even (2 : Nat)) := rfl

example : (ace% "Two is prime iff two is even.") =
    (Nat.Prime 2 ↔ Even (2 : Nat)) := rfl

example : (ace% "Every natural number n equals the natural number n.") =
    (∀ n : Nat, n = n) := rfl

example : (ace% "For every natural number, it equals the natural number.") =
    (∀ n : Nat, n = n) := rfl

-- Recency: the unlabelled definite noun denotes the innermost matching binder.
example : (ace% "For every natural number n, for every natural number m, the natural number equals m.") =
    (∀ _ : Nat, ∀ m : Nat, m = m) := rfl

-- Specificity: an explicit appositional label selects the outer binder.
example : (ace% "For every natural number n, for every natural number m, the natural number n equals n.") =
    (∀ n : Nat, ∀ _ : Nat, n = n) := rfl

example : (ace% "Every natural number n is less than the successor of n.") =
    (∀ n : Nat, n < Nat.succ n) := rfl

-- Function arguments also participate in textual quantifier lifting.
example : (ace% "Every natural number n is at most successor of some natural number m.") =
    (∀ n : Nat, ∃ m : Nat, n ≤ Nat.succ m) := rfl

example (x : Real) : (ace% "X equals 2.") = (x = (2 : Real)) := rfl
example (x : Real) : (ace% "2 equals x.") = ((2 : Real) = x) := rfl
example : (ace% "2 is below 3.") = ((2 : Real) ≤ 3) := rfl
example : (ace% "2 equals 2.") = ((2 : Nat) = 2) := rfl
example : (ace% "No natural number n belongs to empty set.") =
    (∀ n : Nat, ¬ n ∈ (∅ : Set Nat)) := rfl

universe u v

example (α : Type u) : (ace% "Every element x equals x." with ("element" := α)) =
    (∀ x : α, x = x) := rfl

example (α : Type u) :
    (ace% "Every element x equals x." with ("element" := α)) := by
  intro x
  rfl

example : (ace% "Every large natural x equals x." with ("large natural" := ULift.{1} Nat)) =
    (∀ x : ULift.{1} Nat, x = x) := rfl

example (α : Type u) [Preorder α] :
    (ace% "Every element x precedes x." with ("element" := α)) = (∀ x : α, x ≤ x) := rfl

-- Independent local carriers in one sentence; heterogeneous relation domains.
ace_relation "maps via" := fun (x : Nat) (y : Int) => Int.ofNat x = y

example : (ace% "Every natural number n maps via some integer z.") =
    (∀ n : Nat, ∃ z : Int, Int.ofNat n = z) := rfl

example : (ace% "Every domain n maps via some codomain z."
    with ("domain" := Nat) with ("codomain" := Int)) =
    (∀ n : Nat, ∃ z : Int, Int.ofNat n = z) := rfl

ace_relation "compares" := fun n m : Nat => n < m
ace_relation "compares with" := fun n m : Nat => n ≤ m

-- Longest matching must choose the second, mathematically distinct relation.
example : (ace% "Every natural number n compares with n.") =
    (∀ n : Nat, n ≤ n) := rfl

-- Parser AST, source spans and deterministic rejection can be tested without MetaM.
private def words : Array WordEntry := #[
  ⟨"natural number", #["natural", "number"], .type⟩,
  ⟨"prime", #["prime"], .adjective⟩]

#guard (parse words "Every natural number n is prime.").isOk
#guard !(parse words "Every natural number n that is prime is prime.").isOk
#guard !(parse words "Every natural number n is prime. It is prime.").isOk
#guard ((tokenize "α is prime.").toOption.get!)[0]!.span.stop == 2

end AceLean.Tests
