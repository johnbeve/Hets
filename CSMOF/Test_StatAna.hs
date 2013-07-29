{- |
Module      :  $Header$
Description :  Test case for CSMOF static analysis
Copyright   :  (c) Daniel Calegari Universidad de la Republica, Uruguay 2013
License     :  GPLv2 or higher, see LICENSE.txt
Maintainer  :  dcalegar@fing.edu.uy
Stability   :  provisional
Portability :  portable
-}

-- From the CSMOF folder run: ghc -i.. -o main Test_StatAna.hs


import CSMOF.As
import CSMOF.Parser
import CSMOF.StatAna
import CSMOF.Sign
import CSMOF.Print

import Common.GlobalAnnotations

import System.IO 
import Text.XML.Light 


main :: IO ()
main = do  
    handle <- openFile "./tests/classExampleCSMOF.xmi" ReadMode  
    contents <- hGetContents handle 
    case parseXMLDoc contents of
	Nothing -> putStr "VACIO"
	Just el -> do
			handle2 <- openFile "./tests/parsingStaticAn_EXIT.txt" WriteMode  
			hPutStr handle2 (show (basicAna ((parseCSMOF el),emptySign,emptyGlobalAnnos)))
			hClose handle2
    hClose handle
