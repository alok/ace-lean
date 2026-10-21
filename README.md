# ACE Lean

A deterministic, Attempto Controlled English inspired language for **Lean 4.35.0**,
with a typed vocabulary and an opt-in mathlib lexicon. This is an executable,
bounded research prototype, **not full ACE or an Attempto Parsing Engine port**.

```lean
import AceLean.Mathlib

theorem arbitrarilyLargePrimes :
    ace% "For every natural number n, there is a prime number p such that n is at most p." := by
  intro n
  obtain ⟨p, hn, hp⟩ := Nat.exists_infinite_primes n
  exact ⟨p, hp, hn⟩
```

That statement elaborates to `∀ n : Nat, ∃ p : Nat, Nat.Prime p ∧ n ≤ p`.
The restricted noun `prime number` uses mathlib's actual `Nat.Prime`, and the proof
uses mathlib's theorem. The compiler never assumes an English sentence is true.

## Run

Install [elan](https://github.com/leanprover/elan), Python 3, and Git, then:

```sh
git clone https://github.com/alok/ace-lean.git
cd ace-lean
lake update
lake exe cache get Mathlib.Data.Nat.Prime.Infinite Mathlib.Basic.Real.Basic Mathlib.Data.Set.Basic
lake build
python3 scripts/check_diagnostics.py
lake env lean examples/Audit.lean
```

The dependency manifest pins mathlib's `v4.35.0` tag to
`56a005855ea17e0b0958f73ec801ae140b0a1679`. Its `lean-toolchain` is
`leanprover/lean4:v4.35.0`, matching this project. The core `import AceLean` uses
Lean alone; `import AceLean.Mathlib` loads the supplied mathematical vocabulary.
The Lake dependency is a normal official mathlib Git dependency, with no local
path overrides. In a filesystem sandbox, use `LAKE_ARTIFACT_CACHE=false lake build`
to avoid Lake's optional system artifact-cache writes.

To use it from another Lean 4.35.0 project, add this to `lakefile.toml`:

```toml
[[require]]
name = "aceLean"
git = "https://github.com/alok/ace-lean.git"
rev = "v0.1.0"
```

## Write mathematics

`ace% "..."` is a **proposition-valued Lean term**: use it in theorem statements,
assumptions, `have`, or definitions. `#ace "..."` displays the generated Lean
proposition. `#ace_vocab` displays each phrase's checked declaration and type.
Proofs remain normal Lean proofs and tactics.

```lean
example : ace% "Every prime number p is positive." := by
  intro p hp
  exact hp.pos

example : ace% "No natural number n belongs to the empty set." := by
  intro n
  exact Set.notMem_empty n

universe u
example (α : Type u) :
    ace% "Every element x equals x." with ("element" := α) := by
  intro x
  rfl
```

Local carrier bindings connect generic nouns to surrounding Lean types without
storing local variables in the persistent lexicon. Multiple `with (...)` clauses
are allowed. Lean supplies implicit type arguments, universe levels, numeral
instances and typeclass instances. Data coercions are deliberately explicit in
the registered Lean definitions, so a mistaken real/natural comparison is an error.

## Register domain vocabulary

```lean
import AceLean

ace_type "natural number" := Nat
ace_noun "positive number" := fun n : Nat => 0 < n
ace_adjective "positive" := fun n : Nat => 0 < n
ace_relation "is less than" := (LT.lt : Nat → Nat → Prop)
ace_function "successor" := Nat.succ
ace_constant "one" := (1 : Nat)

example : ace% "Every natural number n is less than successor of n." := by
  exact Nat.lt_succ_self
```

Registration validates the actual Lean type. Nouns/adjectives need one explicit
data argument and result `Prop`; relations need two; functions need one explicit
argument and a data result. Implicit type/instance arguments are supported.
Named constants can include sets and other function-like data. Vocabulary is
stored in an environment extension, exported through `.olean` files, and checked
for duplicate or conflicting imported phrases. Every phrase has one category and
meaning. Words match whole tokens; the longest registered phrase wins.

## Scope is visible

| Sentence | Meaning |
| --- | --- |
| Every natural number n is less than some natural number m. | `∀ n, ∃ m, n < m` |
| Some natural number n is at most every natural number m. | `∃ n, ∀ m, n ≤ m` |
| Every prime number p is positive. | `∀ p, Nat.Prime p → 0 < p` |
| A prime number p is even. | `∃ p, Nat.Prime p ∧ Even p` |
| Every natural number n is not prime. | `∀ n, ¬ Nat.Prime n` |
| Not (every natural number n is prime). | `¬ ∀ n, Nat.Prime n` |
| For every natural number n, n is prime and n is positive. | `∀ n, Nat.Prime n ∧ 0 < n` |

Local quantifiers scope over their atomic clause, in subject-to-object order.
Global `for every ... ,` and `there is ... such that ...` extend over the following
formula. `and` binds tighter than `or`; parentheses override grouping. Conditional
consequents extend to the end of the following formula. Labels and definite noun
phrases resolve only to accessible lexical binders. `it` chooses the most recent
binder; explicit labels are clearer with several entities. Shadowing is rejected.

These rules intentionally omit ACE's discourse representation machinery. A local
existential in one conjunct or an `if` antecedent does **not** become available in
the next conjunct or the `then` arm. Use a global quantifier instead. Unresolved
definite descriptions are errors; they do not introduce new entities.

## Diagnostics and boundaries

Unknown words, inaccessible variables, duplicate phrases, wrong vocabulary types,
type mismatches, unsupported punctuation, trailing sentences and unsupported
grammar report Lean diagnostics at the relevant source token. Strings use actual
Unicode and actual newlines; escapes are rejected to preserve exact source spans.
The test runner checks Unicode and multiline positions against Lean's JSON output.

There are no relative clauses, plural/cardinality quantifiers, passives, modalities,
questions, automatic morphology, arithmetic parser, cross-sentence anaphora,
donkey conditionals, or English proof language yet. Ordinary Lean remains available
around `ace%`. See the [grammar](docs/GRAMMAR.md),
[architecture and proof boundary](docs/ARCHITECTURE.md),
[research and provenance](docs/RESEARCH.md), and [roadmap](docs/ROADMAP.md).

## Checks and licensing

`lake build` builds the implementation, mathematical examples and semantic tests.
The tests compare generated propositions to explicit Lean formulas by `rfl`,
including quantifier order, restricted nouns, negation, precedence, reference
resolution, function scope, polymorphism and universes. The Python integration
suite checks expected failures and diagnostic positions. `examples/Audit.lean`
checks named theorem dependencies and rejects `sorryAx` or custom axioms.

Original implementation: Apache-2.0, see [LICENSE](LICENSE). Lean and mathlib keep
their upstream licenses. No Attempto, Verbose Lean or Natural Lean code is bundled.
Contributions should include a documented semantic reading and positive/negative
scope tests; see [CONTRIBUTING.md](CONTRIBUTING.md). Recorded local checks and the
precise trust boundary are in [VALIDATION.md](docs/VALIDATION.md).
