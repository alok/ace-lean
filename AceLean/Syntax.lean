module

public import Lean

public section

/-! Source-preserving surface syntax and a scope-resolved intermediate language.
The parser and resolver below are pure: neither can manufacture a Lean proof. -/

namespace AceLean

/-- UTF-8 byte offsets in the decoded, unescaped source string. -/
structure Span where
  start : Nat
  stop : Nat
  deriving Repr, Inhabited, BEq

structure Diagnostic where
  span : Span
  message : String
  deriving Repr, Inhabited

inductive Kind where
  | type | noun | adjective | relation | function | constant
  deriving Repr, Inhabited, BEq

structure WordEntry where
  phrase : String
  words : Array String
  kind : Kind
  deriving Repr, Inhabited

inductive Quantifier where
  | every | some | no
  deriving Repr, Inhabited, BEq

namespace Surface

/-- Quantified noun phrases are lifted, in textual order, by the scope resolver. -/
inductive NP where
  | ref (span : Span) (name : String)
  | definite (span : Span) (noun : String) (label : Option String)
  | number (span : Span) (value : Nat)
  | constant (span : Span) (phrase : String)
  | function (span : Span) (phrase : String) (arg : NP)
  | quant (span : Span) (q : Quantifier) (noun : String) (label : Option String)
  deriving Repr, Inhabited

def NP.span : NP → Span
  | .ref s _ | .definite s _ _ | .number s _ | .constant s _
  | .function s _ _ | .quant s _ _ _ => s

inductive Formula where
  | atom (span : Span) (phrase : String) (args : Array NP) (negated : Bool)
  | quant (span : Span) (q : Quantifier) (noun : String) (label : Option String)
      (body : Formula)
  | neg (span : Span) (body : Formula)
  | conj (left right : Formula)
  | disj (left right : Formula)
  | implies (left right : Formula)
  | iff (left right : Formula)
  deriving Repr, Inhabited

end Surface

namespace Scoped

inductive Entity where
  | bound (span : Span) (id : Nat)
  | external (span : Span) (name : String)
  | number (span : Span) (value : Nat)
  | constant (span : Span) (phrase : String)
  | function (span : Span) (phrase : String) (arg : Entity)
  deriving Repr, Inhabited

def Entity.span : Entity → Span
  | .bound s _ | .external s _ | .number s _ | .constant s _ | .function s _ _ => s

inductive Formula where
  | atom (span : Span) (phrase : String) (args : Array Entity)
  | quant (span : Span) (q : Quantifier) (id : Nat) (noun : String)
      (label : Option String) (body : Formula)
  | neg (span : Span) (body : Formula)
  | conj (left right : Formula)
  | disj (left right : Formula)
  | implies (left right : Formula)
  | iff (left right : Formula)
  deriving Repr, Inhabited

end Scoped
end AceLean
