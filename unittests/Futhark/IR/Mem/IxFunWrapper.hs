-- | Perform index function operations in both algebraic and LMAD
-- representations.
module Futhark.IR.Mem.IxFunWrapper
  ( IxFun
  , iota
  , permute
  , rotate
  , reshape
  , slice
  , rebase
  )
where

import Futhark.Util.IntegralExp
import Futhark.IR.Syntax (ShapeChange, Slice)
import qualified Futhark.IR.Mem.IxFun as I
import qualified Futhark.IR.Mem.IxFun.Alg as IA


type Shape num = [num]
type Indices num = [num]
type Permutation = [Int]

type IxFun num = (I.IxFun num, IA.IxFun num)

iota :: IntegralExp num =>
        Shape num -> IxFun num
iota x = (I.iota x, IA.iota x)

permute :: IntegralExp num =>
           IxFun num -> Permutation -> IxFun num
permute (l, a) x = (I.permute l x, IA.permute a x)

rotate :: (Eq num, IntegralExp num) =>
          IxFun num -> Indices num -> IxFun num
rotate (l, a) x = (I.rotate l x, IA.rotate a x)

reshape :: (Eq num, IntegralExp num) =>
           IxFun num -> ShapeChange num -> IxFun num
reshape (l, a) x = (I.reshape l x, IA.reshape a x)

slice :: (Eq num, IntegralExp num) =>
         IxFun num -> Slice num -> IxFun num
slice (l, a) x = (I.slice l x, IA.slice a x)

rebase :: (Eq num, IntegralExp num) =>
          IxFun num -> IxFun num -> IxFun num
rebase (l, a) (l1, a1) = (I.rebase l l1, IA.rebase a a1)