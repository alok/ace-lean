module

public import AceLean.Syntax
public meta import AceLean.Syntax

public meta section

/-! Persistent, typed vocabulary. Registration creates a checked Lean definition,
then validates its telescope. Imported entries survive through an environment
extension; duplicate phrases (including conflicting imports) are rejected. -/

namespace AceLean
open Lean Meta Elab Command

structure Entry extends WordEntry where
  target : Name
  deriving Inhabited

initialize vocabulary : SimplePersistentEnvExtension Entry (Array Entry) ←
  registerSimplePersistentEnvExtension {
    name := `AceLean.vocabulary
    addEntryFn := Array.push
    addImportedFn := fun imports => imports.foldl (· ++ ·) #[]
  }

def entries [Monad m] [MonadEnv m] : m (Array Entry) := return vocabulary.getState (← getEnv)

def wordEntries [Monad m] [MonadEnv m] : m (Array WordEntry) := return (← entries).map (·.toWordEntry)

/-- This is deliberately a closed phrase language, independent of Lean identifiers. -/
def phraseWords (phrase : String) : Except String (Array String) := do
  let words := phrase.splitOn " " |>.toArray
  if words.isEmpty || words.any String.isEmpty then
    throw "Vocabulary phrases need single spaces between nonempty words."
  for word in words do
    if !word.toList.all (fun c => c.isAlpha || c == '-') || word != word.toLower then
      throw "Vocabulary phrases must use lowercase letters and hyphens; numerals and variable labels are not vocabulary words."
  if ["every", "each", "some", "a", "an", "no", "the", "for", "there", "if",
      "then", "and", "or", "iff", "not", "it"].contains words[0]! then
    throw s!"'{words[0]!}' is a reserved grammar word and cannot start a vocabulary phrase."
  return words

private def validate (kind : Kind) (target : Name) : TermElabM Unit := do
  let value ← mkConstWithFreshMVarLevels target
  let ty ← inferType value
  if kind == .constant then
    if (← isType value) || (← isProof value) then
      throwError "ace_constant expects data, not a type or proof; got {ty}."
    return
  -- Do not unfold function-like data carriers such as Set α into extra binders.
  forallTelescope ty fun args result => do
    let explicit ← args.filterM fun x => return (← getFVarLocalDecl x).binderInfo.isExplicit
    let count := explicit.size
    match kind with
    | .type =>
      unless count == 0 && result.isSort do
        throwError "ace_type expects a type with no explicit parameters; got {ty}. Supply parameters, e.g. (List Nat)."
      if result == .sort .zero then
        throwError "ace_type requires a data carrier (Type u), not Prop."
    | .noun | .adjective | .relation =>
      let required := if kind == .relation then 2 else 1
      unless count == required && result == .sort .zero do
        throwError "This vocabulary category expects {required} explicit data argument(s) and result Prop; got {ty}. Implicit type and instance parameters are allowed."
      for arg in explicit do
        if ← isProof arg then
          throwError "Vocabulary arguments must be data, not proof arguments; got {ty}."
    | .function =>
      unless count == 1 do
        throwError "ace_function expects exactly one explicit data argument; got {ty}."
      if result.isSort || (← isProp result) then
        throwError "ace_function expects a data-valued unary function, not a type or proposition; got {ty}."
    | .constant =>
      pure ()

private def register (kind : Kind) (phrase : TSyntax `str) (rhs : TSyntax `term) : CommandElabM Unit := do
  let phraseText := phrase.getString
  let words ← match phraseWords phraseText with
    | .ok words => pure words
    | .error msg => throwErrorAt phrase msg
  if (← entries).any (·.phrase == phraseText) then
    throwErrorAt phrase "Vocabulary phrase '{phraseText}' is already registered. Use a distinct phrase; overloading is deliberately rejected."
  -- Keep the alias in the current namespace and out of the user's short-name space.
  let short ← liftCoreM <| mkFreshUserName (`ace_vocab ++ Name.mkSimple (phraseText.replace " " "_"))
  let id := mkIdentFrom phrase short
  let saved ← get
  try
    elabCommand (← `(@[expose] abbrev $id := $rhs))
    -- Resolve the real declaration name: modules may make the alias private,
    -- and macro hygiene/private-name mangling is not predictable by concatenation.
    let target ← liftCoreM <| realizeGlobalConstNoOverloadWithInfo id
    liftTermElabM <| withRef rhs <| validate kind target
    modifyEnv fun env => vocabulary.addEntry env ⟨⟨phraseText, words, kind⟩, target⟩
  catch ex =>
    set saved
    throw ex

/-- Register a Lean carrier such as Nat, ℝ, Set Nat, or ULift.{1} Nat. -/
syntax (name := aceType) "ace_type " str " := " term : command
/-- Register a restricted noun from a unary predicate; its domain is inferred. -/
syntax (name := aceNoun) "ace_noun " str " := " term : command
/-- Register a unary property used after 'is' / 'is not'. -/
syntax (name := aceAdjective) "ace_adjective " str " := " term : command
/-- Register a complete binary verb phrase, including any preposition/copula. -/
syntax (name := aceRelation) "ace_relation " str " := " term : command
/-- Register a unary data function used as '<phrase> of <noun phrase>'. -/
syntax (name := aceFunction) "ace_function " str " := " term : command
/-- Register a data-valued proper name. -/
syntax (name := aceConstant) "ace_constant " str " := " term : command

elab_rules : command
  | `(ace_type $p:str := $rhs:term) => register .type p rhs
  | `(ace_noun $p:str := $rhs:term) => register .noun p rhs
  | `(ace_adjective $p:str := $rhs:term) => register .adjective p rhs
  | `(ace_relation $p:str := $rhs:term) => register .relation p rhs
  | `(ace_function $p:str := $rhs:term) => register .function p rhs
  | `(ace_constant $p:str := $rhs:term) => register .constant p rhs

/-- Inspect the exact checked declarations and types behind the current lexicon. -/
elab "#ace_vocab" : command => do
  for e in ← entries do
    let ty := (← getConstInfo e.target).type
    logInfo m!"{e.phrase} [{repr e.kind}] ↦ {e.target} : {ty}"

end AceLean
