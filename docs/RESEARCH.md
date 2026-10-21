# Research and provenance

Primary sources reviewed before selecting the architecture:

1. [ACE 6.7 construction rules](https://attempto.ifi.uzh.ch/site/docs/ace_constructionrules.html)
   define admissible noun/verb phrases, quantifiers and compound sentences.
2. [ACE 6.7 interpretation rules](https://attempto.ifi.uzh.ch/site/docs/ace_interpretationrules.html)
   specify deterministic scope and anaphora. This project adopts textual local
   quantifier ordering and distinguishes local from global quantifiers. It keeps
   `and` stronger than `or`. Its lexical accessibility is deliberately smaller
   than ACE's discourse accessibility; differences are specified in GRAMMAR.md.
3. [ACE in a nutshell](https://attempto.ifi.uzh.ch/site/docs/ace_nutshell.html)
   places vocabulary, grammar and interpretation in the wider ACE language.
4. [Verbose Lean 4](https://github.com/PatrickMassot/verbose-lean4) provides
   controlled-language tactics/commands aimed at connecting formal proofs to
   traditional written proofs. ACE Lean instead focuses on a typed statement
   frontend and keeps ordinary Lean proofs.
5. [Natural Lean](https://github.com/medovina/natural_lean) is an existing broader
   controlled mathematical language for Lean definitions, statements and proofs.
   ACE Lean explores a smaller separable parser/scope/elaboration pipeline and
   explicit vocabulary registration; it does not claim to replace that work.
6. [Lean's reference manual](https://lean-lang.org/doc/reference/latest/)
   and the installed Lean 4.35.0 sources inform the parser/elaborator,
   environment-extension and source-information APIs.
7. [Lean 4.35.0 release](https://github.com/leanprover/lean4/releases/tag/v4.35.0),
   [mathlib 4.35.0 release](https://github.com/leanprover-community/mathlib4/releases/tag/v4.35.0),
   and [mathlib's pinned toolchain](https://github.com/leanprover-community/mathlib4/blob/v4.35.0/lean-toolchain)
   establish the matching toolchain. The checked local dependency manifest records
   the exact official mathlib revision and all transitive Git revisions.

The original motivating overview is the
[Attempto Controlled English article](https://en.wikipedia.org/wiki/Attempto_Controlled_English).
The project specification relies on the official Attempto documents above rather
than treating that overview as a complete grammar.

## Independence and licenses

The implementation is original Lean code. It does not call, bundle or copy the
Attempto Parsing Engine, Verbose Lean, or Natural Lean. Those projects are cited
as language research/prior art, not asserted to endorse or interoperate with this
prototype. No ACE conformance test suite was used, and no ACE compliance claim is
made. The delivered tests specify this project's documented subset.

The project uses Apache-2.0. The LICENSE file is the standard Apache license text.
Lean and mathlib are normal upstream dependencies retaining their own licenses;
their code is not vendored into this repository. Mathematical theorem names and
ordinary Lean API idioms are referenced through those dependencies. No unrelated
repository material or personal context is included in the source or examples.
