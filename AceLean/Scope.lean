module

public import AceLean.Parser

public section

/-! Lexical scope and anaphora, independent of Lean type elaboration. Local noun
phrases scope over their atomic clause. Global quantifiers scope over the entire
following formula. Sibling connectives and conditional arms do not leak binders. -/

namespace AceLean

private structure Referent where
  id : Nat
  noun : String
  label : Option String

private abbrev R := StateT Nat (Except Diagnostic)

private def introduce (ctx : List Referent) (external : List String) (span : Span)
    (noun : String) (label : Option String) : R Referent := do
  if let some label := label then
    if ctx.any (·.label == some label) || external.contains label then
      throw ⟨span, s!"Variable '{label}' is already accessible. Shadowing is rejected; choose a fresh label."⟩
  let id ← get
  set (id + 1)
  return ⟨id, noun, label⟩

private def resolveRef (ctx : List Referent) (external : List String)
    (span : Span) (name : String) : R Scoped.Entity := do
  if name == "it" then
    match ctx with
    | r :: _ => return .bound span r.id
    | [] => throw ⟨span, "'it' has no accessible antecedent. Introduce a global quantifier or use an explicit label."⟩
  if let some r := ctx.find? (·.label == some name) then return .bound span r.id
  if external.contains name then return .external span name
  throw ⟨span, s!"Unknown or inaccessible reference '{name}'. Quantified variables do not escape their clause, negation or connective branch. Use 'for every ...,' or 'there is ... such that ...' for wider scope."⟩

/-- Continuation-based quantifier lifting also handles quantified function arguments. -/
private partial def resolveNP (ctx : List Referent) (external : List String)
    (p : Surface.NP) (k : List Referent → Scoped.Entity → R Scoped.Formula) : R Scoped.Formula := do
  match p with
  | .ref span name => k ctx (← resolveRef ctx external span name)
  | .number span n => k ctx (.number span n)
  | .constant span phrase => k ctx (.constant span phrase)
  | .function span phrase arg =>
    resolveNP ctx external arg fun ctx value => k ctx (.function span phrase value)
  | .definite span noun label =>
    let r? := ctx.find? fun r => r.noun == noun && (label.isNone || r.label == label)
    match r? with
    | some r => k ctx (.bound span r.id)
    | none => throw ⟨span, s!"The noun phrase 'the {noun}' has no matching accessible antecedent. Definite descriptions never silently introduce an entity in this subset."⟩
  | .quant span q noun label =>
    let r ← introduce ctx external span noun label
    return .quant span q r.id noun label (← k (r :: ctx) (.bound span r.id))

private partial def resolveFormula (ctx : List Referent) (external : List String)
    (p : Surface.Formula) : R Scoped.Formula := do
  match p with
  | .atom span phrase args negative =>
    let rec loop (ctx : List Referent) (i : Nat) (values : Array Scoped.Entity) : R Scoped.Formula := do
      if h : i < args.size then
        resolveNP ctx external args[i] fun ctx value => loop ctx (i + 1) (values.push value)
      else
        return .atom span phrase values
    if negative then
      if h : 0 < args.size then
        resolveNP ctx external args[0] fun ctx subject => do
          return .neg span (← loop ctx 1 #[subject])
      else throw ⟨span, "Internal error: a negated atom requires a subject."⟩
    else loop ctx 0 #[]
  | .quant span q noun label body =>
    let r ← introduce ctx external span noun label
    return .quant span q r.id noun label (← resolveFormula (r :: ctx) external body)
  | .neg span body => return .neg span (← resolveFormula ctx external body)
  | .conj a b => return .conj (← resolveFormula ctx external a) (← resolveFormula ctx external b)
  | .disj a b => return .disj (← resolveFormula ctx external a) (← resolveFormula ctx external b)
  | .implies a b => return .implies (← resolveFormula ctx external a) (← resolveFormula ctx external b)
  | .iff a b => return .iff (← resolveFormula ctx external a) (← resolveFormula ctx external b)

/-- Explicit IDs make capture impossible during subsequent Lean elaboration. -/
def resolve (p : Surface.Formula) (external : List String := []) : Except Diagnostic Scoped.Formula := do
  return (← (resolveFormula [] external p).run 0).1

end AceLean
