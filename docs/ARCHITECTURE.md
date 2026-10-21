# Architecture and proof boundary

The frontend is a parser and elaborator, not a text-replacement macro.

```text
Lean string syntax + imported vocabulary
              │
              ▼
Parser: UTF-8 tokens → Surface.Formula / Surface.NP
              │
              ▼
Scope: lexical references → unique binder IDs + Scoped.Formula
              │
              ▼
Elab: actual Lean types, universes, implicits and instances → Expr : Prop
              │
              ▼
Lean theorem elaboration → proof term → kernel type checking
```

`Syntax.lean` defines surface and resolved ASTs. `Parser.lean` is a deterministic,
pure lexer/parser over registered token phrases. It consumes the entire sentence.
`Scope.lean` is a separate pure pass using continuation-based quantifier lifting;
its IDs avoid name capture during Lean elaboration. It rejects unresolved
references and shadowing before type elaboration begins.

`Vocabulary.lean` checks Lean definitions and stores their names/phrases/categories
in a persistent environment extension. Registration creates an exposed abbreviation
so that imported modules retain the actual mathematical meaning. The actual
declaration name is resolved through Lean, including module privacy and hygiene;
it is never guessed by concatenating strings. A failed registration restores the
command state. Duplicate phrases are rejected at registration and conflicting
imported lexicons are rejected at use. Prefix-overlapping phrases are allowed and
use deterministic longest matching.

`Elab.lean` instantiates these checked definitions with fresh universe/type
metavariables, elaborates data against the expected argument domains, and lets
Lean synthesize numeral/typeclass instances. It extracts the alias body so users
see normal mathematical names in goals. No data coercion is inserted behind the
user's back. Local carrier expressions remain in their surrounding Lean context.
The backend creates normal `Forall`, `Exists`, `And`, `Or`, `Not`, implication,
equality/relation applications, and `Iff` expressions. It checks the final
expression and rejects unresolved expression metavariables.

## Why an elaborator

A macro cannot inspect the type of `Nat.Prime`, validate predicate arity, infer
the carrier of a restricted noun, use an ambient universe-polymorphic type, or
resolve a `Preorder` instance. A full external ACE parser/DRS engine would add a
large trusted semantic bridge and a different licensing/dependency surface.
This implementation uses a small independent frontend plus Lean's native
elaboration facilities. Ordinary Lean proof syntax composes with it immediately.

## Diagnostics

Every token carries a half-open UTF-8 byte span. Source references are synthetic
Lean syntax nodes with canonical positions inside the original string. Parser,
scope and type errors target these spans; entity spans are also attached to term
info for editor inspection. Plain strings with actual Unicode/newlines align
directly with source bytes. Escape sequences are rejected explicitly rather than
misreporting positions. The diagnostic suite checks actual JSON line/column
positions, including multibyte characters and multiline strings.

## What is checked, and what is not proved

Each theorem is checked by Lean's kernel against the **generated proposition**.
The DSL never adds an axiom, uses `sorry`, or silently solves a theorem. Ordinary
Lean can of course accept user-written `sorry` or axioms; this language is not a
policy layer for arbitrary surrounding Lean code.

The lexer/parser/resolver and their correspondence to the English specification
are **not formally verified**. A frontend bug could generate the wrong proposition
and still permit a valid proof of that wrong proposition. The explicit specification,
`#ace` inspection, and definitional-equality semantic tests address that boundary;
kernel checking alone does not establish faithful English translation.

The example dependency audit allows only `propext`, `Classical.choice`, and
`Quot.sound`, the standard Lean/mathlib foundations. It fails on `sorryAx` or a
custom axiom. This is an audit of the named delivered examples, not a claim that
all of mathlib is constructive or uses no axioms.

## Extending the subset

Add grammar in the surface parser, specify accessibility/quantifier behavior in
the scope pass, then add backend support if a new semantic construct requires it.
Each extension needs a normative translation, tests asserting the exact Lean
proposition, and rejection cases. Relative clauses should first support a bounded
restriction AST; cross-sentence/discourse and donkey semantics require an explicit
DRS-style accessibility design rather than ad hoc mutable reference tables.
