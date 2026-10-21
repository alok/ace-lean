module

public import AceLean.Scope
public import AceLean.Vocabulary
public meta import AceLean.Scope
public meta import AceLean.Vocabulary

public meta section

/-! The only backend: ordinary Lean Expr construction and type checking.
No English sentence is trusted as an axiom and no proof search is implicit. -/

namespace AceLean
open Lean Meta Elab Term

private structure LocalType where
  word : WordEntry
  value : Expr

private structure Context where
  literal : Syntax
  vocab : Array Entry
  types : Array LocalType := #[]
  locals : Array (String × Expr) := #[]
  bound : List (Nat × Expr) := []

/-- Plain string payloads align exactly with Lean's UTF-8 source offsets. -/
private def reference (ctx : Context) (span : Span) : Syntax :=
  let base := (ctx.literal.getPos?.getD 0).byteIdx + 1
  .atom (.synthetic ⟨base + span.start⟩ ⟨base + span.stop⟩ true) ""

private def errorAt (ctx : Context) (d : Diagnostic) : TermElabM α :=
  throwErrorAt (reference ctx d.span) "{d.message}"

private def lookup (ctx : Context) (phrase : String) : TermElabM Entry := do
  match ctx.vocab.find? (·.phrase == phrase) with
  | some e => return e
  | none => throwError "Internal vocabulary error: '{phrase}' is missing."

/-- Instantiate the checked alias body, preserving its actual mathematical names.
This avoids exposing generated registration aliases in goals and diagnostics. -/
private def meaning (target : Name) : TermElabM Expr := do
  let info ← getConstInfo target
  let some value := info.value?
    | throwError "Vocabulary declaration {target} has no exposed definition."
  let levels ← info.levelParams.mapM fun _ => mkFreshLevelMVar
  return value.instantiateLevelParams info.levelParams levels

/-- Instantiate implicit types/universes and defer instance synthesis to Lean.
Stop at the first explicit argument so numerals get their actual expected type. -/
private partial def leading (fn : Expr) : TermElabM (Expr × Expr) := do
  let ty ← whnf (← inferType fn)
  match ty with
  | .forallE _ domain _ info =>
    if info.isExplicit then return (fn, ty)
    let arg ← if info.isInstImplicit then mkInstMVar domain else mkFreshExprMVar domain
    leading (mkApp fn arg)
  | _ => return (fn, ty)

mutual
private partial def entity (ctx : Context) (e : Scoped.Entity)
    (expected : Option Expr := none) : TermElabM Expr := withRef (reference ctx e.span) do
  let value ← match e with
    | .bound _ id =>
      match ctx.bound.find? (·.1 == id) with
      | some (_, value) => pure value
      | none => throwError "Internal scope error: unbound referent {id}."
    | .external _ name =>
      match ctx.locals.find? (·.1 == name) with
      | some (_, value) => pure value
      | none => throwError "Local Lean variable '{name}' is no longer accessible."
    | .number _ n => elabTerm (Syntax.mkNumLit (toString n)) expected
    | .constant _ phrase =>
      let (value, _) ← leading (← meaning (← lookup ctx phrase).target)
      pure value
    | .function span phrase arg => applyVocabulary ctx span phrase #[arg]
  if let some expected := expected then
    let actual ← inferType value
    unless ← isDefEq actual expected do
      throwError "ACE type mismatch: this noun phrase has type {actual}, but the vocabulary requires {expected}. No implicit data coercions are inserted."
  discard <| addTermInfo (reference ctx e.span) value expected
  return value

private partial def applyVocabulary (ctx : Context) (span : Span) (phrase : String)
    (args : Array Scoped.Entity) : TermElabM Expr := withRef (reference ctx span) do
  let entry ← lookup ctx phrase
  let mut fn ← meaning entry.target
  for arg in args do
    let (head, ty) ← leading fn
    let .forallE _ domain _ _ := ty
      | throwError "Vocabulary '{phrase}' does not accept another argument."
    let value ← entity ctx arg (some domain)
    fn := mkApp head value
  let (result, _) ← leading fn
  let result := result.headBeta
  discard <| addTermInfo (reference ctx span) result
  return result
end

private def carrier (ctx : Context) (span : Span) (noun : String) :
    TermElabM (Expr × Option Expr) := withRef (reference ctx span) do
  if let some localType := ctx.types.find? (·.word.phrase == noun) then
    return (localType.value, none)
  let entry ← lookup ctx noun
  let (value, ty) ← leading (← meaning entry.target)
  match entry.kind with
  | .type => return (value, none)
  | .noun =>
    let .forallE _ domain _ _ := ty | throwError "Restricted noun '{noun}' has no data argument."
    return (domain, some value)
  | _ => throwError "'{noun}' is not a carrier or restricted noun."

