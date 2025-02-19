{- |
Module      :  $Id$
Description :  generate DriFT directives
Copyright   :  (c) Felix Reckers, C. Maeder, Uni Bremen 2002-2006
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  portable

generate files for DriFT to derive instances (i.e. for ATerms)
-}

module Main (main) where

import System.Console.GetOpt
import System.Environment
import ParseFile

import Control.Monad
import Data.List
import Data.Char
import qualified Data.Set as Set
import qualified Control.Monad.Fail as Fail

data Flag = Rule String | Exclude String | Import String | Output String
            deriving Show

{- previous header files should be replaced by proper imports and
   possibly excluding some data types.
   There may be several -r, -x and -i flags.
-}

options :: [OptDescr Flag]
options = [
           Option "r" ["rule"] (ReqArg Rule "Rule")
                   "the rule for the actual DrIFT derivation",
           Option "x" ["exclude"] (ReqArg Exclude "Data")
            "exclude the specified data-types",
           Option "i" ["import"] (ReqArg Import "Module")
            "additionally import the given file(s)",
           Option "o" ["output-file"] (ReqArg Output "File")
            "specifies the output-directory"
          ]

main :: IO ()
main = do
  args <- getArgs
  case getOpt RequireOrder options args of
    (flags, files, []) ->
      if null files then Fail.fail "missing input file(s)" else genRules flags files
    (_, _, errs) -> Fail.fail $ concat errs ++ usageInfo usage options
       where usage = "Usage: genRules [OPTION...] file [file ...]"

-- | only place imports and data directives into the output module
genRules :: [Flag] -> [FilePath] -> IO ()
genRules flags files =
    do ids <- mapM readParseFile files
       let q@(rules, excs, is, outf) = anaFlags flags
           (datas, imports) = (( \ (x, y) -> (concat x, concat y)) . unzip) ids
           ds = datas \\ excs
           rule = intercalate ", " rules
       checkFlags q
       if null ds then Fail.fail "no data types left" else
           writeFile outf . unlines $
             "{-# OPTIONS -w -O0 #-}"
             : [ "{-# LANGUAGE CPP, StandaloneDeriving, DeriveDataTypeable #-}"
               | elem "Typeable" rules ]
             ++ ["{- |"
             , "Module      :  " ++ outf
             , "Description :  generated " ++ rule ++ " instances"
             , "Copyright   :  (c) DFKI GmbH 2012"
             , "License     :  GPLv2 or higher, see LICENSE.txt"
             , ""
             , "Maintainer  :  Christian.Maeder@dfki.de"
             , "Stability   :  provisional"
             , "Portability :  non-portable(derive Typeable instances)"
             , ""
             , "Automatic derivation of instances via DrIFT-rule " ++ rule
             , "  for the type(s):" ]
             ++ map (\ d -> '\'' : d ++ "'") ds
             ++
             [ "-}"
             , ""
             , "{-"
             , "Generated by 'genRules' (automatic rule generation for DrIFT)."
               ++ " Don't touch!!"
             , "  dependency files:" ]
             ++ files
             ++
             [ "-}"
             , ""
             , "module " ++ toModule outf ++ " () where"
             , "" ]
             ++ map ("import " ++)
                     (Set.toList . Set.fromList $ imports ++ is)
             ++ concatMap (\ r -> "" :
                map (\ d -> "{-! for " ++ d ++ " derive : " ++ r ++ " !-}") ds
                          ) rules

readParseFile :: FilePath -> IO ([String], [Import])
readParseFile fp =
    do inp <- readFile fp
       case parseInputFile fp inp of
         Left err -> Fail.fail $ "parse error at " ++ err
         Right x -> return x

anaFlags :: [Flag] -> ([String], [String], [Import], FilePath)
anaFlags [] = ([], [], [], "")
anaFlags (x : xs) = let
    (rs, ds, is, o) = anaFlags xs in case x of
    Rule r -> (r : rs, ds, is, o)
    Exclude d -> (rs, d : ds, is, o)
    Import i -> (rs, ds, i : is, o)
    Output outFile -> (rs, ds, is, outFile)

checkFlags :: ([String], [String], [Import], FilePath) -> IO ()
checkFlags (rs, ds, is, o) = do
  let wrong s = null s || not (isUpper $ head s)
      frs = filter wrong rs
      fds = filter wrong ds
      fis = filter wrong is
  unless (null frs) . Fail.fail $ "wrong rule to apply: " ++ head frs
  when (wrong o) . Fail.fail $ "no module output file given. " ++ o
  unless (null fds) . Fail.fail $ "wrong data type to exclude: " ++ head fds
  unless (null fis) . Fail.fail $ "wrong module to import: " ++ head fis

toModule :: FilePath -> String
toModule = map (\ c -> if c == '/' then '.' else c) . takeWhile (/= '.')
