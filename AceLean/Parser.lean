module

public import AceLean.Syntax

public section

/-! A deterministic lexer/parser for the documented ACE-Lean subset. Vocabulary
matching uses complete tokens and longest phrases, never substring replacement. -/

namespace AceLean

structure Token where
  text : String
  span : Span
  deriving Repr, Inhabited

private def isWord (c : Char) : Bool :=
  (Lean.isIdRest c && c != '?' && c != '!' && c != '\'') || c == '-'

/-- Lex words, natural numerals, grouping and sentence punctuation. -/
def tokenize (input : String) : Except Diagnostic (Array Token) := Id.run do
  let mut tokens := #[]
  let mut word := ""
  let mut start := 0
  let mut pos := 0
  for c in input.toList do
    if isWord c then
      if word.isEmpty then start := pos
      word := word.push c.toLower
    else
      if !word.isEmpty then
        tokens := tokens.push ⟨word, ⟨start, pos⟩⟩
        word := ""
      if !c.isWhitespace then
        if ['(', ')', ',', '.'].contains c then
          tokens := tokens.push ⟨String.singleton c, ⟨pos, pos + c.utf8Size⟩⟩
        else
          return .error ⟨⟨pos, pos + c.utf8Size⟩,
            s!"Unsupported character '{c}'. Use registered words, numerals and parentheses; embedded Lean terms and arithmetic notation are not part of this grammar."⟩
    pos := pos + c.utf8Size
  if !word.isEmpty then tokens := tokens.push ⟨word, ⟨start, pos⟩⟩
  return .ok (tokens.push ⟨"<end>", ⟨pos, pos⟩⟩)

private structure ParseState where
  tokens : Array Token
  vocab : Array WordEntry
  index : Nat := 0
  deriving Inhabited

private abbrev P := StateT ParseState (Except Diagnostic)

private def peek : P Token := do
  let s ← get
  return s.tokens[s.index]!

private def fail (message : String) : P α := do
  throw ⟨(← peek).span, message⟩

private def take : P Token := do
  let t ← peek
  modify fun s => { s with index := s.index + 1 }
  return t

private def eat (word : String) : P Bool := do
  if (← peek).text == word then
    discard take
    return true
  return false

private def expect (word : String) : P Unit := do
  unless ← eat word do
    fail s!"Expected '{word}', found '{(← peek).text}'."

private def matchesWords (words : Array String) : P Bool := do
  let s ← get
  return words.toList.zipIdx.all fun (w, i) => (s.tokens[s.index + i]?).any (·.text == w)

private def phrase? (kinds : List Kind) : P (Option (WordEntry × Span)) := do
  let s ← get
  let mut best : Option WordEntry := none
  for e in s.vocab do
    if kinds.contains e.kind && (← matchesWords e.words) then
      if best.isNone || e.words.size > best.get!.words.size then best := some e
  match best with
  | none => return none
  | some e =>
    let span := ⟨(← peek).span.start, s.tokens[s.index + e.words.size - 1]!.span.stop⟩
    modify fun s => { s with index := s.index + e.words.size }
    return some (e, span)

private def quantifier? : P (Option Quantifier) := do
  if (← eat "every") || (← eat "each") then return some .every
  if (← eat "a") || (← eat "an") || (← eat "some") then return some .some
  if ← eat "no" then return some .no
  return none

private def noun : P (WordEntry × Span) := do
  match ← phrase? [.type, .noun] with
  | some e => return e
  | none => fail s!"Unknown noun at '{(← peek).text}'. Register a carrier with ace_type or a restricted noun with ace_noun."

private def reserved : List String :=
  ["is", "does", "not", "and", "or", "then", "if", "iff", "such", "that", "of",
   "for", "there", "every", "each", "some", "a", "an", "no", "the", "it",
   "(", ")", ",", ".", "<end>"]

private def label? : P (Option String) := do
  let t ← peek
  if reserved.contains t.text || t.text.toNat?.isSome then return none
  let s ← get
  if s.vocab.any (fun e => e.words[0]? == some t.text) then return none
  discard take
  return some t.text

