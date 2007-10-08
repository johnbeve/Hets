{- |
Module      :  $Header$
Description :  parser for CASL specification librariess
Copyright   :  (c) Maciek Makowski, Uni Bremen 2002-2006
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt
Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  non-portable(Grothendieck)

Parser for CASL specification librariess
   Follows Sect. II:3.1.5 of the CASL Reference Manual.
-}

module Syntax.Parse_AS_Library (library) where

import Logic.Grothendieck (LogicGraph(currentLogic))
import Logic.Logic (AnyLogic(..), language_name)
import Syntax.AS_Structured
import Syntax.AS_Library
import Syntax.Parse_AS_Structured
    (logicName, groupSpec, aSpec, parseMapping)
import Syntax.Parse_AS_Architecture
import Common.AS_Annotation
import Common.AnnoState
import Common.Keywords
import Common.Lexer
import Common.Token
import Common.Id
import Text.ParserCombinators.Parsec
import Data.List(intersperse)
import Data.Maybe(maybeToList)

-- * Parsing functions

-- | Parse a library of specifications
library :: AnyLogic -> LogicGraph -> AParser st LIB_DEFN
library (Logic lid) lG = do
    (ps, ln) <- option
      (nullRange, Lib_id $ Indirect_link libraryS nullRange "" noTime) $ do
      s1 <- asKey libraryS
      n <- libName
      return (tokPos s1, n)
    an <- annos
    ls <- libItems lG { currentLogic = language_name lid }
    return (Lib_defn ln ls ps an)

-- | Parse library name
libName :: AParser st LIB_NAME
libName = do
    libid <- libId
    v <- option Nothing (fmap Just version)
    return $ case v of
      Nothing -> Lib_id libid
      Just v1 -> Lib_version libid v1

-- | Parse the library version
version :: AParser st VERSION_NUMBER
version = do
    s <- asKey versionS
    pos <- getPos
    n <- many1 digit `sepBy1` (string ".")
    skip
    return (Version_number n (tokPos s `appRange` Range [pos]))

-- | Parse library ID
libId :: AParser st LIB_ID
libId = do
    pos <- getPos
    path <- scanAnyWords `sepBy1` (string "/")
    skip
    return $ Indirect_link (concat (intersperse "/" path)) (Range [pos])
        "" noTime
    -- ??? URL need to be added

-- | Parse the library elements
libItems :: LogicGraph -> AParser st [Annoted LIB_ITEM]
libItems l =
     (eof >> return [])
    <|> do
      r <- libItem l
      la <- lineAnnos
      an <- annos
      is <- libItems $ case r of
             Logic_decl (Logic_name logN _) _ ->
                 l { currentLogic = tokStr logN }
             _ -> l
      case is of
        [] -> return [Annoted r nullRange [] $ la ++ an]
        Annoted i p nl ra : rs ->
          return $ Annoted r nullRange [] la : Annoted i p (an ++ nl) ra : rs

-- | Parse an element of the library
libItem :: LogicGraph -> AParser st LIB_ITEM
libItem l =
     -- spec defn
    do s <- asKey specS
       n <- simpleId
       g <- generics l
       e <- equalT
       a <- aSpec l
       q <- optEnd
       return (Syntax.AS_Library.Spec_defn n g a
               (catPos ([s, e] ++ maybeToList q)))
  <|> -- view defn
    do s1 <- asKey viewS
       vn <- simpleId
       g <- generics l
       s2 <- asKey ":"
       vt <- viewType l
       (symbMap,ps) <- option ([],[])
                        (do s <- equalT
                            (m, _) <- parseMapping l
                            return (m,[s]))
       q <- optEnd
       return (Syntax.AS_Library.View_defn vn g vt symbMap
                    (catPos ([s1, s2] ++ ps ++ maybeToList q)))
  <|> -- unit spec
    do kUnit <- asKey unitS
       kSpec <- asKey specS
       name <- simpleId
       kEqu <- equalT
       usp <- unitSpec l
       kEnd <- optEnd
       return (Syntax.AS_Library.Unit_spec_defn name usp
                (catPos ([kUnit, kSpec, kEqu] ++ maybeToList kEnd)))
  <|> -- ref spec
    do kRef <- asKey refinementS
       name <- simpleId
       kEqu <- equalT
       rsp <- refSpec l
       kEnd <- optEnd
       return (Syntax.AS_Library.Ref_spec_defn name rsp
                   (catPos ([kRef, kEqu] ++ maybeToList kEnd)))
  <|> -- arch spec
    do kArch <- asKey archS
       kSpec <- asKey specS
       name <- simpleId
       kEqu <- equalT
       asp <- annotedArchSpec l
       kEnd <- optEnd
       return (Syntax.AS_Library.Arch_spec_defn name asp
                (catPos ([kArch, kSpec, kEqu] ++ maybeToList kEnd)))
  <|> -- download
    do s1 <- asKey fromS
       iln <- libName
       s2 <- asKey getS
       (il,ps) <- itemNameOrMap `separatedBy` anComma
       q <- optEnd
       return (Download_items iln il
                (catPos ([s1, s2] ++ ps ++ maybeToList q)))
  <|> -- logic
    do s1 <- asKey logicS
       logN@(Logic_name t _) <- logicName
       return (Logic_decl logN (catPos [s1, t]))
  <|> -- just a spec (turned into "spec spec = sp")
     do a <- aSpec l
        return (Syntax.AS_Library.Spec_defn (mkSimpleId specS)
               (Genericity (Params []) (Imported []) nullRange) a nullRange)

-- | Parse view type
viewType :: LogicGraph -> AParser st VIEW_TYPE
viewType l = do
    sp1 <- annoParser (groupSpec l)
    s <- asKey toS
    sp2 <- annoParser (groupSpec l)
    return (View_type sp1 sp2 $ tokPos s)

-- | Parse item name or name map
itemNameOrMap :: AParser st ITEM_NAME_OR_MAP
itemNameOrMap = do
    i1 <- simpleId
    i' <- option Nothing $ do
        s <- asKey "|->"
        i <- simpleId
        return $ Just (i,s)
    return $ case i' of
        Nothing -> Item_name i1
        Just (i2, s) -> Item_name_map i1 i2 $ tokPos s

optEnd :: AParser st (Maybe Token)
optEnd = try
    (addAnnos >> option Nothing (fmap Just $ pToken $ keyWord $ string endS))
    << addLineAnnos

generics :: LogicGraph -> AParser st GENERICITY
generics l = do
    (pa, ps1) <- params l
    (imp, ps2) <- option ([], nullRange) (imports l)
    return $ Genericity (Params pa) (Imported imp) $ appRange ps1 ps2

params :: LogicGraph -> AParser st ([Annoted SPEC],Range)
params l = do
    pas <- many (param l)
    let (pas1, ps) = unzip pas
    return (pas1, concatMapRange id ps)

param :: LogicGraph -> AParser st (Annoted SPEC,Range)
param l = do
    b <- oBracketT
    pa <- aSpec l
    c <- cBracketT
    return (pa, toPos b [] c)

imports :: LogicGraph -> AParser st ([Annoted SPEC], Range)
imports l = do
    s <- asKey givenS
    (sps, ps) <- annoParser (groupSpec l) `separatedBy` anComma
    return (sps, catPos (s:ps))
