{- |
Module      :  $Header$
Description :  Transformation between Haskell and Maude
Copyright   :  (c) Adrian Riesco, Facultad de Informatica UCM 2009
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  ariesco@fdi.ucm.es
Stability   :  experimental
Portability :  portable

Translations from Haskell to Maude.
-}

module Maude.Printing () where

import Maude.AS_Maude
import Maude.Symbol

import Common.Doc
import Common.DocUtils (Pretty(..))


combine :: (Pretty a) => (Doc -> Doc) -> ([Doc] -> Doc) -> [a] -> Doc
combine wrap dsep = wrap . dsep . map pretty

parenPretties :: (Pretty a) => [a] -> Doc
parenPretties = combine parens hsep

bracketPretties :: (Pretty a) => [a] -> Doc
bracketPretties = combine brackets hsep

combineHooks :: (Pretty a) => [a] -> Doc
combineHooks = combine (parens . ((<>) $ text "\n")) (vsep . map ((<>) $ text "\t")) 

instance Pretty Membership where
    pretty (Mb t s cs as) = hsep
        [keyword "mb", pretty t, colon, pretty s, pretty cs, pretty as, dot]

instance Pretty Equation where
    pretty (Eq t1 t2 cs as) = hsep
        [keyword "eq", pretty t1, equals, pretty t2, pretty cs, pretty as, dot]

instance Pretty Rule where
    pretty (Rl t1 t2 cs as) = hsep
        [keyword "rl", pretty t1, implies, pretty t2, pretty cs, pretty as, dot]


instance Pretty Condition where
    pretty cond = let pretty' x y z = hsep [pretty x, y, pretty z]
        in case cond of
            MbCond t  s  -> pretty' t colon s
            EqCond t1 t2 -> pretty' t1 equals t2
            RwCond t1 t2 -> pretty' t1 implies t2
            MatchCond t1 t2 -> pretty' t1 (text ":=") t2
    pretties = combine (text "if" <+>) (hsep . punctuate andDoc)


instance Pretty Attr where
    pretty attr = case attr of
        Assoc -> text "assoc"
        Comm -> text "comm"
        Idem -> text "idem"
        Iter -> text "iter"
        Id term -> text "id:" <+> pretty term
        LeftId term -> text "id-left:" <+> pretty term
        RightId term -> text "id-right:" <+> pretty term
        Strat ints -> text "strat" <+> parenPretties ints
        Memo -> text "memo"
        Prec int -> text "prec" <+> pretty int
        Gather qids -> text "gather" <+> parenPretties qids
        Format qids -> text "format" <+> parenPretties qids
        Ctor -> text "ctor"
        Config -> text "config"
        Object -> text "object"
        Msg -> text "msg"
        -- TODO: Is Frozen the only attribute where the parens must be left out for empty lists?
        -- Frozen ints -> text "frozen" <+> parenPretties ints
        Frozen ints -> if null ints
            then text "frozen"
            else text "frozen" <+> parenPretties ints
        Poly ints -> text "poly" <+> parenPretties ints
        Special hooks -> text "special" <+> combineHooks hooks
    pretties attrs = if null attrs
        then empty
        else bracketPretties attrs


instance Pretty StmntAttr where
    pretty attr = case attr of
        Owise        -> text "owise"
        Nonexec      -> text "nonexec"
        Metadata str -> text "metadata" <+> doubleQuotes (pretty str)
        Label qid    -> text "label" <+> doubleQuotes (pretty qid)
        Print _      -> empty
    pretties = bracketPretties


instance Pretty Hook where
    pretty hook = case hook of
        IdHook qid qs -> hsep
            [text "id-hook", pretty qid, parenPretties qs]
        OpHook qid op dom cod -> hsep
            [text "op-hook", pretty qid, parens . pretty $ mkOpPartial op dom cod]
        TermHook qid term -> hsep
            [text "term-hook", pretty qid, parens . pretty $ term]
    pretties = combine parens vsep


instance Pretty Term where
    pretty term = case term of
        Const qid _    -> pretty qid
        Var   qid tp   -> hcat [pretty qid, colon, pretty tp]
        Apply qid ts _ -> pretty qid <> (parens . pretty $ ts)
    pretties = combine id sepByCommas


instance Pretty Type where
    pretty typ = case typ of
        TypeSort sort -> pretty sort
        TypeKind kind -> pretty kind

instance Pretty Sort where
    pretty (SortId qid) = pretty qid

instance Pretty Kind where
    pretty (KindId qid) = pretty qid

instance Pretty ParamId where
    pretty (ParamId qid) = pretty qid

instance Pretty ViewId where
    pretty (ViewId qid) = pretty qid

instance Pretty ModId where
    pretty (ModId qid) = pretty qid

instance Pretty LabelId where
    pretty (LabelId qid) = pretty qid

instance Pretty OpId where
    pretty (OpId qid) = pretty qid
