{-| 
   
Module      :  $Header$
Copyright   :  (c) Klaus L�ttich, Uni Bremen 2002-2004
Licence     :  similar to LGPL, see HetCATS/LICENCE.txt or LIZENZ.txt

Maintainer  :  hets@tzi.de
Stability   :  provisional
Portability :  non-portable(Grothendieck)

   LaTeX Printing the Structured part of hetrogenous specifications.

-}

module Syntax.LaTeX_AS_Structured where

import Common.Lib.Pretty
import Common.PrintLaTeX
import Common.LaTeX_utils

import Logic.Grothendieck

import Syntax.AS_Structured
import Syntax.Print_AS_Structured
import Common.Print_AS_Annotation
import Common.AS_Annotation
import Common.GlobalAnnotations
import Logic.LaTeX_Grothendieck

import Data.Maybe (fromMaybe)

instance PrintLaTeX SPEC where
    printLatex0 ga (Basic_spec aa) =
        tabbed_nest_latex $ printLatex0 ga aa
    printLatex0 ga (Translation aa ab) =
	let aa' = condBracesTransReduct printLatex0 
		           sp_braces_latex2 ga aa
	    ab' = printLatex0 ga ab
	in tab_hang_latex aa' 8 ab'
    printLatex0 ga (Reduction aa ab) =
	let aa' = condBracesTransReduct printLatex0 
		        sp_braces_latex2 ga aa
	    ab' = printLatex0 ga ab
	in tab_hang_latex aa' 8 ab'
    printLatex0 ga (Union aa _) = fsep_latex $ intersperse' aa 
	where intersperse' [] = [] 
	      intersperse' (x:xs) =
		  (condBracesAnd printLatex0 sp_braces_latex2 ga x):
		  map (\y -> hc_sty_plain_keyword "and" $$ 
		       condBracesAnd printLatex0 sp_braces_latex2 ga y)
                      xs
    printLatex0 ga (Extension aa _) =
	fsep_latex $ printList aa
	where printList [] = []
	      printList (x:xs) =
		  (sp_space <> printLatex0 ga' x):
		    map (spAnnotedPrint (printLatex0 ga') 
			 (printLatex0 ga') (<\+>)
			        (hc_sty_hetcasl_keyword "then")) xs
	      (sp_space,ga') = sp_space_latex ga
    printLatex0 ga (Free_spec aa _) =
	tabbed_nest_latex (condBracesGroupSpec printLatex0 
					  sp_braces_latex2 mkw ga aa)
	where mkw = 
		  mkMaybeKeywordTuple Nothing $ hc_sty_plain_keyword "free"
    printLatex0 ga (Local_spec aa ab _) =
	let aa' = sp_braces_latex2 $ set_tabbed_nest_latex $ 
	          (cond_space<> printLatex0 ga aa)
	    ab' = condBracesWithin printLatex0 sp_braces_latex2 ga ab
	    cond_space = case skip_Group $ item aa of
			 Extension _ _ -> space
			 Union _ _ -> space
			 _ -> empty
	    space = hspace_latex (
		       pt_length (keyword_width "view" + normal_width "~"))
		       <>setTab_latex
	in tabbed_nest_latex (setTabWithSpaces_latex 3<>
		 fsep [hc_sty_plain_keyword "local",tabbed_nest_latex aa',
		       hc_sty_plain_keyword "within",tabbed_nest_latex ab'])
    printLatex0 ga (Closed_spec aa _) =
	tabbed_nest_latex (condBracesGroupSpec printLatex0 
                                           sp_braces_latex2 mkw ga aa)
	where mkw = mkMaybeKeywordTuple Nothing
		    $ hc_sty_plain_keyword "closed"
    printLatex0 ga (Group aa _) =
	printLatex0 ga aa
    printLatex0 ga (Spec_inst aa ab _) =
	let aa' = simple_id_latex aa 
	    ga' = set_inside_gen_arg True (set_first_spec_in_param True ga) 
	in tabbed_nest_latex $
	   if null ab 
	   then aa' 
	   else aa' <\+> set_tabbed_nest_latex
		    (fsep_latex $ 
	              map (brackets_latex.
			   (\x -> set_tabbed_nest_latex
			          (printLatex0 ga' x))) ab)
	where ga' = set_inside_gen_arg True (set_first_spec_in_param True ga) 
    printLatex0 ga (Qualified_spec ln asp _) =
	hc_sty_plain_keyword "logic" <\+> 
            (printLatex0 ga ln) <> colon_latex $$ (printLatex0 ga asp)

instance PrintLaTeX RENAMING where
    printLatex0 ga (Renaming aa _) =
       hc_sty_plain_keyword "with"<\+>
          set_tabbed_nest_latex (fsep_latex (map (printLatex0 ga) aa))


instance PrintLaTeX RESTRICTION where
    printLatex0 ga (Hidden aa _) =
       hc_sty_plain_keyword "hide"<\+>
          set_tabbed_nest_latex 
                (fsep_latex (condPunct comma_latex 
                                       aa (map (printLatex0 ga) aa)))
    printLatex0 ga (Revealed aa _) =
	hc_sty_plain_keyword "reveal"<\+>
	  set_tabbed_nest_latex (printLatex0 ga aa)

{- hang_latex (hc_sty_plain_keyword "reveal") 8 $ printLatex0 ga aa -}

{- Is declared in Print_AS_Library
instance PrettyPrint SPEC_DEFN where
-}

instance PrintLaTeX G_mapping where
    printLatex0 ga (G_symb_map gsmil) = printLatex0 ga gsmil
    printLatex0 ga (G_logic_translation enc) =
	hc_sty_plain_keyword "logic" <\+> printLatex0 ga enc

instance PrintLaTeX G_hiding where
    printLatex0 ga (G_symb_list gsil) = printLatex0 ga gsil
    printLatex0 ga (G_logic_projection enc) = 
	hc_sty_plain_keyword "logic" <\+> printLatex0 ga enc

instance PrintLaTeX GENERICITY where
    printLatex0 ga (Genericity aa ab _) =
	let aa' = set_tabbed_nest_latex $ printLatex0 ga aa
	    ab' = printLatex0 ga ab
	in if isEmpty aa' && isEmpty ab' 
	   then empty 
	   else 
	      if isEmpty aa' 
	      then ab' 
	      else if isEmpty ab' 
		   then aa' 
		   else fsep_latex [aa'<~>setTab_latex,
				    tabbed_nest_latex $ ab']

instance PrintLaTeX PARAMS where
    printLatex0 ga (Params aa) =
	if null aa then empty
	else sep_latex $ 
	              map (brackets_latex.
			   (\x -> set_tabbed_nest_latex
			          (printLatex0 ga' x))) aa
	where ga' = set_inside_gen_arg True (set_first_spec_in_param True ga) 

instance PrintLaTeX IMPORTED where
    printLatex0 ga (Imported aa) =
	let mkw = mkMaybeKeywordTuple Nothing
		       (hc_sty_plain_keyword "given")
	    coBrGrSp = condBracesGroupSpec printLatex0 sp_braces_latex2
	    taa = tail aa
	    taa' = if null taa then [] 
		   else punctuate comma_latex $ tabList_latex $
			   map ( coBrGrSp Nothing ga) taa
	    condComma = if null taa then empty else comma_latex
	    aa' = fsep_latex (map (coBrGrSp Nothing ga) aa)
	in if null aa then empty 
	   else  fsep_latex ((coBrGrSp mkw ga (head aa) <> condComma): taa')
        
{-	tabbed_nest_latex (condBracesGroupSpec printLatex0 
					  sp_braces_latex2 mkw ga aa)
	where mkw = 
		  mkMaybeKeywordTuple Nothing $ hc_sty_plain_keyword "free"
-}
instance PrintLaTeX FIT_ARG where
    printLatex0 ga (Fit_spec aa ab _) =
	let aa' = printLatex0 ga aa
	    ab' = printLatex0 ga ab
	    null' = case ab of 
		    G_symb_map_items_list _ sis -> null sis
	in if null' then aa' 
	else fsep_latex [aa',
			     hc_sty_plain_keyword "fit"<\+>
			         set_tabbed_nest_latex ab']
    printLatex0 ga (Fit_view aa ab _ ad) =
	let aa' = simple_id_latex aa
	    ab' = print_fit_arg_list printLatex0 
	                             brackets_latex 
				     sep_latex
				     ga ab
	    ad' = vcat $ map (printLatex0 ga) ad
	    view_name = hc_sty_plain_keyword "view" <\+> aa'
	in ad' $$ if null ab then view_name else setTabWithSpaces_latex 16 <> tab_hang_latex view_name 16 ab'

{- This can be found in Print_AS_Library
instance PrintLaTeX VIEW_DEFN where
-}

instance PrintLaTeX Logic_code where
    printLatex0 ga (Logic_code (Just enc) (Just src) (Just tar) _) =
	printLatex0 ga enc <\+> colon_latex <\+>
	printLatex0 ga src <\+> hc_sty_axiom "\\rightarrow" <\+>
	printLatex0 ga tar
    printLatex0 ga (Logic_code (Just enc) (Just src) Nothing _) =
	printLatex0 ga enc <\+> colon_latex <\+>
	printLatex0 ga src <\+> hc_sty_axiom "\\rightarrow"
    printLatex0 ga (Logic_code (Just enc) Nothing (Just tar) _) =
	printLatex0 ga enc <\+> colon <\+>
	hc_sty_axiom "\\rightarrow" <\+> printLatex0 ga tar
    printLatex0 ga (Logic_code Nothing (Just src) (Just tar) _) =
	printLatex0 ga src <\+> hc_sty_axiom "\\rightarrow" <\+>
	printLatex0 ga tar
    printLatex0 ga (Logic_code (Just enc) Nothing Nothing _) =
	printLatex0 ga enc 
    printLatex0 ga (Logic_code Nothing (Just src) Nothing _) =
	printLatex0 ga src <\+> hc_sty_axiom "\\rightarrow"
    printLatex0 ga (Logic_code Nothing Nothing (Just tar) _) =
	hc_sty_axiom "\\rightarrow" <\+> printLatex0 ga tar
    printLatex0 _ (Logic_code Nothing Nothing Nothing _) =
	ptext ":ERROR" -- should not occur

instance PrintLaTeX Logic_name where
    printLatex0 ga (Logic_name mlog slog) =
        printLatex0 ga mlog <> 
		       (case slog of 
		       Nothing -> empty 
		       Just sub -> casl_normal_latex "." <> printLatex0 ga sub)


mkMaybeKeywordTuple :: Maybe String -> Doc -> Maybe (String,Doc)
mkMaybeKeywordTuple mstr kw_doc = 
    Just (fromMaybe (if isEmpty kw_doc then "" 
		     else show $ kw_doc<~>setTab_latex) mstr,kw_doc)

sp_space_latex :: GlobalAnnos -> (Doc,GlobalAnnos)
sp_space_latex ga = if is_inside_gen_arg ga && is_first_spec_in_param ga
		    then (space,set_first_spec_in_param False ga)
		    else (empty,ga)
    where space = hspace_latex $ pt_length (keyword_width "view" + normal_width "~")
