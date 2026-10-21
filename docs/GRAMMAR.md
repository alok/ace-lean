# Grammar and semantics, version 0.1

This document specifies ACE Lean's accepted subset. It is normative for this
project, not a specification of Attempto Controlled English. Vocabulary phrases
are registered in Lean before a sentence is elaborated. ASCII case is folded,
including variable labels; other Unicode characters are preserved. Matching uses
complete tokens and the longest matching phrase.

```ebnf
sentence    = formula, ["."] ;
formula     = "for", ("every" | "each"), noun, [label], ",", formula
            | "there is", ("a" | "an" | "some" | "no"), noun, [label],
              "such that", formula
            | "if", disjunction, "then", formula
            | disjunction, ["iff", formula] ;
disjunction = conjunction, {"or", conjunction} ;
conjunction = primary, {"and", primary} ;
primary     = "(", formula, ")"
            | "not", "(", formula, ")"
            | "it is false that", "(", formula, ")"
            | np, relation, np
            | np, "is", ["not"], ["a" | "an"], property
            | np, "does not", relation, np ;
np          = determiner, noun, [label]
            | "the", noun, [label]
            | ["the"], function, "of", np
            | ["the"], constant
            | numeral | label | "it" ;
determiner  = "every" | "each" | "a" | "an" | "some" | "no" ;
noun        = registered-type | registered-restricted-noun ;
property    = registered-adjective | registered-restricted-noun ;
```

Use ordinary Lean quoted strings; raw string literals and escape sequences are
rejected. The prose grammar's spaces can be any whitespace, including actual newlines.
An optional label is one non-reserved token that does not start a vocabulary
phrase. Numerals are nonnegative decimal integers, interpreted through Lean's
`OfNat` mechanism with their actual expected type. A label may use Lean identifier
letters, Unicode and subscripts; question marks, exclamation marks and apostrophes
are excluded. Vocabulary phrases use lowercase letters/hyphens with single spaces.
Each phrase has one meaning/category; overloads are rejected. A registered binary
phrase takes precedence over the generic `is <property>` rule.

## Quantifiers

Let a noun carry type `T` and an optional restriction `R : T → Prop`.

| Quantifier | Bare carrier | Restricted noun |
| --- | --- | --- |
| every/each | `∀ x : T, P x` | `∀ x : T, R x → P x` |
| a/an/some | `∃ x : T, P x` | `∃ x : T, R x ∧ P x` |
| no | `∀ x : T, ¬ P x` | `∀ x : T, R x → ¬ P x` |

Local subject and object quantifiers lift in textual order over one atomic clause.
Quantified function arguments participate in that order as well. A globally
introduced binder scopes over the entire following formula, including both sides
of a connective or conditional, until the enclosing parenthesis or sentence end.
`there is no ... such that ...` uses the same universal-negative reading as `no`.
No existential import is assumed for universal statements.

Verbal/copular negation is **after the subject binder and before the object
binder**. For example, `Every natural number n does not divide some natural number m`
means `∀ n, ¬ ∃ m, n ∣ m`. The ordinary grammatical infinitive `divide` and finite
form `divides` are separately registered synonyms; morphology is never guessed.
Sentential `not (...)` and `it is false that (...)` negate the entire grouped
formula, including its quantifiers. Parentheses are required after these forms.

`and` binds tighter than `or`. `iff` has lower precedence and associates to the
right. `if ... then ...` has a disjunction antecedent and a full-formula consequent;
parentheses allow nested conditionals/global quantifiers in an antecedent.

## References and accessibility

Labels resolve to an accessible DSL binder first, then a data variable from the
surrounding Lean local context. DSL binders cannot shadow an accessible label or
Lean local name. Case-fold collisions among Lean local names are errors.

`the <noun>` chooses the most recent accessible binder introduced using that exact
noun phrase. `the <noun> <label>` additionally requires the label. `it` chooses
the most recent accessible binder; it has no gender or reflexivity rules.
Types alone do not establish noun identity: a `prime number` is not automatically
an antecedent for `the natural number`. This avoids using type inference as a
hidden linguistic disambiguator.

Global binders remain accessible throughout their bodies. Local binders remain
accessible only within the atomic clause in which they are introduced. Bindings
in sibling conjunction/disjunction/implication arms never propagate to each other.
There is no discourse state between `ace%` terms, nor between sentences. Multiple
sentences in one string are rejected. Unresolved definite phrases are errors.

## Supported mathematical extension points

`ace_type` maps a noun to a data carrier. `ace_noun` infers its carrier from a
unary Lean predicate. `ace_adjective`, `ace_relation`, `ace_function`, and
`ace_constant` map other categories to checked definitions. Implicit types and
instances are instantiated during use. Arity refers to explicit arguments in the
registered type, without unfolding a function-like data carrier into more
arguments. Constants may themselves be sets or function values.

Local `with ("noun" := T)` bindings add or override a carrier for a single `ace%`
term. They cannot override a different vocabulary category. This supports generic
`Type u` parameters without leaking local context into exported declarations.

## Deliberately unsupported

Relative clauses, coordinated verb phrases with an omitted subject, automatic
inflection, plural/cardinality quantifiers, passives, modals, strings inside the
language, questions, commands, discourse continuation, donkey conditionals, and
arithmetic expressions are rejected. Define a new typed phrase for a useful
domain concept; do not rely on an unsupported English reading.

ACE Lean also omits ACE's definite-to-indefinite fallback, gender/number matching,
reflexive-pronoun constraints, disjunct-to-disjunct references and discourse
representation semantics. The `with` carrier annotations, mandatory global comma,
grouped negation and `iff` spelling are explicit project extensions/conventions.
