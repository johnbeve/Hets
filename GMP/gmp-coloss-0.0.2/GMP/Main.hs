{- | Module     : $Header$
 -  Description : Implemenation of main file for the prover
 -  Copyright   : (c) Georgel Calin & Lutz Schroeder, DFKI Lab Bremen
 -  License     : Similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt
 -  Maintainer  : g.calin@jacobs-university.de
 -  Stability   : provisional
 -  Portability : portable
 -
 -  Provides the implementation of the user interaction "interface"
 -}
module Main where

import Text.ParserCombinators.Parsec
import System.Environment
import IO

import GMP.Parser
import GMP.Generic

-- | Runs the parser and the prover and prints the result(s) of obtained.
runLex :: (Logic a, Eq a, Show a) => Parser (L a) -> String -> IO ()
runLex p_rL input = run (do spaces
                            x <- p_rL 
                            eof
                            return x
                        ) input

run :: (Logic a, Eq a, Show a) => Parser (L a) -> String -> IO ()
run p_r input = case (parse p_r "" input) of
                  Left err -> do putStr "parse error at "
                                 print err
                  Right x ->  do -- putStrLn ({-show x++" <=> "++-}input)
                                 let isS = sat x
                                 case isS of
                                    True -> putStrLn "... is Satisfiable"
                                    _    -> putStrLn "... is Not Satisfiable"
                                 let isP = provable x
                                 case isP of
                                    True -> putStrLn "... is Provable"
                                    _    -> putStrLn "... is Not Provable"

-- | Auxiliary run function for testing with the file path to input given
runFPtest :: Int -> FilePath -> IO ()
runFPtest ml path = do
    input <- readFile path
    case ml of
     1 -> runLex ((par5er Sqr parseKindex) :: Parser (L K)) input
     2 -> runLex ((par5er Sqr parseKDindex) :: Parser (L KD)) input
     3 -> runLex ((par5er Sqr parseCindex) :: Parser (L C)) input
     4 -> runLex ((par5er Ang parseGindex) :: Parser (L G)) input
     5 -> runLex ((par5er Ang parsePindex) :: Parser (L P)) input
     6 -> runLex ((par5er Sqr parseHMindex) :: Parser (L HM)) input
     7 -> runLex ((par5er Sqr parseMindex) :: Parser (L Mon)) input
     _ -> showHelp
    return ()
-- | Auxiliary run function for testing with the input given as string
runStest :: Int -> String -> IO ()
runStest ml input = do
    case ml of
     1 -> runLex ((par5er Sqr parseKindex) :: Parser (L K)) input
     2 -> runLex ((par5er Sqr parseKDindex) :: Parser (L KD)) input
     3 -> runLex ((par5er Sqr parseCindex) :: Parser (L C)) input
     4 -> runLex ((par5er Ang parseGindex) :: Parser (L G)) input
     5 -> runLex ((par5er Ang parsePindex) :: Parser (L P)) input
     6 -> runLex ((par5er Sqr parseHMindex) :: Parser (L HM)) input
     7 -> runLex ((par5er Sqr parseMindex) :: Parser (L Mon)) input
     _ -> showHelp
    return ()
-- | Function for displying user help 
showHelp :: IO()
showHelp = do
    putStrLn ( "Usage:\n" ++
               "    ./main <ML> -p <path> or ./main <ML> -t <test>\n\n" ++
               "<ML>:    1 for K Modal Logic\n" ++
               "         2 for KD Modal Logic\n" ++
               "         3 for Coalition Logic\n" ++
               "         4 for Graded Modal Logic\n" ++
               "         5 for Probability Logic\n" ++
               "         6 for Hennessy-Milner Modal Logic\n" ++
               "         7 for Monotonic Logic\n" ++
               "<path>:  path to input file\n" ++
               "<test>:  test given as a string\n")
-- | main program function
main :: IO()
main = do
    args <- getArgs
    if (args == [])||(head args == "--help")||(length args < 3)
     then showHelp
     else let ml:it:test:[] = take 3 args
          in case it of
               "-p" -> runFPtest (read ml) test
               "-t" -> runStest (read ml) test
               _    -> showHelp
