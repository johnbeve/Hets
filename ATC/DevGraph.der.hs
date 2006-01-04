{-# OPTIONS -fno-strictness #-}
{- |
Module      :  $Header$
Description :  ShATermConvertible instances
Copyright   :  (c) C. Maeder, Uni Bremen 2005-2006
License     :  similar to LGPL, see HetCATS/LICENSE.txt

Maintainer  :  maeder@tzi.de
Stability   :  provisional
Portability :  portable

derive 'ShATermConvertible' instance
  for the type(s): 'DGNodeLab' 'DGLinkLab' 'DGRule' 'BasicConsProof' 'ThmLinkStatus' 'DGLinkType' 'Conservativity' 'DGOrigin' 'NodeSig' 'MaybeNode' 'UnitSig' 'ImpUnitSigOrSig' 'ArchSig' 'GlobalEntry' 'DGChange'

instances for 'BasicProof' and 'G_theory' need to be given explicitely
-}

module ATC.DevGraph where

import Static.DevGraph
import Logic.Logic
import Common.ATerm.Lib
import Common.DynamicUtils
import ATC.AS_Library()
import ATC.Prover()
import ATC.Grothendieck

{-! for DGNodeLab derive : ShATermConvertible !-}
{-! for DGLinkLab derive : ShATermConvertible !-}
{-! for DGRule derive : ShATermConvertible !-}
{-! for BasicConsProof derive : ShATermConvertible !-}
{-! for ThmLinkStatus derive : ShATermConvertible !-}
{-! for DGLinkType derive : ShATermConvertible !-}
{-! for Conservativity derive : ShATermConvertible !-}
{-! for DGOrigin derive : ShATermConvertible !-}
{-! for NodeSig derive : ShATermConvertible !-}
{-! for MaybeNode derive : ShATermConvertible !-}
{-! for UnitSig derive : ShATermConvertible !-}
{-! for ImpUnitSigOrSig derive : ShATermConvertible !-}
{-! for ArchSig derive : ShATermConvertible !-}
{-! for GlobalEntry derive : ShATermConvertible !-}
{-! for DGChange derive : ShATermConvertible !-}

{-! for DGNodeLab derive : Typeable !-}
{-! for DGLinkLab derive : Typeable !-}
{-! for DGRule derive : Typeable !-}
{-! for BasicConsProof derive : Typeable !-}
{-! for ThmLinkStatus derive : Typeable !-}
{-! for DGLinkType derive : Typeable !-}
{-! for Conservativity derive : Typeable !-}
{-! for DGOrigin derive : Typeable !-}
{-! for NodeSig derive : Typeable !-}
{-! for MaybeNode derive : Typeable !-}
{-! for UnitSig derive : Typeable !-}
{-! for ImpUnitSigOrSig derive : Typeable !-}
{-! for ArchSig derive : Typeable !-}
{-! for GlobalEntry derive : Typeable !-}
{-! for DGChange derive : Typeable !-}

_tc_G_theoryTc :: TyCon
_tc_G_theoryTc = mkTyCon "G_theory"
instance Typeable G_theory where
    typeOf _ = mkTyConApp _tc_G_theoryTc []

instance ShATermConvertible BasicProof where
    toShATerm att0 (BasicProof lid p) =
         case toShATerm att0 (language_name lid) of { (att1,i1) ->
         case toShATerm att1 p of { (att2,i2) ->
            addATerm (ShAAppl "BasicProof" [i1,i2] []) att2}}
    toShATerm att0 Guessed =
         case toShATerm att0 (show Guessed) of { (att1, i1) ->
            addATerm (ShAAppl "BasicProof" [i1] []) att1}
    toShATerm att0 Conjectured =
         case toShATerm att0 (show Conjectured) of { (att1, i1) ->
            addATerm (ShAAppl "BasicProof" [i1] []) att1}
    toShATerm att0 Handwritten =
         case toShATerm att0 (show Handwritten) of { (att1, i1) ->
            addATerm (ShAAppl "BasicProof" [i1] []) att1}
    fromShATermAux ix att =
         case getShATerm ix att of
            ShAAppl "BasicProof" [i1,i2] _ ->
                case fromShATerm' i1 att of { (att1, i1') ->
                case atcLogicLookup "BasicProof" i1' of { Logic lid ->
                case fromShATerm' i2 att1 of { (att2, i2') ->
                (att2, BasicProof lid i2') }}}
            v@(ShAAppl "BasicProof" [i1] _) ->
               case fromShATerm' i1 att of { (att1, i1') ->
               (att1, case i1' of
                 "Guessed" -> Guessed
                 "Conjectured" -> Conjectured
                 "Handwritten" -> Handwritten
                 _ -> fromShATermError "BasicProof" v)}
            u -> fromShATermError "BasicProof" u

instance ShATermConvertible G_theory where
    toShATerm att0 (G_theory lid sign sens) =
         case toShATerm att0 (language_name lid) of { (att1,i1) ->
         case toShATerm att1 sign of { (att2,i2) ->
         case toShATerm att2 sens of { (att3,i3) ->
           addATerm (ShAAppl "G_theory" [i1,i2,i3] []) att3}}}
    fromShATermAux ix att =
         case getShATerm ix att of
            ShAAppl "G_theory" [i1,i2,i3] _ ->
                case fromShATerm' i1 att of { (att1, i1') ->
                case atcLogicLookup "G_theory" i1' of { Logic lid ->
                case fromShATerm' i2 att1 of { (att2, i2') ->
                case fromShATerm' i3 att2 of { (att3, i3') ->
                (att3, G_theory lid i2' i3') }}}}
            u -> fromShATermError "G_theory" u
