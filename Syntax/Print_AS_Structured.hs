{-| 
   
Module      :  $Header$
Copyright   :  (c) Klaus L�ttich, Uni Bremen 2002-2004
Licence     :  similar to LGPL, see HetCATS/LICENCE.txt or LIZENZ.txt

Maintainer  :  hets@tzi.de
Stability   :  provisional
Portability :  non-portable(Grothendieck)

   Printing the Structured part of hetrogenous specifications.

-}

module Syntax.Print_AS_Structured where

import Common.Lib.Pretty
import Common.PrettyPrint
import Common.PPUtils

import Logic.Grothendieck
import Logic.Logic

import Syntax.AS_Structured
import Common.Print_AS_Annotation
import Common.AS_Annotation
import Common.GlobalAnnotations

import Data.List
import Data.Maybe (fromMaybe)

instance PrettyPrint SPEC where
    --- This implementation doesn't use the grouping information 
    --- it detects this information by precedence rules
    printText0 ga (Basic_spec aa) =
	nest 4 $ printText0 ga aa
    printText0 ga (Translation aa ab) =
	let aa' = condBracesTransReduct printText0 sp_braces ga aa
	    ab' = printText0 ga ab
	in hang aa' 4 ab'
    printText0 ga (Reduction aa ab) =
	let aa' = condBracesTransReduct printText0 sp_braces ga aa
	    ab' = printText0 ga ab
	in hang aa' 4 ab'
    printText0 ga (Union aa _) = 
	fsep $ pl aa 
	where pl [] = [] 
	      pl (x:xs) =
		  (condBracesAnd printText0 sp_braces ga x):
		  map (\y -> ptext "and" $$ 
		       condBracesAnd printText0 sp_braces ga y) 
		      xs
    printText0 ga (Extension aa _) =
	fsep $ printList aa
	       -- intersperse (ptext "then") $ map (printText0 ga) aa
	where printList [] = []
	      printList (x:xs) = 
		  (printText0 ga x):
		    map (spAnnotedPrint (printText0 ga) 
			 (printText0 ga) (<+>) (ptext "then")) xs
    printText0 ga (Free_spec aa _) =
	hang (ptext "free") 5 $ 
	     condBracesGroupSpec printText0 braces Nothing ga aa
    printText0 ga (Cofree_spec aa _) =
	hang (ptext "cofree") 5 $ 
	     condBracesGroupSpec printText0 braces Nothing ga aa
    printText0 ga (Local_spec aa ab _) =
	let aa' = printText0 ga aa
	    ab' = condBracesWithin printText0 sp_braces ga ab
	in (hang (ptext "local") 4 aa') $$ 
	   (hang (ptext "within") 4 ab')
    printText0 ga (Closed_spec aa _) =
	hang (ptext "closed") 4 $ 
	     condBracesGroupSpec printText0 braces Nothing ga aa
    printText0 ga (Group aa _) =
	printText0 ga aa
        -- maybe?: condBracesGroupSpec printText0 sp_braces ga aa
    printText0 ga (Spec_inst aa ab _) =
	let aa' = printText0 ga aa
	    ab' = print_fit_arg_list printText0 sp_brackets sep ga ab
	in nest 4 (hang aa' 4 ab')
    printText0 ga (Qualified_spec ln asp _) =
	ptext "logic" <+> (printText0 ga ln) <> colon $$ (printText0 ga asp)
    printText0 ga (Data (Logic l) s1 s2 _) =
	ptext (language_name l) <+> (printText0 ga s1) $$ (printText0 ga s2)

instance PrettyPrint RENAMING where
    printText0 ga (Renaming aa _) =
	hang (text "with") 4 $ fcat $ map (printText0 ga) aa

instance PrettyPrint RESTRICTION where
    printText0 ga (Hidden aa _) =
	hang (text "hide") 4 $ fsep $ condPunct comma aa 
                                                $ map (printText0 ga) aa
    printText0 ga (Revealed aa _) =
	hang (text "reveal") 4 $ printText0 ga aa

condPunct :: Doc -> [G_hiding] -> [Doc] -> [Doc]
condPunct _ [] [] = []
condPunct _ _  [] = 
    error "something went wrong in printLatex0 of Hidden"
condPunct _ [] _  = 
    error "something went wrong in printLatex0 of Hidden"
condPunct _ [_c] [d] = [d]
condPunct com (c:cs) (d:ds) = 
		 (case c of
			G_symb_list _gsil -> d<>com 
			G_logic_projection _enc -> d)
		 : condPunct com cs ds


{- hang_latex (hc_sty_plain_keyword "reveal") 8 $ printLatex0 ga aa -}

{- Is declared in Print_AS_Library
instance PrettyPrint SPEC_DEFN where
-}

instance PrettyPrint G_mapping where
    printText0 ga (G_symb_map gsmil) = printText0 ga gsmil
    printText0 ga (G_logic_translation enc) =
	ptext "logic" <+> printText0 ga enc

instance PrettyPrint G_hiding where
    printText0 ga (G_symb_list gsil) = printText0 ga gsil
    printText0 ga (G_logic_projection enc) = 
	ptext "logic" <+> printText0 ga enc

instance PrettyPrint GENERICITY where
    printText0 ga (Genericity aa ab _) =
	let aa' = printText0 ga aa
	    ab' = printText0 ga ab
	in hang aa' 6 ab'

instance PrettyPrint PARAMS where
    printText0 ga (Params aa) =
	if null aa then empty
	else sep $ map (brackets.(nest (-4)).(printText0 ga)) aa

instance PrettyPrint IMPORTED where
    printText0 ga (Imported aa) =
	if null aa then empty 
	else ptext "given" <+> (fsep $ punctuate comma $ 
				         map (condBracesGroupSpec printText0 
					         braces Nothing ga) aa)

instance PrettyPrint FIT_ARG where
    printText0 ga (Fit_spec aa ab _) =
	let aa' = printText0 ga aa
	    ab' = printText0 ga ab
	    null' = case ab of 
		    G_symb_map_items_list _ sis -> null sis
	in aa' <+> if null' then empty else hang (ptext "fit") 4 ab'
    printText0 ga (Fit_view aa ab _ ad) =
	let aa' = printText0 ga aa
	    ab' = print_fit_arg_list printText0 sp_brackets sep ga ab
	    ad' = vcat $ map (printText0 ga) ad
	in ad' $$ hang (ptext "view" <+> aa') 4 ab'


instance PrettyPrint Logic_code where
    printText0 ga (Logic_code (Just enc) (Just src) (Just tar) _) =
	printText0 ga enc <+> colon <+>
	printText0 ga src <+> ptext "->" <+>
	printText0 ga tar
    printText0 ga (Logic_code (Just enc) (Just src) Nothing _) =
	printText0 ga enc <+> colon <+>
	printText0 ga src <+> ptext "->"
    printText0 ga (Logic_code (Just enc) Nothing (Just tar) _) =
	printText0 ga enc <+> colon <+>
	ptext "->" <+> printText0 ga tar
    printText0 ga (Logic_code Nothing (Just src) (Just tar) _) =
	printText0 ga src <+> ptext "->" <+>
	printText0 ga tar
    printText0 ga (Logic_code (Just enc) Nothing Nothing _) =
	printText0 ga enc 
    printText0 ga (Logic_code Nothing (Just src) Nothing _) =
	printText0 ga src <+> ptext "->"
    printText0 ga (Logic_code Nothing Nothing (Just tar) _) =
	ptext "->" <+> printText0 ga tar
    printText0 _ (Logic_code Nothing Nothing Nothing _) =
	ptext ":ERROR" -- should not occur

instance PrettyPrint Logic_name where
    printText0 ga (Logic_name mlog slog) =
        printText0 ga mlog <> 
		       (case slog of 
		       Nothing -> empty 
		       Just sub -> ptext "." <> printText0 ga sub)

-----------------------------------------------
print_fit_arg_list :: (GlobalAnnos -> (Annoted FIT_ARG) -> Doc)
		   -> (Doc -> Doc) -- ^ a function enclosing the Doc
                                   -- in brackets
		   -> ([Doc] -> Doc) -- ^ a function printing a list
                                     -- of Doc seperated by space
		   -> GlobalAnnos -> [Annoted FIT_ARG] -> Doc
print_fit_arg_list _pf _b_fun _sep_fun _ga [] = empty
print_fit_arg_list pf b_fun _sep_fun ga [fa] = b_fun $ pf ga fa
print_fit_arg_list pf b_fun sep_fun ga fas = 
    sep_fun $ map (b_fun . (pf ga)) fas

condBracesGroupSpec :: (GlobalAnnos -> (Annoted SPEC) -> Doc)
		    -> (Doc -> Doc) -- ^ a function enclosing the Doc
                                    -- in braces
		    -> Maybe (String,Doc) -- ^ something like a keyword 
					  -- that should be right before 
		                          -- the braces                        
		    -> GlobalAnnos -> (Annoted SPEC) -> Doc
condBracesGroupSpec pf b_fun mkeyw ga as =
    case skip_Group $ item as of
		 Spec_inst _ _ _ -> str_doc'<>as'
		 Union _ _       -> nested''
		 Extension _ _   -> nested''
		 _               -> 
		     str_doc'<>b_fun as'
    where as' = pf ga as

	  (_str,str_doc) = fromMaybe ("",empty) mkeyw 
	  str_doc' = if isEmpty str_doc then empty 
	             else str_doc
	  nested'' = str_doc' <>b_fun as'

condBracesTransReduct :: (GlobalAnnos -> (Annoted SPEC) -> Doc)
		      -> (Doc -> Doc) -- ^ a function enclosing the Doc
                                      -- in brackets
		      -> GlobalAnnos -> (Annoted SPEC) -> Doc
condBracesTransReduct pf b_fun ga as =
    case skip_Group $ item as of
		 Extension _ _    -> nested''
		 Union _ _        -> nested''
		 Local_spec _ _ _ -> nested''
		 _                -> as'
    where as' = pf ga as
	  nested'' = b_fun as'

condBracesWithin :: (GlobalAnnos -> (Annoted SPEC) -> Doc)
		 -> (Doc -> Doc) -- ^ a function enclosing the Doc
                                 -- in braces
		 -> GlobalAnnos -> (Annoted SPEC) -> Doc
condBracesWithin pf b_fun ga as =
    case skip_Group $ item as of
		 Extension _ _    -> nested''
		 Union _ _        -> nested''
		 _                -> as'
    where as' = pf ga as
	  nested'' = b_fun as'

condBracesAnd :: (GlobalAnnos -> (Annoted SPEC) -> Doc)
	      -> (Doc -> Doc) -- ^ a function enclosing the Doc
                              -- in braces
	      -> GlobalAnnos -> (Annoted SPEC) -> Doc
condBracesAnd pf b_fun ga as =
    case skip_Group $ item as of
		 Extension _ _    -> nested''
		 _                -> as'
    where as' = pf ga as
	  nested'' = b_fun as'

skip_Group :: SPEC -> SPEC
skip_Group sp = 
    case sp of
	    Group as _ -> skip_Group $ item as
	    _          -> sp

-- moved from Print_AS_Annotation
spAnnotedPrint :: (a -> Doc) 
	       -> (Annotation -> Doc)
	       -> (Doc -> Doc -> Doc) -- ^ a function like <+> or <\+>
	       -> Doc -> Annoted a -> Doc
spAnnotedPrint pf pAn beside_ keyw ai = 
    case ai of 
    Annoted i _ las _ ->
	let i'   = pf i
            (msa,as) = case las of
		       []     -> (Nothing,[]) 
		       (x:xs) | isSemanticAnno x -> (Just x,xs)
		       xs     -> (Nothing,xs)
	    san      = case msa of
		       Nothing -> empty
		       Just a  -> pAn a 
	    as' = if null as then empty else vcat $ map pAn as
        in keyw `beside_` san $+$ as' $+$ i'
