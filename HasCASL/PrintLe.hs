
{- HetCATS/HasCASL/PrintLe.hs
   $Id$
   Authors: Christian Maeder
   Year:    2002
   
   printing Le data types
-}

module HasCASL.PrintLe where

import HasCASL.As
import HasCASL.HToken
import Common.Id
import HasCASL.PrintAs
import HasCASL.Le
import Data.Maybe
import Common.PrettyPrint
import Common.Lib.Pretty as Pretty
import qualified Common.Lib.Set as Set
import qualified Common.Lib.Map as Map
import Common.Keywords

instance PrettyPrint ClassInfo where
    printText0 ga (ClassInfo sups k defn) =
        noPrint (case k of ExtClass (Intersection s []) InVar _ -> 
		                       Set.isEmpty s
		           _ -> False) (space <> printKind ga k)
	<> noPrint (isNothing defn)
	   (space <> ptext equalS <+> printText0 ga defn)
	<> noPrint (Set.isEmpty sups)
	   (space <> ptext lessS <+> printList0 ga (Set.toList sups))

instance PrettyPrint TypeDefn where
    printText0 _ NoTypeDefn = empty
    printText0 _ TypeVarDefn = space <> ptext "%(var)%"
    printText0 ga (AliasTypeDefn s) = space <> ptext assignS 
				      <+> printPseudoType ga s
    printText0 ga (Supertype v t f) = space <> ptext equalS <+> 
					 braces (printText0 ga v 
					   <+> colon
					   <+> printText0 ga t 
					   <+> text dotS
					   <+> printText0 ga f)
    printText0 _ (DatatypeDefn k)  = ptext " %%" <>
	let om = ptext " type definition omitted"
					 in case k of
				     Loose -> om
				     Free -> space <> ptext freeS <> om
				     Generated -> space <> ptext generatedS 
						  <> om

instance PrettyPrint TypeInfo where
    printText0 ga (TypeInfo k ks sups defn) =
	space <> colon <> printList0 ga (k:ks) 
	<> noPrint (null sups)
	   (ptext lessS <+> printList0 ga sups)
        <> printText0 ga defn

instance PrettyPrint [Kind] where
    printText0 ga l = space <> colon <> printList0 ga l

instance PrettyPrint [Type] where
    printText0 ga l = space <> colon <> printList0 ga l

instance PrettyPrint OpDefn where
    printText0 _ NoOpDefn = empty
    printText0 _ VarDefn = space <> ptext "%(var)%"
    printText0 _ (ConstructData i) = space <> ptext ("%(construct " ++
				     showId i ")%")
    printText0 ga (SelectData c i) = space <> ptext ("%(select from " ++
				     showId i " constructed by")
				    <+> printList0 ga c <> ptext ")%"
    printText0 ga (Definition t) = space <> ptext equalS <+> 
				   printText0 ga t
 
instance PrettyPrint OpInfo where
    printText0 ga o = space <> colon <+> printText0 ga (opType o)
		      <> (case opAttrs o of 
			  [] -> empty 
			  l -> comma <> commas ga l)
		      <>  printText0 ga (opDefn o)

instance PrettyPrint [OpInfo] where
    printText0 ga l = vcat $ map (printText0 ga) l

instance PrettyPrint a => PrettyPrint (Maybe a) where
    printText0 _ Nothing = empty
    printText0 ga (Just c) =  printText0 ga c

instance (PrettyPrint a, Ord a, PrettyPrint b) 
    => PrettyPrint (Map.Map a b) where
    printText0 ga m =
	let l = Map.toList m in
	    vcat(map (\ (a, b) -> printText0 ga a <> printText0 ga b) l)

instance PrettyPrint Env where
    printText0 ga (Env{classMap=cm, typeMap=tm, 
		       assumps=as, sentences=se, envDiags=ds}) = 
	noPrint (Map.isEmpty cm) (header "Classes")
	$$ printText0 ga cm
	$$ noPrint (Map.isEmpty tm) (header "Type Constructors")
	$$ printText0 ga tm
	$$ noPrint (Map.isEmpty as) (header "Assumptions")
        $$ printText0 ga as
	$$ noPrint (null se) (header "Sentences")
        $$ vcat (map (printText ga) se)
	$$ noPrint (null ds) (header "Diagnostics")
	$$ vcat (map (printText ga) $ reverse ds)
	where header s =  ptext "%%" <+> ptext s 
			  <+> ptext (replicate (70 - length s) '-')
