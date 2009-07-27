{- |
Module      :  $Header$
Description :  derived functions for signatures with symbol sets
Copyright   :  (c) Till Mossakowski, and Uni Bremen 2002-2006
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt
Maintainer  :  till@informatik.uni-bremen.de
Stability   :  provisional
Portability :  non-portable (imports Logic.Logic)

Functions from the class Logic that operate over signatures are
extended to work over signatures with symbol sets.
-}

module Logic.ExtSign where

import qualified Data.Set as Set
import qualified Data.Map as Map
import Control.Monad
import Common.Result
import Common.DocUtils
import Common.ExtSign
import Logic.Logic

ext_sym_of :: Logic lid sublogics
        basic_spec sentence symb_items symb_map_items
        sign morphism symbol raw_symbol proof_tree
        => lid -> ExtSign sign symbol -> Set.Set symbol
ext_sym_of l = sym_of l . plainSign

-- | simply put all symbols into the symbol set
makeExtSign :: Logic lid sublogics
        basic_spec sentence symb_items symb_map_items
        sign morphism symbol raw_symbol proof_tree
        => lid -> sign -> ExtSign sign symbol
makeExtSign l s = ExtSign s $ sym_of l s

ext_ide :: (Ord symbol, Category sign morphism)
           => ExtSign sign symbol -> morphism
ext_ide = ide . plainSign

ext_empty_signature :: Logic lid sublogics
        basic_spec sentence symb_items symb_map_items
        sign morphism symbol raw_symbol proof_tree
        => lid -> ExtSign sign symbol
ext_empty_signature l = mkExtSign (empty_signature l)

checkExtSign :: Logic lid sublogics
        basic_spec sentence symb_items symb_map_items
        sign morphism symbol raw_symbol proof_tree
        => lid -> String -> ExtSign sign symbol -> Result ()
checkExtSign l msg e@(ExtSign s sy) = let sys = sym_of l s in
    if Set.isSubsetOf sy sys then return () else
        error $ "inconsistent symbol set in extended signature: " ++ msg ++ "\n"
             ++ showDoc e "\rwith unknown symbols\n"
             ++ showDoc (Set.difference sy sys) ""

ext_signature_union :: Logic lid sublogics
        basic_spec sentence symb_items symb_map_items
        sign morphism symbol raw_symbol proof_tree
        => lid -> ExtSign sign symbol -> ExtSign sign symbol
               -> Result (ExtSign sign symbol)
ext_signature_union l e1@(ExtSign s1 _) e2@(ExtSign s2 _) = do
    checkExtSign l "u1" e1
    checkExtSign l "u2" e2
    s <- signature_union l s1 s2
    return $ makeExtSign l s

ext_is_subsig :: Logic lid sublogics
        basic_spec sentence symb_items symb_map_items
        sign morphism symbol raw_symbol proof_tree
        => lid -> ExtSign sign symbol -> ExtSign sign symbol -> Bool
ext_is_subsig l (ExtSign sig1 _) (ExtSign sig2 _) =
    is_subsig l sig1 sig2

ext_final_union :: Logic lid sublogics
        basic_spec sentence symb_items symb_map_items
        sign morphism symbol raw_symbol proof_tree
        => lid -> ExtSign sign symbol -> ExtSign sign symbol
               -> Result (ExtSign sign symbol)
ext_final_union l e1@(ExtSign s1 _) e2@(ExtSign s2 _) = do
    checkExtSign l "f1" e1
    checkExtSign l "f2" e2
    s <- final_union l s1 s2
    return $ makeExtSign l s

ext_inclusion :: Logic lid sublogics
        basic_spec sentence symb_items symb_map_items
        sign morphism symbol raw_symbol proof_tree
        => lid -> ExtSign sign symbol -> ExtSign sign symbol -> Result morphism
ext_inclusion l (ExtSign s1 _) (ExtSign s2 _) =
    inclusion l s1 s2

ext_generated_sign :: Logic lid sublogics
        basic_spec sentence symb_items symb_map_items
        sign morphism symbol raw_symbol proof_tree
        => lid -> Set.Set symbol -> ExtSign sign symbol -> Result morphism
ext_generated_sign l s (ExtSign sig _) =
    generated_sign l s sig

ext_cogenerated_sign :: Logic lid sublogics
        basic_spec sentence symb_items symb_map_items
        sign morphism symbol raw_symbol proof_tree
        => lid -> Set.Set symbol -> ExtSign sign symbol -> Result morphism
ext_cogenerated_sign l s (ExtSign sig _) =
    cogenerated_sign l s sig

ext_induced_from_morphism :: Logic lid sublogics
        basic_spec sentence symb_items symb_map_items
        sign morphism symbol raw_symbol proof_tree
        => lid -> EndoMap raw_symbol -> ExtSign sign symbol
               -> Result morphism
ext_induced_from_morphism l rmap (ExtSign sigma _) = do
  -- first check: do all source raw symbols match with source signature?
  checkRawMap l rmap sigma
  induced_from_morphism l rmap sigma

checkRawMap :: Logic lid sublogics
        basic_spec sentence symb_items symb_map_items
        sign morphism symbol raw_symbol proof_tree
        => lid -> EndoMap raw_symbol -> sign -> Result ()
checkRawMap l rmap sigma = do
  let syms = sym_of l sigma
      unknownSyms = Set.filter
          ( \ rsy -> Set.null $ Set.filter (flip (matches l) rsy) syms)
          $ Map.keysSet rmap
  unless (Set.null unknownSyms)
    $ Result [mkDiag Error "unknown symbols" unknownSyms] $ Just ()

ext_induced_from_to_morphism :: Logic lid sublogics
        basic_spec sentence symb_items symb_map_items
        sign morphism symbol raw_symbol proof_tree
        => lid -> EndoMap raw_symbol -> ExtSign sign symbol
               -> ExtSign sign symbol -> Result morphism
ext_induced_from_to_morphism l r s@(ExtSign p sy) t = do
    checkExtSign l "from" s
    checkExtSign l "to" t
    checkRawMap l r p
    mor <- induced_from_to_morphism l r s t
    let sysI = Set.toList $ Set.difference (sym_of l p) sy
        morM = symmap_of l mor
        msysI = map (\ sym -> Map.findWithDefault sym sym morM) sysI
    if sysI == msysI then return mor
       else fail $ "imported symbols are mapped differently.\n"
            ++ showDoc (filter (uncurry (/=)) $ zip sysI msysI) ""
