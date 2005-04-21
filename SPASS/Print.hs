{- |
Module      :  $Header$
Copyright   :  (c) Rene Wagner, Uni Bremen 2005
Licence     :  similar to LGPL, see HetCATS/LICENCE.txt or LIZENZ.txt

Maintainer  :  rwagner@tzi.de
Stability   :  provisional
Portability :  unknown

   Pretty printing for SPASS signatures.
   Refer to <http://spass.mpi-sb.mpg.de/webspass/help/syntax/dfgsyntax.html>
   for the SPASS syntax documentation.

-}

module SPASS.Print where

import Maybe

import Common.AS_Annotation
import Common.GlobalAnnotations
import Common.Lib.Pretty
import Common.PrettyPrint

import SPASS.Sign

{- |
  Helper function. Generates a '.' as a Doc.
-}
dot :: Doc
dot = char '.'

{- |
  Creates a Doc from a SPASS Problem.
-}
--printProblem :: SPProblem-> Doc
instance PrettyPrint SPProblem where
  printText0 ga p = text "begin_problem" <> parens (text (identifier p)) <> dot
    $$ printText0 ga (description p)
    $$ printText0 ga (logicalPart p)
    $$ text "end_problem."

{- |
  Creates a Doc from a SPASS Logical Part.
-}
--printLogicalPart :: SPLogicalPart-> Doc
instance PrettyPrint SPLogicalPart where
  printText0 ga lp =
    (if isJust (symbolList lp) then printText0 ga (fromJust (symbolList lp)) else empty)
    $$ (if not $ null (declarationList lp) then printDeclarationList (declarationList lp) else empty)
    $$ (if not $ null (formulaLists lp) then printFormulaLists (formulaLists lp) else empty)
    where
      printDeclarationList xs = text "list_of_declarations."
        $$ foldl (\d x-> d $$ printText0 ga x) empty xs
        $$ text "end_of_list."
      printFormulaLists = foldl (\d x-> d $$ printText0 ga x) empty

{- |
  Creates a Doc from a SPASS Symbol List.
-}
--printSymbolList :: SPSymbolList-> Doc
instance PrettyPrint SPSymbolList where
  printText0 ga sl = text "list_of_symbols."
    $$ printSignSymList "functions" (functions sl)
    $$ printSignSymList "predicates" (predicates sl)
    $$ printSignSymList "sorts" (sorts sl)
    $$ printSignSymList "operators" (operators sl)
    $$ printSignSymList "quantifiers" (quantifiers sl)
    $$ text "end_of_list."
    where 
      printSignSymList name list =
        if not $ null list
          then text name <> brackets (foldl (\d x-> if isEmpty d then printText0 ga x else d <> comma $$ printText0 ga x) empty list) <> dot
          else empty

{-|
  Helper function. Creates a Doc from a Signature Symbol.
-}
--printSignSym :: SPSignSym-> Doc
instance PrettyPrint SPSignSym where
  printText0 ga (SPSimpleSignSym s) = text s
  printText0 ga ssym = parens (text (sym ssym) <> comma <> int (arity ssym))

{- |
  Creates a Doc from a SPASS Declaration
-}
--printDeclaration :: SPDeclaration-> Doc
instance PrettyPrint SPDeclaration where
  printText0 ga _ = empty

{- |
  Creates a Common.Lib.Pretty.Doc from a SPASS Formula List
-}
--printFormulaList :: SPFormulaList-> Doc
instance PrettyPrint SPFormulaList where
  printText0 ga l = text "list_of_formulae" <> parens (printText0 ga (originType l)) <> dot
    $$ printFormulae (formulae l)
    $$ text "end_of_list."
    where
      printFormulae = foldl (\fl x-> fl <> printText0 ga x <> dot) empty

{- |
  Creates a Doc from a SPASS Origin Type
-}
--printOriginType :: SPOriginType-> Doc
instance PrettyPrint SPOriginType where
  printText0 ga t = case t of
    SPOriginAxioms      -> text "axioms"
    SPOriginConjectures -> text "conjectures"

{- |
  Creates a Doc from a SPASS Formula.
-}
--printFormula :: SPFormula-> Doc
instance PrettyPrint SPFormula where
  printText0 ga f =
    (text "formula") <> parens (printText0 ga (formulaTerm f) <> comma <> text (formulaLabel f))

{- |
  Creates a Doc from a SPASS Term.
-}
--printTerm :: SPTerm-> Doc
instance PrettyPrint SPTerm where
  printText0 ga t = case t of
    SPQuantTerm{quantSym= qsym, termTermList= tlist, termTerm= t} -> printText0 ga qsym <> parens (brackets (printTermList tlist) <> comma <> printText0 ga t)
    SPSimpleTerm sym -> printText0 ga sym
    SPComplexTerm{symbol= sym, arguments= args} -> printText0 ga sym <> parens (printTermList args)
    where
      printTermList = foldl (\tl x-> if isEmpty tl then printText0 ga x else tl <> comma <> (printText0 ga x)) empty

{- |
  Creates a Doc from a SPASS Quantifier Symbol.
-}
--printQuantSym :: SPQuantSym-> Doc
instance PrettyPrint SPQuantSym where
  printText0 ga qs = case qs of
    SPForall             -> text "forall"
    SPExists             -> text "exists"
    SPCustomQuantSym cst -> text cst

{- |
  Creates a Doc from a SPASS Symbol.
-}
-- printSymbol :: SPSymbol-> Doc
instance PrettyPrint SPSymbol where
    printText0 ga s = case s of
     SPEqual            -> text "equal"
     SPTrue             -> text "true"
     SPFalse            -> text "false"
     SPOr               -> text "or"
     SPAnd              -> text "and"
     SPNot              -> text "not"
     SPImplies          -> text "implies"
     SPImplied          -> text "implied"
     SPEquiv            -> text "equiv"
     SPCustomSymbol cst -> text cst

{- |
  Creates a Doc from a SPASS description.
-}
--printDescription :: SPDescription-> Doc
instance PrettyPrint SPDescription where
  printText0 ga d = text "list_of_descriptions."
    $$ text "name" <> parens (spText (name d)) <> dot
    $$ text "author" <> parens (spText (author d)) <> dot
    $$ (if isJust (version d) then text "version" <> parens (spText (fromJust (version d))) <> dot else empty)
    $$ (if isJust (logic d) then text "logic" <> parens (spText (fromJust (logic d))) <> dot else empty)
    $$ text "status" <> parens (printText0 ga (status d)) <> dot
    $$ text "description" <> parens (spText (desc d)) <> dot
    $$ (if isJust (date d) then text "date" <> parens (text (fromJust (date d))) <> dot else empty)
    $$ text "end_of_list."

{- |
  Helper function. Wraps a String in "{*  *}" as required for some of the
  description fields.
-}
spText :: String-> Doc
spText s = text "{* " <> text s <> text " *}"

{- |
  Creates a Doc from an 'SPLogState'.
-}
--printLogState :: SPLogState-> Doc
instance PrettyPrint SPLogState where
  printText0 ga s = case s of
    SPStateSatisfiable   -> text "satisfiable"
    SPStateUnsatisfiable -> text "unsatisfiable"
    SPStateUnknown       -> text "unknown"
