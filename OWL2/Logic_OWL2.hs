{-# LANGUAGE CPP, MultiParamTypeClasses, TypeSynonymInstances #-}
{-# OPTIONS -w #-}
{- |
Module      :  ./OWL2/Logic_OWL2.hs
Description :  instance of the class Logic for OWL2
Copyright   :  (c) Christian Maeder, DFKI GmbH 2011
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  non-portable

Here is the place where the class Logic is instantiated for OWL2.
-}

module OWL2.Logic_OWL2 where

import ATC.ProofTree ()

import Common.AS_Annotation as Anno
import Common.Consistency
import Common.DefaultMorphism
import Common.Doc
import Common.DocUtils
import Common.ProofTree
import Common.ProverTools
import Common.IRI

import Common.ExtSign
import Common.Result

import Data.Char (isAlpha)
import Data.Monoid
import Data.Maybe (fromJust)
import qualified Data.Map as Map
import qualified Data.Set as Set

import Logic.Logic

import OWL2.AS
--import OWL2.ATC_OWL2 ()
import OWL2.ColimSign
import OWL2.Conservativity
--import OWL2.MS2Ship
import qualified OWL2.PrintMS as PrMS (printOntologyDocument)
import qualified OWL2.PrintAS as PrAS (printOntologyDocument, printAxiom)
import OWL2.Pretty
import OWL2.Morphism
import qualified OWL2.ParseMS as PaMS (parseOntologyDocument)
import qualified OWL2.ParseAS as PaAS (parseOntologyDocument) 
import OWL2.ManchesterPrint (convertBasicTheory, convertBasicTheory')
import OWL2.Parse (symbItem, symbItems, symbMapItems) --temporary
import OWL2.ProfilesAndSublogics
import OWL2.ProveFact
import OWL2.ProvePellet
import OWL2.ProveHermit
import OWL2.Rename
import OWL2.Sign
import OWL2.StaticAnalysis
import OWL2.Symbols
import OWL2.Taxonomy
import OWL2.Theorem
-- import OWL2.ExtractModule
import ATerm.Conversion

data OWL2 = OWL2

instance ShATermConvertible SymbItems
instance ShATermConvertible SymbMapItems
instance ShATermConvertible Sign
instance ShATermConvertible Axiom
instance ShATermConvertible OntologyDocument
instance ShATermConvertible OWLMorphism
instance ShATermConvertible Entity
instance ShATermConvertible ProfSub

instance Show OWL2 where
  show _ = "OWL"

instance Language OWL2 where
  description _ =
    "OWL -- Web Ontology Language http://www.w3.org/TR/owl2-overview/"

instance Category Sign OWLMorphism where
    ide sig = inclOWLMorphism sig sig
    dom = osource
    cod = otarget
    legal_mor = legalMor
    isInclusion = isOWLInclusion
    composeMorphisms = composeMor

instance Semigroup Ontology where
    (Ontology n v i1 a1 ax1) <> (Ontology _ _ i2 a2 ax2) =
        Ontology n v (i1 ++ i2) (a1 ++ a2) (ax1 ++ ax2)
instance Monoid Ontology where
    mempty = Ontology Nothing Nothing [] [] []

instance Semigroup OntologyDocument where
    (OntologyDocument m p1 o1) <> (OntologyDocument _ p2 o2) =
      OntologyDocument m (Map.union p1 p2) $ mappend o1 o2
instance Monoid OntologyDocument where
    mempty = OntologyDocument (OntologyMetadata AS) mempty mempty

instance Syntax OWL2 OntologyDocument Entity SymbItems SymbMapItems where
    parsersAndPrinters OWL2 = -- addSyntax "Ship" (parseOntologyDocument, ppShipOnt) 
      addSyntax "Manchester" (PaMS.parseOntologyDocument, PrMS.printOntologyDocument)
      $ addSyntax "Functional" (PaAS.parseOntologyDocument, PrAS.printOntologyDocument)
      $ makeDefault (PaMS.parseOntologyDocument, PrMS.printOntologyDocument)
    parseSingleSymbItem OWL2 = Just . const $ symbItem
    parse_symb_items OWL2 = Just . const $ symbItems
    parse_symb_map_items OWL2 = Just . const $ symbMapItems
    symb_items_name OWL2 = symbItemsName


printOneNamed :: Anno.Named Axiom -> Doc
printOneNamed ns = PrAS.printAxiom mempty
  $ (if Anno.isAxiom ns then rmImplied else addImplied) $ Anno.sentence ns

instance Sentences OWL2 Axiom Sign OWLMorphism Entity where
    map_sen OWL2 = mapSen
    print_named OWL2 = printOneNamed
    sym_of OWL2 = singletonList . symOf
    symmap_of OWL2 = symMapOf
    sym_name OWL2 = entityToId
    sym_label OWL2 = label
    fullSymName OWL2 s = let
      i = cutIRI s
      x = showIRI i --expandedIRI i
      in if null x then getPredefName i else x
    symKind OWL2 = takeWhile isAlpha . showEntityType . entityKind
    symsOfSen OWL2 _ = Set.toList . symsOfAxiom
    pair_symbols OWL2 = pairSymbols

inducedFromToMor :: Map.Map RawSymb RawSymb -> 
                    ExtSign Sign Entity -> 
                    ExtSign Sign Entity -> 
                    Result OWLMorphism
inducedFromToMor rm s@(ExtSign ssig _) t@(ExtSign tsig _) = 
 case Map.toList rm of
   [] -> do 
     let 
       mkImplMap f k = 
         case Set.toList (f tsig) of 
           [x] -> 
              let aEntity = Entity Nothing k x
              in Map.fromList $ 
                    map (\y -> (ASymbol $ Entity Nothing k y, 
                               ASymbol $ aEntity)) $ 
                    Set.toList $ f ssig
           _ -> Map.empty 
       rm' = Map.unions
                   [mkImplMap concepts Class,
                    mkImplMap objectProperties ObjectProperty,
                    mkImplMap dataProperties DataProperty, 
                    mkImplMap individuals NamedIndividual]
      in inducedFromToMorphismAux rm' s t 
   _ ->  inducedFromToMorphismAux rm  s t

inducedFromToMorphismAux :: Map.Map RawSymb RawSymb -> 
                    ExtSign Sign Entity -> 
                    ExtSign Sign Entity -> 
                    Result OWLMorphism
inducedFromToMorphismAux rm s@(ExtSign ssig _) t@(ExtSign tsig _) = do
    mor <- inducedFromMor rm ssig
    let csig = cod mor
    incl <- inclusion OWL2 csig tsig              
    composeMorphisms mor incl

instance StaticAnalysis OWL2 OntologyDocument Axiom
               SymbItems SymbMapItems
               Sign
               OWLMorphism
               Entity RawSymb where
      basic_analysis OWL2 = Just basicOWL2Analysis
      stat_symb_items OWL2 s = return . statSymbItems s
      stat_symb_map_items OWL2 = statSymbMapItems
      convertTheory OWL2 = Just convertBasicTheory
      empty_signature OWL2 = emptySign
      signature_union OWL2 = uniteSign
      intersection OWL2 = intersectSign
      morphism_union OWL2  = morphismUnion
      signatureDiff OWL2 s = return . diffSig s
      final_union OWL2 = signature_union OWL2
      is_subsig OWL2 = isSubSign
      subsig_inclusion OWL2 s = return . inclOWLMorphism s
      matches OWL2 = matchesSym
      symbol_to_raw OWL2 = ASymbol
      id_to_raw OWL2 = idToRaw
      add_symb_to_sign OWL2 = addSymbToSign
      induced_from_morphism OWL2 = inducedFromMor
      induced_from_to_morphism OWL2 = inducedFromToMor
      cogenerated_sign OWL2 = cogeneratedSign
      generated_sign OWL2 = generatedSign
      signature_colimit OWL2 = return . signColimit
      corresp2th OWL2 = corr2theo
      equiv2cospan OWL2 = addEquiv
    --   extract_module OWL2 = extractModule
#ifdef UNI_PACKAGE
      theory_to_taxonomy OWL2 = onto2Tax
#endif
instance Logic OWL2 ProfSub OntologyDocument Axiom SymbItems SymbMapItems
               Sign
               OWLMorphism Entity RawSymb ProofTree where
         empty_proof_tree OWL2 = emptyProofTree
         -- just a selection of sublogics
         all_sublogics OWL2 = bottomS : concat allProfSubs ++ [topS]
         bottomSublogic OWL2 = Just bottomS
         sublogicDimensions OWL2 = allProfSubs
         parseSublogic OWL2 _ = Just topS -- ignore sublogics
         provers OWL2 = [pelletProver, factProver, hermitProver]
         default_prover OWL2 = "Fact"
         cons_checkers OWL2 = [pelletConsChecker, factConsChecker, hermitConsChecker]
         conservativityCheck OWL2 = map
           (\ ct -> ConservativityChecker ("Locality_" ++ ct)
                    (checkOWLjar localityJar) $ conserCheck ct)
           ["BOTTOM_BOTTOM", "TOP_BOTTOM", "TOP_TOP"]
         stability OWL2 = Stable
         sublogicOfTheo OWL2 = profilesAndSublogic . convertBasicTheory'

instance SemiLatticeWithTop ProfSub where
    lub = maxS
    top = topS

instance SublogicName ProfSub where
    sublogicName = nameS

instance MinSublogic ProfSub Axiom where
    minSublogic = psAxiom

instance MinSublogic ProfSub OWLMorphism where
    minSublogic = sMorph

instance ProjectSublogic ProfSub OWLMorphism where
    projectSublogic = prMorph

instance MinSublogic ProfSub Sign where
    minSublogic = sSig

instance ProjectSublogic ProfSub Sign where
    projectSublogic = prSign

instance MinSublogic ProfSub SymbItems where
    minSublogic = const topS

instance MinSublogic ProfSub SymbMapItems where
    minSublogic = const topS

instance MinSublogic ProfSub Entity where
    minSublogic = const topS

instance MinSublogic ProfSub OntologyDocument where
    minSublogic = profilesAndSublogic

instance ProjectSublogicM ProfSub SymbItems where
    projectSublogicM = const Just

instance ProjectSublogicM ProfSub SymbMapItems where
    projectSublogicM = const Just

instance ProjectSublogicM ProfSub Entity where
    projectSublogicM = const Just

instance ProjectSublogic ProfSub OntologyDocument where
    projectSublogic = prOntDoc
