module

public import AceLean
public import Mathlib.Data.Nat.Prime.Infinite
public import Mathlib.Basic.Real.Basic
public import Mathlib.Data.Set.Basic

public section

/-! An opt-in starter lexicon backed by actual mathlib definitions. Applications
can import AceLean alone and build their own vocabulary without these phrases. -/

namespace AceLean.MathlibVocabulary

ace_type "natural number" := Nat
ace_type "integer" := Int
ace_type "real number" := Real
ace_type "natural set" := Set Nat

ace_noun "prime number" := Nat.Prime
ace_adjective "prime" := Nat.Prime
ace_adjective "even" := (Even : Nat → Prop)
ace_adjective "positive" := fun n : Nat => 0 < n
ace_adjective "nonnegative" := fun x : Real => 0 ≤ x
ace_adjective "empty" := fun s : Set Nat => s = ∅

ace_relation "equals" := @Eq
ace_relation "is equal to" := @Eq
ace_relation "divides" := (Dvd.dvd : Nat → Nat → Prop)
ace_relation "divide" := (Dvd.dvd : Nat → Nat → Prop)
ace_relation "is less than" := (LT.lt : Nat → Nat → Prop)
ace_relation "is at most" := (LE.le : Nat → Nat → Prop)
ace_relation "is below" := (LE.le : Real → Real → Prop)
ace_relation "belongs to" := fun (n : Nat) (s : Set Nat) => n ∈ s
ace_relation "is a subset of" := (Set.Subset : Set Nat → Set Nat → Prop)

ace_function "successor" := Nat.succ
ace_function "square" := fun x : Real => x * x
ace_constant "zero" := (0 : Nat)
ace_constant "two" := (2 : Nat)
ace_constant "empty set" := (∅ : Set Nat)

end AceLean.MathlibVocabulary
