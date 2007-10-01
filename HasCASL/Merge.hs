{- |
Module      :  $Header$
Description :  union of signature parts
Copyright   :  (c) Christian Maeder and Uni Bremen 2003-2005
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  experimental
Portability :  portable

merging parts of local environment
-}

module HasCASL.Merge
    ( merge
    , mergeMap
    , improveDiag
    , mergeClassInfo
    , mergeTypeDefn
    , mergeOpInfo
    , addUnit
    ) where

import Common.Id
import Common.DocUtils
import Common.Result

import HasCASL.As
import HasCASL.Le
import HasCASL.AsUtils
import HasCASL.PrintLe ()
import HasCASL.ClassAna
import HasCASL.TypeAna
import HasCASL.Unify
import HasCASL.Builtin
import HasCASL.MapTerm
import qualified Data.Map as Map
import qualified Data.Set as Set

import Control.Monad(foldM)
import Data.List

improveDiag :: (PosItem a, Pretty a) => a -> Diagnosis -> Diagnosis
improveDiag v d = d
  { diagString = let f:l = lines $ diagString d in
      unlines $ (f ++ " of '" ++ showDoc v "'") : l
  , diagPos = getRange v }

mergeMap :: (Ord a, PosItem a, Pretty a) => (b -> b -> Result b)
         -> Map.Map a b -> Map.Map a b -> Result (Map.Map a b)
mergeMap f m1 m2 = foldM ( \ m (k, v) -> case Map.lookup k m of
    Nothing -> return $ Map.insert k v m
    Just w -> let
      Result ds r = do
        u <- f w v
        return $ Map.insert k u m
      in Result (map (improveDiag k) ds) r) m1 $ Map.toList m2

mergeClassInfo :: ClassInfo -> ClassInfo -> Result ClassInfo
mergeClassInfo c1 c2 = do
    k <-  minRawKind "class raw kind" (rawKind c1) $ rawKind c2
    return $ ClassInfo k $ Set.union (classKinds c1) $ classKinds c2

mergeTypeInfo :: ClassMap -> TypeInfo -> TypeInfo -> Result TypeInfo
mergeTypeInfo cm t1 t2 = do
    let o = keepMinKinds cm [otherTypeKinds t1, otherTypeKinds t2]
        s = Set.union (superTypes t1) $ superTypes t2
    k <- minRawKind "type raw kind" (typeKind t1) $ typeKind t2
    d <- mergeTypeDefn (typeDefn t1) $ typeDefn t2
    return $ TypeInfo k o s d

mergeTypeDefn :: TypeDefn -> TypeDefn -> Result TypeDefn
mergeTypeDefn d1 d2 = case (d1, d2) of
    (_, DatatypeDefn _) -> return d2
    (PreDatatype, _) -> fail "expected data type definition"
    (_, PreDatatype) -> return d1
    (NoTypeDefn, _) -> return d2
    (_, NoTypeDefn) -> return d1
    (AliasTypeDefn s1, AliasTypeDefn s2) -> do
        s <- mergeAlias s1 s2
        return $ AliasTypeDefn s
    (_, _) -> mergeA "TypeDefn" d1 d2

mergeAlias :: Type -> Type -> Result Type
mergeAlias s1 s2 = if eqStrippedType s1 s2 then return s1 else
    fail $ "wrong type" ++ expected s1 s2

mergeOpBrand :: OpBrand -> OpBrand -> OpBrand
mergeOpBrand b1 b2 = case (b1, b2) of
    (Pred, _) -> Pred
    (_, Pred) -> Pred
    (Op, _) -> Op
    (_, Op) -> Op
    _ -> Fun

