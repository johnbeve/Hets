{- |
Module      :  $Header$
Description :  consistency checking of free types
Copyright   :  (c) Mingyi Liu and Till Mossakowski and Uni Bremen 2004-2005
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  mgross@informatik.uni-bremen.de
Stability   :  provisional
Portability :  non-portable (imports Logic.Logic)

Consistency checking of free types
-}

module CASL.CCC.FreeTypes (checkFreeType) where

import CASL.AS_Basic_CASL       -- FORMULA, OP_{NAME,SYMB}, TERM, SORT, VAR
import CASL.Morphism
import CASL.Sign
import CASL.SimplifySen
import CASL.CCC.TermFormula
import CASL.CCC.TerminationProof (terminationProof)
import CASL.Overload (leqF)

import Common.AS_Annotation
import Common.Consistency (Conservativity (..))
import Common.DocUtils (showDoc)
import Common.Id
import Common.Result
import Common.Utils (nubOrd)
import qualified Common.Lib.MapSet as MapSet
import qualified Common.Lib.Rel as Rel

import Data.Function
import Data.List
import Data.Maybe

import qualified Data.Set as Set

-- | check values of constructors (free types have only total ones)
inhabited :: Set.Set SORT -> [OP_SYMB] -> Set.Set SORT
inhabited sorts cons = iterateInhabited sorts where
  argsRes = foldr (\ os -> case os of
    Qual_op_name _ (Op_type Total args res _) _ -> ((args, res) :)
    _ -> id) [] cons
  iterateInhabited l =
    if changed then iterateInhabited newL else newL where
      (newL, changed) = foldr (\ (ags, rs) p@(l', _) ->
        if all (`Set.member` l') ags && not (Set.member rs l')
        then (Set.insert rs l', True) else p) (l, False) argsRes

-- | just filter out the axioms generated for free types
isUserOrSortGen :: Named (FORMULA f) -> Bool
isUserOrSortGen ax = case stripPrefix "ga_" $ senAttr ax of
  Nothing -> True
  Just rname -> all (not . (`isPrefixOf` rname))
    ["disjoint_", "injective_", "selector_"]

getFs :: [Named (FORMULA f)] -> [FORMULA f]
getFs = map sentence . filter isUserOrSortGen

getExAxioms :: [Named (FORMULA ())] -> [FORMULA ()]
getExAxioms = filter isExQuanti . getFs

getAxioms :: [Named (FORMULA ())] -> [FORMULA ()]
getAxioms =
  filter (\ f -> not $ isSortGen f || isMembership f || isExQuanti f) . getFs

getInfoSubsort :: Morphism () () ()
    -> [Named (FORMULA ())] -> [FORMULA ()]
getInfoSubsort m = concatMap (infoSubsort esorts) . filter isMembership . getFs
  where esorts = Set.toList . emptySortSet $ mtarget m

getAxGroup :: [Named (FORMULA ())] -> [[FORMULA ()]]
getAxGroup = groupAxioms . filter (not . isDomain) . map quanti . getAxioms

-- | get the constraints from sort generation axioms
constraintOfAxiom :: [FORMULA f] -> [[Constraint]]
constraintOfAxiom = foldr (\ f -> case f of
  Sort_gen_ax constrs _ -> (constrs :)
  _ -> id) []

recoverSortsAndConstructors :: [Named (FORMULA f)] -> [Named (FORMULA f)]
  -> (Set.Set SORT, [OP_SYMB])
recoverSortsAndConstructors osens fsn = let
  (srts, cons, _) = unzip3 . map recover_Sort_gen_ax
    . constraintOfAxiom . getFs $ osens ++ fsn
  in (Set.unions $ map Set.fromList srts, nubOrd $ concat cons)

getOverloadedConstructors :: [Named (FORMULA ())] -> Morphism () () ()
    -> [Named (FORMULA ())] -> [OP_SYMB]
getOverloadedConstructors osens m fsn = let tsig = mtarget m in
    constructorOverload tsig (opMap tsig)
          . snd $ recoverSortsAndConstructors osens fsn

-- check that patterns do not overlap, if not, return proof obligation.
getOverlapQuery :: [Named (FORMULA ())] -> [FORMULA ()]
getOverlapQuery fsn = overlap_query where
        axPairs = concatMap pairs $ getAxGroup fsn
        olPairs = filter (\ (a, b) -> checkPatterns
                           (patternsOfAxiom a, patternsOfAxiom b)) axPairs
        subst (f1, f2) = ((f1, reverse sb1), (f2, reverse sb2))
          where (sb1, sb2) = st ((patternsOfAxiom f1, []),
                                 (patternsOfAxiom f2, []))
                st ((pa1, s1), (pa2, s2)) = case (pa1, pa2) of
                  (hd1 : tl1, hd2 : tl2)
                    | hd1 == hd2 -> st ((tl1, s1), (tl2, s2))
                    | isVar hd1 -> st ((tl1, (hd2, hd1) : s1), (tl2, s2))
                    | isVar hd2 -> st ((tl1, s1), (tl2, (hd1, hd2) : s2))
                    | otherwise -> st ((patternsOfTerm hd1 ++ tl1, s1),
                                       (patternsOfTerm hd2 ++ tl2, s2))
                  _ -> (s1, s2)
        olPairsWithS = map subst olPairs
        overlap_qu = map overlapQuery olPairsWithS
        overlap_query = map (\ f -> Quantification Universal (varDeclOfF f) f
                                nullRange) overlap_qu
{-
  check if leading symbols are new (not in the image of morphism),
        if not, return it as proof obligation
-}
getDefsForOld :: Morphism () () () -> [Named (FORMULA ())] -> [FORMULA ()]
getDefsForOld m fsn = let
        sig = imageOfMorphism m
        oldOpMap = opMap sig
        oldPredMap = predMap sig
        axioms = getAxioms fsn
    in foldr (\ f -> case leadingSym f of
         Just (Left (Qual_op_name ident ot _))
           | MapSet.member ident (toOpType ot) oldOpMap -> (f :)
         Just (Right (Qual_pred_name ident pt _))
           | MapSet.member ident (toPredType pt) oldPredMap -> (f :)
         _ -> id) [] axioms

{- | newly introduced sorts
(the input signature is the domain of the inclusion morphism) -}
getNSorts :: Sign e f -> Morphism e f m -> Set.Set SORT
getNSorts osig m = on Set.difference sortSet (mtarget m) osig

-- | all only generated sorts
getNotFreeSorts :: Set.Set SORT -> [Named (FORMULA ())] -> Set.Set SORT
getNotFreeSorts nSorts fsn = Set.intersection nSorts
    $ Set.difference (getGenSorts fsn) freeSorts where
        freeSorts = foldr (\ f -> case sentence f of
          Sort_gen_ax csts True -> Set.union . Set.fromList $ map newSort csts
          _ -> id) Set.empty fsn

getGenSorts :: [Named (FORMULA ())] -> Set.Set SORT
getGenSorts = fst . recoverSortsAndConstructors []

-- | non-inhabited non-empty sorts
getNefsorts :: (Sign () (), [Named (FORMULA ())]) -> Morphism () () ()
    -> Set.Set SORT -> [Named (FORMULA ())] -> Set.Set SORT
getNefsorts (osig, osens) m nSorts fsn =
  Set.difference fsorts $ inhabited oldSorts cons where
    oldSorts = sortSet osig
    esorts = emptySortSet $ mtarget m
    (srts, cons) = recoverSortsAndConstructors osens fsn
    fsorts = Set.difference (Set.intersection nSorts srts) esorts

getDataStatus :: (Sign () (), [Named (FORMULA ())]) -> Morphism () () ()
  -> [Named (FORMULA ())] -> Conservativity
getDataStatus (osig, osens) m fsn = dataStatus where
        tsig = mtarget m
        subs = Rel.keysSet . Rel.rmNullSets $ sortRel tsig
        nSorts = getNSorts osig m
        gens = Set.intersection nSorts . fst
          $ recoverSortsAndConstructors osens fsn
        dataStatus
          | Set.null nSorts = Def
          | not $ Set.null $ Set.difference (Set.difference nSorts gens) subs
              = Cons
          | otherwise = Mono

getNotComplete :: [Named (FORMULA ())] -> Morphism () () ()
  -> [Named (FORMULA ())] -> [[FORMULA ()]]
getNotComplete osens m fsn =
  let constructors = getOverloadedConstructors osens m fsn in
  filter (not . completePatterns constructors . map patternsOfAxiom)
  $ getAxGroup fsn

getOpsPredsAndExAxioms :: Morphism () () () -> [Named (FORMULA ())]
  -> [FORMULA ()]
getOpsPredsAndExAxioms m fsn = getDefsForOld m fsn ++ getExAxioms fsn

getConStatus :: (Sign () (), [Named (FORMULA ())]) -> Morphism () () ()
  -> [Named (FORMULA ())] -> Conservativity
getConStatus oTh m fsn = min dataStatus defStatus where
  dataStatus = getDataStatus oTh m fsn
  defStatus = if null $ getOpsPredsAndExAxioms m fsn ++ getOverlapQuery fsn
    then Def else Cons

getObligations :: Morphism () () () -> [Named (FORMULA ())] -> [FORMULA ()]
getObligations m fsn = getOpsPredsAndExAxioms m fsn
  ++ getInfoSubsort m fsn ++ getOverlapQuery fsn

isDomainDef :: FORMULA f -> Bool
isDomainDef f = case quanti f of
  Relation (Definedness {}) Equivalence _ _ -> True
  _ -> False

-- check the definitional form of the partial axioms
checkDefinitional :: Sign () () -> [Named (FORMULA ())]
  -> Maybe (Result (Maybe (Conservativity, [FORMULA ()])))
checkDefinitional tsig fsn = let
       formatAxiom :: FORMULA () -> String
       formatAxiom = flip showDoc "" . simplifyCASLSen tsig
       (noLSyms, withLSyms) = partition (isNothing . fst . snd)
         $ map (\ a -> (a, leadingSymPos a)) $ getAxioms fsn
       partialLSyms = foldr (\ (a, (ma, _)) -> case ma of
         Just (Left (Application t@(Qual_op_name _ (Op_type k _ _ _) _) _ _))
           | k == Partial -> ((a, t) :)
         _ -> id) [] withLSyms
       (domainDefs, otherPartials) = partition (isDomainDef . fst) partialLSyms
       (withDefs, withOutDefs) = partition (containDef . fst) otherPartials
       wrongDefs = filter (not . correctDef . fst) withDefs
       grDomainDefs = groupBy (on (==) snd) $ sortBy (on compare snd) domainDefs
       multDomainDefs = filter (\ l -> case l of
          [_] -> False
          _ -> True) grDomainDefs
       defOpSymbs = Set.fromList $ map (snd . head) grDomainDefs
       wrongWithoutDefs = filter ((`Set.member` defOpSymbs) . snd) withOutDefs
       ds = map (\ (a, (_, pos)) -> Diag
         Warning ("missing leading symbol in:\n" ++ formatAxiom a) pos) noLSyms
         ++ map (\ (a, t) -> Diag
         Warning ("definedness is not definitional:\n" ++ formatAxiom a)
                $ getRange t) wrongDefs
         ++ map (\ l@((_, t) : _) -> Diag Warning (unlines $
             ("multiple definedness definitions for: " ++ showDoc t "")
             : map (formatAxiom . fst) l) $ getRange t) multDomainDefs
         ++ map (\ (a, t) -> Diag
         Warning ("missing definedness condition for partial '"
                      ++ showDoc t "' in\n" ++ formatAxiom a)
             $ getRange t) wrongWithoutDefs
       in if null ds then Nothing else Just $ Result ds Nothing

{-
  call the symbols in the image of the signature morphism "new"

- each new sort must be a free type,
  i.e. it must occur in a sort generation constraint that is marked as free
    (Sort_gen_ax constrs True)
    such that the sort is in srts,
        where (srts,ops,_)=recover_Sort_gen_ax constrs
    if not, output "don't know"
  and there must be one term of that sort (inhabited)
    if not, output "no"
- group the axioms according to their leading operation/predicate symbol,
  i.e. the f resp. the p in
  forall x_1:s_n .... x_n:s_n .                  f(t_1,...,t_m)=t
  forall x_1:s_n .... x_n:s_n .       phi =>      f(t_1,...,t_m)=t
                                  Implication  Application  Strong_equation
  forall x_1:s_n .... x_n:s_n .                  p(t_1,...,t_m)<=>phi
  forall x_1:s_n .... x_n:s_n .    phi1  =>      p(t_1,...,t_m)<=>phi
                                 Implication   Predication    Equivalence
  if there are axioms not being of this form, output "don't know"
-}
checkSort :: (Sign () (), [Named (FORMULA ())]) -> Morphism () () ()
    -> [Named (FORMULA ())]
    -> Maybe (Result (Maybe (Conservativity, [FORMULA ()])))
checkSort oTh@(osig, _) m fsn
    | null fsn && Set.null nSorts = Just $ return (Just (Cons, []))
    | not $ Set.null notFreeSorts = mkWarn "some types are not freely generated"
        notFreeSorts Nothing
    | not $ Set.null nefsorts = mkWarn "some sorts are not inhabited"
        nefsorts $ Just (Inconsistent, [])
    | not $ Set.null genNotNew = mkWarn "some free types are not new"
        genNotNew Nothing
    | otherwise = Nothing
    where
        nSorts = getNSorts osig m
        notFreeSorts = getNotFreeSorts nSorts fsn
        nefsorts = getNefsorts oTh m nSorts fsn
        genNotNew = Set.difference (getGenSorts fsn) nSorts
        mkWarn s i r = Just $ Result [mkDiag Warning s i] $ Just r

checkLeadingTerms :: [Named (FORMULA ())] -> Morphism () () ()
  -> [Named (FORMULA ())]
  -> Maybe (Result (Maybe (Conservativity, [FORMULA ()])))
checkLeadingTerms osens m fsn = let
    tsig = mtarget m
    constructors = snd $ recoverSortsAndConstructors osens fsn
    ltp = mapMaybe leadingTermPredication $ getAxioms fsn
    formatTerm = flip showDoc "" . simplifyCASLTerm tsig
    args = foldr (\ ei -> case ei of
      Left (Application os ts qs) ->
         ((qs, "term for " ++ show (opSymbName os), ts) :)
      Right (Predication ps ts qs) ->
         ((qs, "predicate " ++ show (predSymbName ps), ts) :)
      _ -> id) [] ltp
    ds = foldr (\ (qs, d, ts) l ->
           let vs = concatMap varOfTerm ts
               dupVs = vs \\ Set.toList (Set.fromList vs)
               nonCs = checkTerms tsig constructors ts
               td = " in leading " ++ d ++ ": "
           in map (\ v -> Diag Warning
                    ("duplicate variable" ++ td ++ formatTerm v) qs) dupVs
              ++ map (\ t -> Diag Warning
                     ("non-constructor" ++ td ++ formatTerm t)
                     qs) nonCs
              ++ l) [] args
    in if null ds then Nothing else Just $ Result ds Nothing

-- check the sufficient completeness
checkIncomplete :: [Named (FORMULA ())] -> Morphism () () ()
    -> [Named (FORMULA ())]
    -> Maybe (Result (Maybe (Conservativity, [FORMULA ()])))
checkIncomplete osens m fsn = case getNotComplete osens m fsn of
  [] -> Nothing
  incomplete -> let obligations = getObligations m fsn in Just $ Result
      (map (\ (hd : _) -> let
        (lSym, pos) = leadingSymPos hd
        sname = case fmap extractLeadingSymb lSym of
                      Just (Left opS) -> opSymbName opS
                      Just (Right pS) -> predSymbName pS
                      _ -> error "CASL.CCC.FreeTypes.<Symb_Name>"
        in Diag Warning
            ("the definition of " ++ show sname ++ " is not complete") pos)
       incomplete) $ Just $ Just (Cons, obligations)

checkTerminal :: (Sign () (), [Named (FORMULA ())]) -> Morphism () () ()
    -> [Named (FORMULA ())]
    -> IO (Maybe (Result (Maybe (Conservativity, [FORMULA ()]))))
checkTerminal oTh m fsn = do
    let fs = getFs fsn
        fs_terminalProof = filter (\ f ->
          not $ isSortGen f || isMembership f || isExQuanti f || isDomain f
          ) fs
        domains = domainList fs
        obligations = getObligations m fsn
        conStatus = getConStatus oTh m fsn
        res = if null obligations then Nothing else
                  Just $ return (Just (conStatus, obligations))
    if null fs_terminalProof then return res else do
      proof <- terminationProof fs_terminalProof domains
      return $ case proof of
        Just True -> res
        _ -> Just $ warning (Just (Cons, obligations))
             (if isJust proof then "not terminating"
              else "cannot prove termination") nullRange

checkPositive :: [Named (FORMULA ())]
    -> Maybe (Result (Maybe (Conservativity, [FORMULA ()])))
checkPositive fsn =
  if all checkPos $ getFs fsn then Just $ return (Just (Cons, []))
  else Nothing where
    checkPos f = case quanti f of
      Junction _ cs _ -> all checkPos cs
      Relation i1 c i2 _ -> let
        c1 = checkPos i1
        c2 = checkPos i2
        in if c == Equivalence then c1 == c2 else c1 <= c2
      Negation n _ -> not $ checkPos n
      Atom b _ -> b
      Predication {} -> True
      Definedness {} -> True
      Equation {} -> True
      _ -> False

{- -----------------------------------------------------------------------
   function checkFreeType:
   - check if leading symbols are new (not in the image of morphism),
           if not, return them as obligations
   - generated datatype is free
   - if new sort is not etype or esort, it can not be empty.
   - the leading terms consist of variables and constructors only,
           if not, return Nothing
     - split function leading_Symb into
       leadingTermPredication
       and
       extractLeadingSymb
     - collect all operation symbols from recover_Sort_gen_ax fconstrs
                                                       (= constructors)
   - no variable occurs twice in a leading term, if not, return Nothing
   - check that patterns do not overlap, if not, return obligations
     This means:
       in each group of the grouped axioms:
       all patterns of leading terms/formulas are disjoint
       this means: either leading symbol is a variable,
                           and there is just one axiom
                   otherwise, group axioms according to leading symbol
                              no symbol may be a variable
                              check recursively the arguments of
                              constructor in each group
  - sufficient completeness
  - termination proof
------------------------------------------------------------------------
free datatypes and recursive equations are consistent -}
checkFreeType :: (Sign () (), [Named (FORMULA ())]) -> Morphism () () ()
                 -> [Named (FORMULA ())]
                 -> IO (Result (Maybe (Conservativity, [FORMULA ()])))
checkFreeType oTh@(_, osens) m axs = do
  ms <- mapM ($ axs)
    [ return . checkDefinitional (mtarget m)
    , return . checkSort oTh m
    , return . checkLeadingTerms osens m
    , return . checkIncomplete osens m
    , checkTerminal oTh m
    , return . checkPositive]
  return $ case catMaybes ms of
    [] -> return $ Just (getConStatus oTh m axs, [])
    a : _ -> a

{- | group the axioms according to their leading symbol,
output Nothing if there is some axiom in incorrect form -}
groupAxioms :: GetRange f => [FORMULA f] -> [[FORMULA f]]
groupAxioms phis = map (map snd)
   $ groupBy (on (==) fst)  -- maybe consider overload relation here?
   $ sortBy (on compare fst)
   $ foldr (\ f -> case leadingSym f of
    Just ei -> ((ei, f) :)
    Nothing -> id) [] phis

-- | return the non-constructor terms of arguments of a leading term
checkTerms :: Sign f e -> [OP_SYMB] -> [TERM f] -> [TERM f]
checkTerms sig cons = concatMap checkT
  where checkT t = case unsortedTerm t of
          Qual_var {} -> []
          Application subop subts _ ->
            if isCons sig cons subop then concatMap checkT subts else [t]
          _ -> [t]

{- | check whether the operation symbol is a constructor
(or a related overloaded variant). -}
isCons :: Sign f e -> [OP_SYMB] -> OP_SYMB -> Bool
isCons s cons os = any (is_Cons os) cons
    where is_Cons (Qual_op_name on1 ot1 _) (Qual_op_name on2 ot2 _) =
            on1 == on2 && on (leqF s) toOpType ot1 ot2
          is_Cons _ _ = False

-- | create all possible pairs from a list
pairs :: [a] -> [(a, a)]
pairs ps = case ps of
  hd : tl@(_ : _) -> map (\ x -> (hd, x)) tl ++ pairs tl
  _ -> []

-- | get the patterns of a term
patternsOfTerm :: TERM f -> [TERM f]
patternsOfTerm t = case unsortedTerm t of
    Qual_var {} -> [t]
    Application (Qual_op_name {}) ts _ -> ts
    _ -> []

-- | get the patterns of a axiom
patternsOfAxiom :: FORMULA f -> [TERM f]
patternsOfAxiom f = case quanti f of
    Negation f' _ -> patternsOfAxiom f'
    Relation _ c f' _ | c /= Equivalence -> patternsOfAxiom f'
    Relation f' Equivalence _ _ -> patternsOfAxiom f'
    Predication _ ts _ -> ts
    Equation t _ _ _ -> patternsOfTerm t
    Definedness t _ -> patternsOfTerm t
    _ -> []

-- | check whether two patterns are overlapped
checkPatterns :: (Eq f) => ([TERM f], [TERM f]) -> Bool
checkPatterns (ps1, ps2) = case (ps1, ps2) of
  (hd1 : tl1, hd2 : tl2) ->
      if isVar hd1 || isVar hd2 then checkPatterns (tl1, tl2)
      else sameOpsApp hd1 hd2 && checkPatterns (patternsOfTerm hd1 ++ tl1,
                                                patternsOfTerm hd2 ++ tl2)
  _ -> True

{- | get the axiom from left hand side of a implication,
if there is no implication, then return atomic formula true -}
conditionAxiom :: FORMULA f -> FORMULA f
conditionAxiom f = case quanti f of
                     Relation f' c _ _ | c /= Equivalence -> f'
                     _ -> trueForm

{- | get the axiom from right hand side of a equivalence,
if there is no equivalence, then return atomic formula true -}
resultAxiom :: FORMULA f -> FORMULA f
resultAxiom f = case quanti f of
                  Relation _ c f' _ | c /= Equivalence -> resultAxiom f'
                  Relation _ Equivalence f' _ -> f'
                  _ -> trueForm

{- | get the term from right hand side of a equation in a formula,
if there is no equation, then return a simple id -}
resultTerm :: FORMULA f -> TERM f
resultTerm f = case quanti f of
                 Relation _ c f' _ | c /= Equivalence -> resultTerm f'
                 Negation (Definedness _ _) _ ->
                   varOrConst (mkSimpleId "undefined")
                 Equation _ _ t _ -> t
                 _ -> varOrConst (mkSimpleId "unknown")

-- | create the proof obligation for a pair of overlapped formulas
overlapQuery :: (GetRange f, Eq f)
  => ((FORMULA f, [(TERM f, TERM f)]), (FORMULA f, [(TERM f, TERM f)]))
    -> FORMULA f
overlapQuery ((a1, s1), (a2, s2)) =
        case leadingSym a1 of
          Just (Left _)
            | containNeg a1 && not (containNeg a2) ->
                mkImpl (conjunct [con1, con2])
                            (mkNeg (Definedness resT2 nullRange))
            | containNeg a2 && not (containNeg a1) ->
                mkImpl (conjunct [con1, con2])
                            (mkNeg (Definedness resT1 nullRange))
            | containNeg a1 && containNeg a2 -> trueForm
            | otherwise ->
                mkImpl (conjunct [con1, con2])
                            (mkStEq resT1 resT2)
          Just (Right _)
            | containNeg a1 && not (containNeg a2) ->
                mkImpl (conjunct [con1, con2])
                            (mkNeg resA2)
            | containNeg a2 && not (containNeg a1) ->
                mkImpl (conjunct [con1, con2])
                            (mkNeg resA1)
            | containNeg a1 && containNeg a2 -> trueForm
            | otherwise ->
                mkImpl (conjunct [con1, con2])
                            (conjunct [resA1, resA2])
          _ -> error "CASL.CCC.FreeTypes.<overlapQuery>"
      where [c1, c2] = map conditionAxiom [a1, a2]
            [t1, t2] = map resultTerm [a1, a2]
            [r1, r2] = map resultAxiom [a1, a2]
            con1 = substiF s1 c1
            con2 = substiF s2 c2
            resT1 = substitute s1 t1
            resT2 = substitute s2 t2
            resA1 = substiF s1 r1
            resA2 = substiF s2 r2

-- | check whether the patterns of a function or predicate are complete
completePatterns :: [OP_SYMB] -> [[TERM ()]] -> Bool
completePatterns cons pas
    | all null pas = True
    | any null pas = False -- argument lists must be of the same length
    | otherwise = let
          s_op_os c = case c of
                        Op_name _ -> []
                        Qual_op_name o ot _ -> [(res_OP_TYPE ot, o)]
          s_sum = map (\ l@((s, _) : _) -> (s, Set.fromList $ map snd l))
            . groupBy (on (==) fst) . sortBy (on compare fst)
          s_cons = s_sum $ concatMap s_op_os cons
          s_op_t t = case unsortedTerm t of
                       Application os _ _ -> s_op_os os
                       _ -> []
          con_ts = s_sum . concatMap s_op_t
          opN t = case unsortedTerm t of
                    Application os _ _ -> opSymbName os
                    _ -> genName "unknown"
          pa_group p = case p of
            (hdt : _) : _ -> let
              (_ , consForRes) : _ = filter ((== sortOfTerm hdt) . fst) s_cons
               in map (p_g
                     . \ o -> filter (\ (h : _) -> isVar h || opN h == o) p)
                 $ Set.toList consForRes
            _ -> error "pa_group"
          p_g p = map (\ (h : t) ->
            if isVar h
            then replicate (maximum $ map
                   (length . arguOfTerm . head) p) h ++ t
            else arguOfTerm h ++ t) p
          (hds, tls) = unzip $ map (\ (hd : tl) -> (hd, tl)) pas
         in if all isVar hds then completePatterns cons tls else
                let apps : _ = con_ts hds in
                elem apps s_cons &&
                all (completePatterns cons) (pa_group pas)
