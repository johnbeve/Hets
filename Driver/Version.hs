{- |
Module      :  $Header$
Description :  module for the hets version string
Copyright   :  (c) Uni-Bremen, DFKI 2012
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  portable

generated version module of Hets

-}

module Driver.Version where

hetsVersionNumeric :: String
hetsVersionNumeric = "0.108.0"

hetsVersion :: String
hetsVersion =
  "The Heterogeneous Tool Set, version " ++ hetsVersionNumeric