private partial def np : P Surface.NP := do
  let t ← peek
  if let some q ← quantifier? then
    let (e, _) ← noun
    return .quant t.span q e.phrase (← label?)
  let definite ← eat "the"
  if let some (e, span) ← phrase? [.function] then
    expect "of"
    return .function span e.phrase (← np)
  if let some (e, span) ← phrase? [.constant] then return .constant span e.phrase
  if definite then
    let (e, span) ← noun
    return .definite span e.phrase (← label?)
  if let some n := t.text.toNat? then
    discard take
    return .number t.span n
  if ← eat "it" then return .ref t.span "it"
  if reserved.contains t.text then
    fail s!"Expected a noun phrase, numeral, registered constant or accessible variable; found '{t.text}'."
  discard take
  return .ref t.span t.text

private partial def atom : P Surface.Formula := do
  let subject ← np
  if let some (e, span) ← phrase? [.relation] then
    return .atom span e.phrase #[subject, ← np] false
  if ← eat "is" then
    let negative ← eat "not"
    discard (eat "a")
    discard (eat "an")
    let some (e, span) ← phrase? [.adjective, .noun]
      | fail s!"Unknown property at '{(← peek).text}'. Use an ace_adjective/ace_noun entry, or register the full verb phrase with ace_relation."
    return .atom span e.phrase #[subject] negative
  if ← eat "does" then
    expect "not"
    let some (e, span) ← phrase? [.relation]
      | fail "After 'does not', use an exactly registered relation phrase (no automatic inflection)."
    -- Predicate negation leaves the subject binder outside, the object inside.
    return .atom span e.phrase #[subject, ← np] true
  fail s!"Expected 'is' or a registered relation after the subject; found '{(← peek).text}'. Relative clauses, passives, plurals and omitted subjects are unsupported."

mutual
private partial def formula : P Surface.Formula := do
  if ← eat "for" then
    let t ← peek
    let some q ← quantifier? | fail "Use 'for every <noun> [label], <sentence>'."
    unless q == .every do fail "Only 'for every'/'for each' introduce a global universal."
    let (e, _) ← noun
    let label ← label?
    expect ","
    return .quant t.span q e.phrase label (← formula)
  if ← eat "there" then
    expect "is"
    let t ← peek
    let some q ← quantifier? | fail "Use 'there is a/some/no <noun> [label] such that <sentence>'."
    if q == .every then fail "Use 'for every' for a global universal."
    let (e, _) ← noun
    let label ← label?
    expect "such"
    expect "that"
    return .quant t.span q e.phrase label (← formula)
  if ← eat "if" then
    let lhs ← disjunction
    expect "then"
    return .implies lhs (← formula)
  let lhs ← disjunction
  if ← eat "iff" then return .iff lhs (← formula)
  return lhs

private partial def disjunction : P Surface.Formula := do
  let mut lhs ← conjunction
  while ← eat "or" do lhs := .disj lhs (← conjunction)
  return lhs

private partial def conjunction : P Surface.Formula := do
  let mut lhs ← primary
  while ← eat "and" do lhs := .conj lhs (← primary)
  return lhs

private partial def primary : P Surface.Formula := do
  if ← eat "(" then
    let p ← formula
    expect ")"
    return p
  let t ← peek
  if ← eat "not" then
    expect "("
    let p ← formula
    expect ")"
    return .neg t.span p
  if ← matchesWords #["it", "is", "false", "that"] then
    for _ in [:4] do discard take
    expect "("
    let p ← formula
    expect ")"
    return .neg t.span p
  return ← atom
end

/-- Parse one sentence; a terminal full stop is optional. No text is discarded. -/
def parse (vocab : Array WordEntry) (input : String) : Except Diagnostic Surface.Formula := do
  let tokens ← tokenize input
  let action : P Surface.Formula := do
    let result ← formula
    discard (eat ".")
    unless (← peek).text == "<end>" do
      fail s!"Unexpected '{(← peek).text}'. Only one sentence is accepted. Use parentheses for nested scope; relative clauses, discourse continuation and comma-coordination are unsupported."
    return result
  return (← action.run ⟨tokens, vocab, 0⟩).1

end AceLean
