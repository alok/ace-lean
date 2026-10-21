# Publication plan and announcement draft

## Release sequence

1. Pass the full Lake build, semantic tests, diagnostic integration suite, and
   named-example axiom audit on the pinned dependencies.
2. Inspect the Git-tracked file list and staged diff for credentials, private
   context, generated caches, unrelated code and licensing/provenance problems.
3. Create/push the new public GitHub repository and record the exact commit and
   URL in the handoff. A local commit alone is not a published repository.
4. Have the task owner verify the intended SF Lean Discord server/channel, then
   share the factual announcement there. No Discord post is made by this project.
5. Consider a Lean Zulip announcement only after useful feedback/social proof
   from that audience and verification of the appropriate channel. Do not imply
   that early feedback or a Zulip post already exists.

The following is a draft, not evidence of a sent message. Replace the repository
link with the confirmed URL and check that all stated checks passed at that commit.

## Draft announcement

I made ACE Lean, a small Attempto Controlled English inspired statement DSL for
Lean 4.35.0 with mathlib integration: https://github.com/alok/ace-lean.

It parses English into a surface AST, resolves lexical scope/anaphora in a separate
pass, and elaborates against a typed vocabulary of actual Lean/mathlib definitions.
For example, “For every natural number n, there is a prime number p such that n is
at most p” becomes `∀ n, ∃ p, Nat.Prime p ∧ n ≤ p`, proved using
`Nat.exists_infinite_primes`.

This is a documented subset, not full ACE. It has local/global quantifiers,
restricted nouns, connectives/negation, typed relations/functions, generic local
carriers and source-positioned errors. Ordinary Lean proofs remain kernel checked.
The repository includes tests of the exact generated propositions, rejection and
diagnostic-position tests, and an example axiom audit. The English translation
itself is tested, not formally proved correct.

I would especially welcome feedback on quantifier scope, vocabulary design and
which bounded language extension would make it useful for real mathematics.
