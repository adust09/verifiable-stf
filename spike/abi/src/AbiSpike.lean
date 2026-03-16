import LeanToLambdaBox

/-
  ABI spike: test ByteArray and custom byte types through #erase.

  ByteArray is a Lean built-in opaque type, so #erase is expected to fail.
  The fallback uses custom inductive types to simulate byte serialization.
-/

-- Attempt 1: ByteArray (expected to fail)
-- Uncomment to test:
-- set_option compiler.extract_closed false in
-- def trivialBA (input : @& ByteArray) : ByteArray := input
-- open Erasure in
-- #erase trivialBA to "extraction/trivialBA.ast"

-- Fallback: custom byte types for serialization testing
set_option compiler.extract_closed false in
inductive Bit where
  | b0 : Bit
  | b1 : Bit

set_option compiler.extract_closed false in
inductive Byte where
  | mk : Bit -> Bit -> Bit -> Bit -> Bit -> Bit -> Bit -> Bit -> Byte

set_option compiler.extract_closed false in
inductive ByteList where
  | nil : ByteList
  | cons : Byte -> ByteList -> ByteList

set_option compiler.extract_closed false in
def byteIdentity (bs : ByteList) : ByteList := bs

set_option compiler.extract_closed false in
def byteLength : ByteList -> Nat
  | .nil => 0
  | .cons _ rest => 1 + byteLength rest

set_option compiler.extract_closed false in
def byteConcat (a b : ByteList) : ByteList :=
  match a with
  | .nil => b
  | .cons x rest => .cons x (byteConcat rest b)

open Erasure in
#erase byteIdentity config { nat := .peano, extern := .preferLogical } to "extraction/byteIdentity.ast"

open Erasure in
#erase byteLength config { nat := .peano, extern := .preferLogical } to "extraction/byteLength.ast"

open Erasure in
#erase byteConcat config { nat := .peano, extern := .preferLogical } to "extraction/byteConcat.ast"
