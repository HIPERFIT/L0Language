{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ConstraintKinds #-}
module Futhark.Optimise.MemoryBlockMerging.VariableMemory where

import qualified Data.Map.Strict as M
import Control.Monad.Writer

import Futhark.Representation.AST
import Futhark.Representation.ExplicitMemory (ExplicitMemorish)
import qualified Futhark.Representation.ExplicitMemory as ExpMem
import Futhark.Representation.Kernels.Kernel

import Futhark.Optimise.MemoryBlockMerging.Miscellaneous
import Futhark.Optimise.MemoryBlockMerging.Types


newtype FindM lore a = FindM { unFindM :: Writer (VarMemMappings MemorySrc) a }
  deriving (Monad, Functor, Applicative,
            MonadWriter (VarMemMappings MemorySrc))

type LoreConstraints lore = (ExplicitMemorish lore,
                             FullWalk lore)

recordMapping :: VName -> MemorySrc -> FindM lore ()
recordMapping var memloc = tell $ M.singleton var memloc

coerce :: (ExplicitMemorish flore, ExplicitMemorish tlore) =>
          FindM flore a -> FindM tlore a
coerce = FindM . unFindM

findVarMemMappings :: LoreConstraints lore =>
                      FunDef lore -> VarMemMappings MemorySrc
findVarMemMappings fundef =
  let m = unFindM $ do
        mapM_ lookInFParam $ funDefParams fundef
        lookInBody $ funDefBody fundef
      var_to_mem = execWriter m
  in var_to_mem

lookInFParam :: LoreConstraints lore =>
                FParam lore -> FindM lore ()
lookInFParam (Param x (ExpMem.ArrayMem _ shape _ xmem xixfun)) = do
  let memloc = MemorySrc xmem xixfun shape
  recordMapping x memloc
lookInFParam _ = return ()

lookInLParam :: LoreConstraints lore =>
                LParam lore -> FindM lore ()
lookInLParam (Param x (ExpMem.ArrayMem _ shape _ xmem xixfun)) = do
  let memloc = MemorySrc xmem xixfun shape
  recordMapping x memloc
lookInLParam _ = return ()

lookInBody :: LoreConstraints lore =>
              Body lore -> FindM lore ()
lookInBody (Body _ bnds _res) =
  mapM_ lookInStm bnds

lookInKernelBody :: LoreConstraints lore =>
                    KernelBody lore -> FindM lore ()
lookInKernelBody (KernelBody _ bnds _res) =
  mapM_ lookInStm bnds

lookInStm :: LoreConstraints lore =>
             Stm lore -> FindM lore ()
lookInStm (Let (Pattern _patctxelems patvalelems) _ e) = do
  mapM_ lookInPatValElem patvalelems
  fullWalkExpM walker walker_kernel e
  where walker = identityWalker
          { walkOnBody = lookInBody
          , walkOnFParam = lookInFParam
          , walkOnLParam = lookInLParam
          }
        walker_kernel = identityKernelWalker
          { walkOnKernelBody = coerce . lookInBody
          , walkOnKernelKernelBody = coerce . lookInKernelBody
          , walkOnKernelLParam = lookInLParam
          }

lookInPatValElem :: LoreConstraints lore =>
                    PatElem lore -> FindM lore ()
lookInPatValElem (PatElem x _bindage (ExpMem.ArrayMem _ shape _ xmem xixfun)) = do
  let memloc = MemorySrc xmem xixfun shape
  recordMapping x memloc
lookInPatValElem _ = return ()
