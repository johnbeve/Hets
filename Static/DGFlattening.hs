{- |
Module      :  $Header$
Description :  Central datastructures for development graphs
Copyright   :  (c) Igor Stassiy, DFKI Bremen 2008
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt
Maintainer  :  i.stassiy@jacobs-university.de
Stability   :  provisional
Portability :  non-portable(Logic)


In this module we introduce flattening of the graph:
Flattening from level 1 to 0 - deleting all inclusion links, and inserting a new node, with new computed theory (computeTheory).

Flattening from level 4 to 1 - deterimining renaming link, inserting a new node with the renaming morphism applied to theory of a                                 source, deleting the link and setting a new inclusion link between a new node and the target node.

In this module we introduce flattening of the graph. All the edges in the
graph are cut out and theories of a node with theories of all the incoming
nodes are merged into a theory of a new node and then inserted in the graph.
While the old nodes are deleted.
-}

module Static.DGFlattening (--libEnv_flattening,
                            dg_flattening1,
                            libEnv_flattening1,
                            dg_flattening4,
                            libEnv_flattening4,
                            dg_flattening5,
                            libEnv_flattening5
                            ) where	
import Logic.Grothendieck
import Logic.Logic()
import Comorphisms.LogicGraph
import Static.DevGraph
import Static.GTheory
import Static.DevGraph
import Proofs.EdgeUtils
import Proofs.TheoremHideShift
import Syntax.AS_Library
import Common.Result
import Data.Graph.Inductive.Graph
import Data.Map
import qualified Data.Map as Map
import Control.Monad

dg_flattening1 :: LibEnv -> LIB_NAME -> Result DGraph
dg_flattening1 libEnv ln = do
       let
                dg = lookupDGraph ln libEnv
                nds =  nodesDG dg
                l_nodes = labNodesDG dg
                l_edges = labEdgesDG dg
                change_de =  Prelude.map (\ x -> DeleteEdge(x)) l_edges
                change_dn =  Prelude.map (\ x -> DeleteNode(x)) l_nodes
       change_an <- mapM (liftM InsertNode . updateNodeT libEnv ln) nds
       let
                rule_n = Prelude.map ( const FlatteningOne ) nds
                rule_e = Prelude.map ( const FlatteningOne ) l_edges
                hist = [(rule_n ++ rule_n ++ rule_e
                        , change_de ++ change_dn ++ change_an)]
                -- part for dealing with the graph itself
       return $ applyProofHistory hist  dg
       where
           delLEdgesDG :: [LEdge DGLinkLab] -> DGraph -> DGraph
           delLEdgesDG ed dg = case ed of
             [] -> dg
             hd : tl -> delLEdgesDG tl ( delLEdgeDG hd dg )

           updateNodeT :: LibEnv -> LIB_NAME -> Node -> Result (LNode DGNodeLab) 
           updateNodeT lib_Env l_n n =
                  let
                    g = lookupDGraph l_n lib_Env
                    nodeLab = labDG g n
                  in 
                   do 
                    (_,ndgn_theory) <- computeTheory lib_Env l_n n
                    return   (n,
                              newInfoNodeLab (dgn_name nodeLab) (nodeInfo nodeLab) (ndgn_theory))

libEnv_flattening1 :: LibEnv -> Result LibEnv
libEnv_flattening1 lib = do
        new_lib_env <- mapM (\ (x,_) -> do
                         z <- dg_flattening1 lib x
                         return (x, z)) $ Map.toList lib
        return $ Map.fromList new_lib_env