private partial def proposition (ctx : Context) (p : Scoped.Formula) : TermElabM Expr := do
  match p with
  | .atom span phrase args =>
    let value ← applyVocabulary ctx span phrase args
    unless ← isProp value do
      throwErrorAt (reference ctx span) "Vocabulary '{phrase}' did not produce a proposition."
    return value
  | .neg span body => withRef (reference ctx span) <| mkAppM ``Not #[← proposition ctx body]
  | .conj a b => mkAppM ``And #[← proposition ctx a, ← proposition ctx b]
  | .disj a b => mkAppM ``Or #[← proposition ctx a, ← proposition ctx b]
  | .implies a b => mkArrow (← proposition ctx a) (← proposition ctx b)
  | .iff a b => mkAppM ``Iff #[← proposition ctx a, ← proposition ctx b]
  | .quant span q id noun label body => withRef (reference ctx span) do
    let (type, restriction) ← carrier ctx span noun
    withLocalDeclD (Name.mkSimple (label.getD s!"entity{id}")) type fun x => do
      let mut body ← proposition { ctx with bound := (id, x) :: ctx.bound } body
      if q == .no then body ← mkAppM ``Not #[body]
      if let some restriction := restriction then
        let guard := mkApp restriction x
        body ← if q == .some then mkAppM ``And #[guard, body] else mkArrow guard body
      if q == .some then
        mkAppM ``Exists #[← mkLambdaFVars #[x] body]
      else
        mkForallFVars #[x] body

private def elaborate (literal : TSyntax `str) (names : Array (TSyntax `str))
    (typeSyntax : Array (TSyntax `term)) : TermElabM Expr := do
  -- Escapes can change byte positions. Reject them explicitly instead of emitting
  -- misleading diagnostics. Actual newlines/Unicode are accepted in Lean strings.
  unless (literal.raw.reprint.getD "").startsWith "\"" do
    throwErrorAt literal "ACE sentences require ordinary quoted strings; raw string literals are unsupported."
  if (literal.raw.reprint.getD "").contains '\\' then
    throwErrorAt literal "ACE strings do not support escape sequences. Use literal Unicode and actual newlines so diagnostics retain exact source positions."
  let vocab ← entries
  for i in [:vocab.size] do
    for j in [:i] do
      if vocab[i]!.phrase == vocab[j]!.phrase && vocab[i]!.target != vocab[j]!.target then
        throwErrorAt literal "Conflicting imported vocabulary for '{vocab[i]!.phrase}'. Import a single lexicon or rename the phrase in one module."
  let mut types := #[]
  let mut words := vocab.map (·.toWordEntry)
  for name in names, type in typeSyntax do
    let phrase := name.getString
    let ws ← match phraseWords phrase with
      | .ok ws => pure ws
      | .error msg => throwErrorAt name msg
    if types.any (fun t : LocalType => t.word.phrase == phrase) then
      throwErrorAt name "Duplicate local carrier '{phrase}'."
    if vocab.any (fun e => e.phrase == phrase && e.kind != .type) then
      throwErrorAt name "Local carriers can override only ace_type entries, not nouns, predicates or relations."
    let value ← elabType type
    if (← whnf (← inferType value)) == .sort .zero then
      throwErrorAt type "A local carrier must be Type u, not Prop."
    let word : WordEntry := ⟨phrase, ws, .type⟩
    types := types.push ⟨word, value⟩
    words := (words.filter (·.phrase != phrase)).push word
  let mut locals := #[]
  for d in ← getLCtx do
    unless d.isImplementationDetail || (← isProof d.toExpr) do
      let name := d.userName.toString.toLower
      if locals.any (·.1 == name) then
        throwErrorAt literal "Ambiguous local Lean name '{name}' after case folding. Rename a local variable."
      locals := locals.push (name, d.toExpr)
  let ctx : Context := ⟨literal, vocab, types, locals, []⟩
  let parsed ← match parse words literal.getString with
    | .ok p => pure p
    | .error d => errorAt ctx d
  let resolved ← match resolve parsed (locals.toList.map (·.1)) with
    | .ok p => pure p
    | .error d => errorAt ctx d
  let value ← proposition ctx resolved
  synthesizeSyntheticMVarsNoPostponing
  let value ← instantiateMVars value
  if value.hasExprMVar then
    throwErrorAt literal "ACE elaboration left an unresolved type. Specialize the vocabulary entry or supply a local carrier with ('element' := α)."
  check value
  return value

/-- Elaborate one ACE-inspired sentence to a Lean proposition. Optional local
carriers connect generic English nouns to types in the surrounding Lean context. -/
syntax (name := aceTerm) "ace% " str (" with " "(" str " := " term ")")* : term

elab_rules : term
  | `(ace% $text:str $[with ($names:str := $types:term)]*) => elaborate text names types

/-- Display Lean's actual proposition; no theorem or assumption is introduced. -/
syntax (name := aceCheck) "#ace " str (" with " "(" str " := " term ")")* : command

elab_rules : command
  | `(#ace $text:str $[with ($names:str := $types:term)]*) =>
    Command.liftTermElabM do
      logInfo (← elaborate text names types)

end AceLean
