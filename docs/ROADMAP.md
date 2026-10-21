# Roadmap

The first release is a usable statement-language experiment with a deliberately
small semantics. Extend it by preserving explicit translation rules and good
diagnostics, not by accepting English that the semantics cannot faithfully handle.

## Next coherent increment

1. Add restricted relative clauses, with a restriction AST and tests distinguishing
   the restricted noun from a main-clause conjunction. Specify how quantified
   relative-clause objects interact with the noun's scope before implementing them.
2. Add typed binary/n-ary function vocabulary with explicit surface argument
   grouping. Include dependent/heterogeneous-domain tests and wrong-arity errors.
3. Add an explicit lexicon namespace/import selection mechanism so applications
   can combine independently authored domain vocabularies without global collision.
4. Add a source literal parser that retains a decoded-to-source offset map, allowing
   Lean string escapes without weakening diagnostic precision.
5. Add completion/hover polish using registered phrase metadata and resolved ASTs.

## Larger research questions

- DRS-style discourse accessibility, including implication antecedents and
  cross-sentence existential references. This changes semantics substantially and
  should be a versioned extension with differential tests against official ACE
  readings, not a mutable-name-table shortcut.
- A compositional denotation of the resolved AST and proofs of binder/scope
  invariants. This would strengthen the presently tested translation boundary.
- Optional English proof steps layered over normal Lean tactics, without making
  proof search or a failed proof silently introduce assumptions.
- A corpus of realistic mathematical statements and user studies comparing
  clarity, translation inspection and diagnostics with existing Lean languages.

No milestone promises full ACE compatibility. Before making a compatibility claim,
define an explicit grammar profile and validate it against a suitable independent
ACE corpus and semantic reference implementation, including licensing review of
any external tooling actually incorporated.