mergeOpDefn :: OpDefn -> OpDefn -> Result OpDefn
mergeOpDefn d1 d2 = case (d1, d2) of
    (NoOpDefn b1, NoOpDefn b2) -> do
        let b = mergeOpBrand b1 b2
        return $ NoOpDefn b
    (SelectData c1 s, SelectData c2 _) -> do
        let c = Set.union c1 c2
        return $ SelectData c s
    (Definition b1 e1, Definition b2 e2) -> do
        d <- mergeTerm Hint e1 e2
        let b = mergeOpBrand b1 b2
        return $ Definition b d
    (NoOpDefn b1, Definition b2 e2) -> do
        let b = mergeOpBrand b1 b2
        return $ Definition b e2
    (Definition b1 e1, NoOpDefn b2) -> do
        let b = mergeOpBrand b1 b2
        return $ Definition b e1
    (ConstructData _, SelectData _ _) ->
        fail "illegal selector as constructor redefinition"
    (SelectData _ _, ConstructData _) ->
        fail "illegal constructor as selector redefinition"
    (ConstructData _, _) -> return d1
    (_, ConstructData _) -> return d2
    (SelectData _ _, _) -> return d1
    (_, SelectData _ _) -> return d2

addUnit :: ClassMap -> TypeMap -> TypeMap
addUnit cm = maybe (error "addUnit") id . maybeResult . mergeTypeMap cm bTypes

mergeOpInfos :: ClassMap -> TypeMap -> Set.Set OpInfo -> Set.Set OpInfo
             -> Result (Set.Set OpInfo)
mergeOpInfos cm tm s1 s2 = do
  nt <- mergeTypeMap cm bTypes tm
  mergeOps cm nt s1 s2

mergeOps :: ClassMap -> TypeMap -> Set.Set OpInfo -> Set.Set OpInfo
         -> Result (Set.Set OpInfo)
mergeOps cm tm s1 s2 = if Set.null s1 then return s2 else do
    let (o, os) = Set.deleteFindMin s1
        (es, us) = Set.partition (isUnifiable tm 1 (opType o) . opType) s2
    s <- mergeOps cm tm os us
    r <- foldM (mergeOpInfo cm tm) o $ Set.toList es
    return $ Set.insert r s

mergeOpInfo :: ClassMap -> TypeMap -> OpInfo -> OpInfo -> Result OpInfo
mergeOpInfo cm tm o1 o2 = do
    let s1@(TypeScheme args1 ty1 _) = opType o1
        s2@(TypeScheme args2 ty2 _) = opType o2
    sc <-
      if eqStrippedType ty1 ty2 then
          if specializedScheme cm args2 args1 then return s1
          else if specializedScheme cm args1 args2 then return s2
          else fail "equal type schemes with uncomparable constraints"
      else if instScheme tm 1 s2 s1 then return s1
      else if instScheme tm 1 s1 s2 then return s2
      else fail "overlapping but incompatible type schemes"
    let as = Set.union (opAttrs o1) $ opAttrs o2
    d <- mergeOpDefn (opDefn o1) $ opDefn o2
    return $ OpInfo sc as d

mergeTypeMap :: ClassMap -> TypeMap -> TypeMap -> Result TypeMap
mergeTypeMap cm = mergeMap $ mergeTypeInfo cm

merge :: Env -> Env -> Result Env
merge e1 e2 = do
    cMap <- mergeMap mergeClassInfo (classMap e1) $ classMap e2
    let clMap = Map.map (\ ci -> ci { classKinds =
                          keepMinKinds cMap [classKinds ci] }) cMap
    tMap <- mergeTypeMap clMap (typeMap e1) $ typeMap e2
    let tAs = filterAliases tMap
    as <- mergeMap (mergeOpInfos clMap tMap) (assumps e1) $ assumps e2
    return initialEnv
      { classMap = clMap
      , typeMap = tMap
      , assumps = Map.map (Set.map $ mapOpInfo (id, expandAliases tAs)) $ as }

mergeA :: (Pretty a, Eq a) => String -> a -> a -> Result a
mergeA str t1 t2 = if t1 == t2 then return t1 else
    fail ("different " ++ str ++ expected t1 t2)

mergeTerm :: DiagKind -> Term -> Term -> Result Term
mergeTerm k t1 t2 = if t1 == t2 then return t1 else
  Result [Diag k ("different terms" ++ expected t1 t2) $ getRange t2] $ Just t2
