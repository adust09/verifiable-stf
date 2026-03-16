import LeanToLambdaBox

set_option compiler.extract_closed false in
inductive Nat_ where
  | zero : Nat_
  | suc : Nat_ -> Nat_

set_option compiler.extract_closed false in
def identity (n : Nat_) : Nat_ := n

set_option compiler.extract_closed false in
def add (a b : Nat_) : Nat_ :=
  match a with
  | .zero => b
  | .suc n => .suc (add n b)

open Erasure in
#erase identity config { nat := .peano, extern := .preferLogical } to "extraction/identity.ast"

open Erasure in
#erase add config { nat := .peano, extern := .preferLogical } to "extraction/add.ast"
