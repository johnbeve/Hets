-------------------------------------------------------------------------------
-- GMP
-- Copyright 2007, Lutz Schroeder and Georgel Calin
-------------------------------------------------------------------------------
module Main where 

import Text.ParserCombinators.Parsec
import System.Environment
import IO

import GMP.GMPAS
import GMP.GMPSAT
import GMP.GMPParser
import GMP.ModalLogic
import GMP.ModalK()
import GMP.ModalKD()
import GMP.GradedML()
import GMP.CoalitionL()
import GMP.MajorityL()
import GMP.GenericML()
import GMP.Lexer

--import qualified Data.Set as Set
-------------------------------------------------------------------------------
-- Funtion to run parser & print
-------------------------------------------------------------------------------
runLex :: (Ord a, Show a, ModalLogic a b) => Parser (Formula a) -> String -> IO ()
runLex p input = run (do
    whiteSpace
    ; x <- p
    ; eof
    ; return x
    ) input

run :: (Ord a, Show a, ModalLogic a b) => Parser (Formula a) -> String -> IO ()
run p input
        = case (parse p "" input) of
                Left err -> do putStr "parse error at "
                               ;print err
                Right x ->  do {-print "PV list:"
                               let ls = guessPV x ---------------------------
                               print ls{-
                               let h = if ((not.null) ls) then head(ls)------
                                                          else Set.empty-----
                               print h ------------ FOR TESTING -------------}
                               let lro = map roFromPV ls --------------------
                               print "Rho val from the above PV:"
                               print lro ------------------------------------}
                               print "the Formula:"
                               print x
                               let sat = checkSAT x
                               if sat then print "is Satisfiable"
                                      else print "is not Satisfiable"
-------------------------------------------------------------------------------
-- For Testing 
-------------------------------------------------------------------------------
runTest :: Int -> FilePath -> IO ()
runTest ml p = do
    input <- readFile (p)
    case ml of
     1 -> runLex ((par5er parseIndex) :: Parser (Formula ModalK)) input
     2 -> runLex ((par5er parseIndex) :: Parser (Formula ModalKD)) input
     3 -> runLex ((par5er parseIndex) :: Parser (Formula CL)) input
     4 -> runLex ((par5er parseIndex) :: Parser (Formula GML)) input
     5 -> runLex ((par5er parseIndex) :: Parser (Formula ML)) input
     _ -> runLex ((par5er parseIndex) :: Parser (Formula Kars)) input
    return ()
help :: IO()
help = do
    putStrLn ( "Usage:\n" ++
               "    ./main <ML> <path>\n\n" ++
               "<ML>:    1 for K ML\n" ++
               "         2 for KD ML\n" ++
               "         3 for Coalition L\n" ++
               "         4 for Graded ML\n" ++
               "         5 for Majority L\n" ++
               "         _ for Generic ML\n" ++
               "<path>:  path to input file\n" )
-------------------------------------------------------------------------------
main :: IO()
main = do
    args <- getArgs
    if (args == [])||(head args == "--help")||(length args < 2)
     then help
     else let ml = head args
              p = head (tail args)
          in runTest (read ml) p
