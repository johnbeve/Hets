{- |
Module      :  $Header$
Copyright   :  (c) Francisc-Nicolae Bungiu
License     :  GPLv2 or higher, see LICENSE.txt

Maintainer  :  Christian.Maeder@dfki.de
Stability   :  provisional
Portability :  portable

RDF abstract syntax

References:
    <http://www.informatik.uni-bremen.de/~till/papers/ontotrans.pdf>
    <http://www.w3.org/TR/rdf-concepts/#section-Graph-syntax>
-}

module RDF.AS where

import Common.Id
import OWL2.AS

-- * Graphs

type Subject = IRI
type Predicate = IRI
type Object = Either IRI Literal

getIRIFromObject :: Object -> Maybe IRI
getIRIFromObject obj = case obj of
    Left iri -> Just iri
    _ -> Nothing

-- Axiom represents a RDF Triple
data Axiom = Axiom Subject Predicate Object
    deriving (Show, Eq, Ord)

data RDFGraph = RDFGraph [Axiom]
    deriving (Show, Eq, Ord)

data RDFEntityType = Subject | Predicate | Object
    deriving (Show, Eq, Ord, Bounded, Enum)

-- | entities used for morphisms
data RDFEntity = RDFEntity RDFEntityType IRI
    deriving (Show, Eq, Ord)

rdfEntityTypes :: [RDFEntityType]
rdfEntityTypes = [minBound .. maxBound]

instance GetRange RDFGraph where
instance GetRange Axiom where
instance GetRange RDFEntity where