dg_flattening4 :: LibEnv -> LIB_NAME -> DGraph
dg_flattening4 lib_Env l_n =
  let
   dg = lookupDGraph l_n lib_Env
   l_edges = labEdgesDG dg
   renamings = Prelude.filter (\ (_,_,x) -> let
                                    l_type = getRealDGLinkType x
                                  in
                                    case l_type of
                                     GlobalDefNoInc -> True
                                     _ -> False ) l_edges
   (fin_dg,ruls, chngs) = applyUpdDG renamings [] [] dg
  in
   setProofHistoryDG [(ruls,chngs)] fin_dg
   --case isDGRef nodelab of
    where  updateWithDG :: (LEdge DGLinkLab) -> DGraph -> (DGraph,[DGChange])
           updateWithDG l_edg@( v1, v2, label) d_graph =
            let
             --update node
             lv1 = labDG d_graph v1 
             name = dgn_name lv1
             n_node = getNewNodeDG d_graph
             n_lnode = (do
                      n_dgn_theory <- translateG_theory (dgl_morphism label) (dgn_theory lv1)
                      return (n_node, (newInfoNodeLab (name) (newNodeInfo DGFlattening)  n_dgn_theory) ) )
             nlv1 = (do
                      ( _, n_dgn_theory ) <- computeTheory lib_Env l_n v2
                      return $ lv1 {dgn_theory = n_dgn_theory } )
             nl_dg = fst $ labelNodeDG (v1,propagateErrors nlv1) d_graph
             --update edge
             sign_source = signOf . dgn_theory . snd $ propagateErrors n_lnode 
             sign_target = signOf . dgn_theory $ labDG d_graph v2
             n_edg = (do
                       ng_morphism <- ginclusion logicGraph sign_source sign_target
                       return (n_node, v2, label { dgl_morphism = ng_morphism,
                                                   dgl_type = LocalDef ,
                                                   dgl_origin = DGLinkFlatteningFour,
                                                   dgl_id = defaultEdgeId }) )
             change_dg = [DeleteEdge(l_edg),
                          InsertNode(propagateErrors  n_lnode),
                          InsertEdge(propagateErrors n_edg)
                         ]
            in
             updateDGAndChanges nl_dg change_dg

           applyUpdDG :: [LEdge DGLinkLab] -> [DGRule] -> [DGChange] -> DGraph -> (DGraph,[DGRule],[DGChange])
           applyUpdDG l_list rl_l ch_l d_g = case l_list of
             [] -> (d_g, rl_l, ch_l)
             hd:tl -> let 
                        (dev_g,changes) = updateWithDG hd d_g
                        rules = replicate 3 FlatteningFour
                      in
                        applyUpdDG tl (rl_l ++ rules) (ch_l ++ changes) dev_g

libEnv_flattening4 :: LibEnv -> Result LibEnv
libEnv_flattening4 libEnvi =
       let
        new_lib_env = Prelude.map (\ (x,_) -> 
                        let
                         z = dg_flattening4 libEnvi x
                        in
                         (x, z)) $ Map.toList libEnvi
       in
        return $ Map.fromList new_lib_env


dg_flattening5 :: LibEnv -> LIB_NAME -> DGraph
dg_flattening5 lib_Envir lib_name = 
  let 
   dg = lookupDGraph lib_name lib_Envir
   nods = nodesDG dg
   l_edges = labEdgesDG dg
   hidings = Prelude.filter (\ (_,_,x) -> let
                                    l_type = getRealDGLinkType x
                                  in
                                    case l_type of
                                     HidingDefNoInc -> True
                                     _ -> False ) l_edges
   --history
   edg_rules = Prelude.map (\ _ -> FlatteningFour ) l_edges
   edg_changes = Prelude.map (\ x -> DeleteEdge(x)) l_edges
   edg_hist = [(edg_rules,edg_changes)]
   upd_dg = applyUpdNf lib_Envir lib_name dg nods
  in
   (applyProofHistory edg_hist upd_dg)
     where 
      applyUpdNf :: LibEnv -> LIB_NAME -> DGraph -> [Node] -> DGraph
      applyUpdNf lib_Envi lib_Name dg l_nodes =
             case l_nodes of
              [] ->  dg
              hd:tl -> let
                        new_Lib = propagateErrors $ convertToNf lib_Name lib_Envi hd
                       in
                        applyUpdNf new_Lib lib_Name dg tl

libEnv_flattening5 :: LibEnv -> Result LibEnv
libEnv_flattening5 libEnvi =
       let
        new_lib_env = Prelude.map (\ (x,_) -> 
                        let
                         z = dg_flattening5 libEnvi x
                        in
                         (x, z)) $ Map.toList libEnvi
       in
        return $ Map.fromList new_lib_env