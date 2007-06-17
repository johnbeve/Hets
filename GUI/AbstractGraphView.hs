{- |
Module      :  $Header$
Description :  Interface for graph viewing and abstraction
Copyright   :  (c) Jorina Freya Gerken, Till Mossakowski, Uni Bremen 2002-2006
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  ken@tzi.de
Stability   :  provisional
Portability :  non-portable (relies on Logic via DevGraph)

Interface for graph viewing and abstraction.
   It is possible to hide sets of nodes and edges.
   Using a composition table for edge types,
   paths through hidden nodes can be displayed.
   Graphs, nodes, and edges are handled via
   descriptors (here: integers), while node and
   edge types are handled by user-supplied strings.
-}

module GUI.AbstractGraphView
    ( OurGraph
    , initgraphs
    , Result(Result)
    , makegraph
    , redisplay
    , get_graphid
    , Descr
    , GraphInfo
    , RelationViewSpec(RelViewSpec)
    , writeRelViewSpecs
    , AbstractionGraph(theGraph, edges,
                       ontoGraph, nodeMap, nodes, relViewSpecs)
    , NodeMapping
    , writeNodeMap
    , addnode
    , addlink
    , delnode
    , dellink
    , EdgeValue
    , writeOntoGraph
    , showIt
    , CompTable
    , hidenodes
    , changeNodeType
    , checkHasHiddenNodes
    , hideSetOfNodeTypes
    ) where

-- All:
import DaVinciGraph
import GraphDisp
import GraphConfigure
import Data.List(nub)
import Data.IORef

-- tax:
import Computation
import Taxonomy.MMiSSOntology
import qualified Data.Graph.Inductive.Graph as Graph
import Common.Lib.Graph as Tree
import qualified Data.Map as Map

-- gui:
import Static.DevGraph (DGLinkLab)
import Data.Graph.Inductive.Graph (LEdge)
import ATC.DevGraph()

{- methods using fetch_graph return a quadruple containing the
modified graph, a descriptor of the last modification (e.g. a new
node), the descriptor that can be used for the next modification and a
possible error message -}

-- Which graph display tool to be used, perhaps make it more tool independent?

instance Eq (DaVinciNode (String,Int,Int)) where
    (==) = eq1

instance Eq (DaVinciArc EdgeValue) where
    (==) = eq1

graphtool :: Graph DaVinciGraph
   DaVinciGraphParms DaVinciNode DaVinciNodeType DaVinciNodeTypeParms
   DaVinciArc DaVinciArcType DaVinciArcTypeParms
graphtool = daVinciSort

type OurGraph =
     Graph   DaVinciGraph
             DaVinciGraphParms
             DaVinciNode
             DaVinciNodeType
             DaVinciNodeTypeParms
             DaVinciArc
             DaVinciArcType
             DaVinciArcTypeParms

-- Main datastructure for carrying around the graph,
-- both internally (nodes as integers), and at the daVinci level

type CompTable = [(String,String,String)]
data AbstractionGraph = AbstractionGraph {
       theGraph :: OurGraph,
       nodeTypes :: [(String,DaVinciNodeType (String,Int,Int))],
       edgeTypes :: [(String,DaVinciArcType EdgeValue)],
       nodes :: [(Int,(String,DaVinciNode (String,Int,Int)))],
       edges :: [(Int,(Int,Int,String,DaVinciArc EdgeValue))],
       {- probably, also the abstracted graph needs to be stored,
       and a list of hide/abstract events with the hidden nodes/edges (for
       each event), which is used to restore things when showIt is called -}
       edgeComp :: CompTable,
       eventTable :: [(Int,Entry)],
       deletedNodes :: [Int],
       ontoGraph :: Tree.Gr (String,String,OntoObjectType) String,
       relViewSpecs :: [RelationViewSpec],
       nodeMap :: NodeMapping}

type NodeMapping = Map.Map Int Descr
type Descr = Int
type EdgeValue = (String,Int,Maybe (LEdge DGLinkLab))
type GraphInfo = IORef ([(Descr,AbstractionGraph)],Descr)
                       -- for each graph the descriptor and the graph,
                       -- plus a global counter for new descriptors
data Result = Result Descr          -- graph, node or edge descriptor
                     (Maybe String) -- a possible error message


data Entry = Entry {newNodes :: [(Descr,(String,
                                         DaVinciNode (String,Int,Int)))],
                    oldNodes :: [(Descr,(String,String))],
                    newEdges :: [(Int,(Int,Int,String,DaVinciArc EdgeValue))],
                    oldEdges :: [(Int,(Int,Int,String,EdgeValue))]
                    }

data RelationViewSpec = RelViewSpec String Bool Bool

{- creates a new entry of the eventTable and fills it with the data contained
   in its parameters -}
createEntry :: [(Descr,(String,DaVinciNode (String,Int,Int)))]
            -> [(Descr,(String,String))]
            -> [(Descr,(Int,Int,String,DaVinciArc EdgeValue))]
            -> [(Descr,(Int,Int,String,EdgeValue))] -> Descr -> (Int,Entry)
createEntry nn on ne oe cnt =
  (cnt, Entry {newNodes = nn, oldNodes = on, newEdges = ne, oldEdges = oe})

{- zips two lists by pairing each element of the first with each element of
   the second -}
specialzip :: [a] -> [b] -> [(a,b)]
specialzip xs ys = [ (x, y) | x <- xs, y <- ys ] 

{- similar to lookup, but also returns the decriptor
   should only be used, if lookup will be successful (otherwise an error is
   thrown) -}
get :: Descr -> [(Descr,a)] -> (Descr,a)
get d list =
  case lookup d list of
    Just r -> (d,r)
    Nothing -> error ("get: descriptor unknown: "++(show d)++"\n"
                      ++(show (map fst list)))

remove :: Eq a => a -> [(a,b)] -> [(a,b)]
remove x l = filter (\(y,_) -> not (x==y)) l

{- lookup a graph descriptor and execute a command on the graph
   the delete flag specifies if the graph should be removed from the graph
   list afterwards -}
fetch_graph :: Descr -> GraphInfo -> Bool -> ((AbstractionGraph, Descr)
            -> IO (AbstractionGraph, Descr, Descr, Maybe String)) -> IO Result
fetch_graph gid gv delete cmd = do
  (gs,ev_cnt) <- readIORef gv
  case lookup gid gs of
    Just g -> do
      (g',descr,ev_cnt',err) <- cmd (g,ev_cnt)
      let gs'' = if delete then gs' else (gid,g'):gs'
      writeIORef gv (gs'',ev_cnt')
      return (Result descr err)
      where gs' = remove gid gs
    Nothing -> return (Result 0 (Just ("Graph id "++show gid++" not found")))

get_graphid :: Descr -> GraphInfo -> IO OurGraph
get_graphid gid gv = do
  (gs,_) <- readIORef gv
  case lookup gid gs of
    Just g -> return $ theGraph g
    Nothing -> error "get_graphid: graph does not exist"

-- These are the operations of the interface

initgraphs :: IO GraphInfo
initgraphs = do newRef <- newIORef ([],0)
                return newRef

makegraph :: String -> Maybe (IO ()) -> Maybe (IO ()) -> Maybe (IO ())
          -> [GlobalMenu]
          -> [(String,DaVinciNodeTypeParms (String,Descr,Descr))]
          -> [(String,DaVinciArcTypeParms EdgeValue)] -> CompTable
          -> GraphInfo -> IO Result
makegraph
  title open save saveAs menus nodetypeparams edgetypeparams comptable gv = do
  (gs,ev_cnt) <- readIORef gv
  let
    graphParms  =
      foldr ($$) (GraphTitle title $$
                  OptimiseLayout True $$
                  AllowClose (return True) $$
                  FileMenuAct OpenMenuOption open $$
                  FileMenuAct SaveMenuOption save $$
                  FileMenuAct SaveAsMenuOption saveAs $$
                  emptyGraphParms)
                  menus
    abstractNodetypeparams =
      LocalMenu (
        Button "Unhide abstracted nodes"
          (\(_, descr, gid) -> do
             oldGv <- readIORef gv
             (Result _ error') <- showIt gid descr gv
             case error' of
               Just _ -> do
                 writeIORef gv oldGv
                 return ()
               Nothing -> do
                 redisplay gid gv
                 return ()
          )
        ) $$$
        Rhombus  $$$
        ValueTitle ( \ (name,_,_) -> return name) $$$
        emptyNodeTypeParms :: DaVinciNodeTypeParms (String,Int,Int)
    (nodetypenames,nodetypeparams1) =
      unzip (("ABSTRACT",abstractNodetypeparams):nodetypeparams)
    (edgetypenames,edgetypeparams1) = unzip edgetypeparams
  graph <- GraphDisp.newGraph graphtool graphParms
  ontoGr <- return(Graph.empty)
  relViewSpecList <- return([])
  nodetypes <- sequence (map (newNodeType graph) nodetypeparams1)
  edgetypes <- sequence (map (newArcType graph) edgetypeparams1)
  let g = AbstractionGraph {
            theGraph = graph,
            nodeTypes = zip nodetypenames nodetypes,
            edgeTypes = zip edgetypenames edgetypes,
            nodes = [],
            edges = [],
            edgeComp = comptable,
            eventTable = [],
            deletedNodes = [],
            ontoGraph = ontoGr,
            relViewSpecs = relViewSpecList,
            nodeMap = Map.empty }
  writeIORef gv ((ev_cnt,g):gs,ev_cnt+1)
  return (Result ev_cnt Nothing)

addnode :: Descr -> String -> String -> GraphInfo -> IO Result
addnode gid nodetype name gv =
  fetch_graph gid gv False (\(g,ev_cnt) -> do
------------------------------ why query nodetype first
    case lookup nodetype (nodeTypes g) of
      Nothing ->
        return (g,0,ev_cnt,Just ("addnode: illegal node type: "++nodetype))
      Just nt -> do
            node <- newNode (theGraph g) nt (name,ev_cnt,gid)
            return (g{nodes = (ev_cnt,(nodetype,node)):nodes g},
                    ev_cnt,ev_cnt+1,Nothing)
    )

changeNodeType :: Descr -> Descr -> String -> GraphInfo -> IO Result
changeNodeType gid node nodetype graph =
  fetch_graph gid graph False (\(g, ev_cnt) ->
    case lookup node (nodes g) of
      Nothing ->
        return (g, 0, ev_cnt, Just ("changeNodeType: illegal node: "
                                    ++ show node))
      Just n ->
        case lookup nodetype (nodeTypes g) of
          Nothing ->
            return (g, 0, ev_cnt,
                    Just ("changeNodeType: illegal node type: " ++ nodetype))
          Just nt -> do
            setNodeType (theGraph g) (snd n) nt
            let newnodes =
                   map (\x@(descr, (_, davinciNode)) -> if descr == node
                     then (descr, (nodetype, davinciNode)) else x) $ nodes g
            return (g{nodes = newnodes}, node, ev_cnt+1, Nothing)
    )

writeOntoGraph :: Descr -> Tree.Gr (String,String,OntoObjectType) String
               -> GraphInfo -> IO Result
writeOntoGraph gid graph gv =
  fetch_graph gid gv False (\(g,ev_cnt) ->
    return (g{ontoGraph = graph},0,ev_cnt+1,Nothing)
    )

writeRelViewSpecs :: Descr -> [RelationViewSpec] -> GraphInfo -> IO Result
writeRelViewSpecs gid specs gv =
  fetch_graph gid gv False (\(g,ev_cnt) ->
    return (g{relViewSpecs = specs},0,ev_cnt+1,Nothing)
    )

writeNodeMap :: Descr -> NodeMapping -> GraphInfo -> IO Result
writeNodeMap gid nMap gv =
  fetch_graph gid gv False (\(g,ev_cnt) ->
    return (g{nodeMap = nMap},0,ev_cnt+1,Nothing)
    )

delnode :: Descr -> Descr -> GraphInfo -> IO Result
delnode gid node gv =
  fetch_graph gid gv False (\(g,ev_cnt) ->
    case lookup node (nodes g) of
      Just n -> do
        deleteNode (theGraph g) (snd n)
        return (g{nodes = remove node (nodes g),deletedNodes = deletedNodes g},
                0,ev_cnt+1,Nothing)
      Nothing ->
        return (g,0,ev_cnt,Just ("delnode: illegal node: "++show node))
    )

addlink :: Descr -> String -> String -> Maybe (LEdge DGLinkLab) -> Descr
        -> Descr -> GraphInfo -> IO Result
addlink gid edgetype name label src tar gv =
  fetch_graph gid gv False (\(g,ev_cnt) ->
    case (lookup edgetype (edgeTypes g),
          lookup src (nodes g),
          lookup tar (nodes g)) of
      (Just et, Just src_node, Just tar_node) -> do
        existingEdgesOfSameTypeAndPosition <-
          sequence [(getArcValue (theGraph g) davinciArc)
                    |(_,(srcId, tgtId, tp, davinciArc)) <- (edges g),
                    tp == edgetype && srcId == src && tgtId == tar]
        case lookup name [(nm,descr)|(nm,descr,_) <-
          existingEdgesOfSameTypeAndPosition] of
           _ -> do
             edge <- newArc (theGraph g) et (name,ev_cnt,label) (snd src_node)
                       (snd tar_node)
             return (g{edges = (ev_cnt,(src,tar,edgetype,edge)):edges g},
                     ev_cnt,ev_cnt+1,Nothing)
      (Nothing,_,_) ->
        return (g,0,ev_cnt,Just ("addlink: illegal edge type: "++edgetype))
      (_,Nothing,_) ->
        return (g,0,ev_cnt,
                Just ("addlink: illegal source node id: "++show src))
      (_,_,Nothing) ->
        return (g,0,ev_cnt,
                Just ("addlink: illegal target node id: "++show tar))
    )

dellink :: Descr -> Descr -> GraphInfo -> IO Result
dellink gid edge gv =
  fetch_graph gid gv False (\(g,ev_cnt) ->
    case lookup edge (edges g) of
      Just (_,_,_,e) -> do
        deleteArc (theGraph g) e
        return (g{edges = remove edge (edges g)},0,ev_cnt+1,Nothing)
      Nothing ->
        return (g,0,ev_cnt,Just ("dellink: illegal edge: "++show edge))
    )

redisplay :: Descr -> GraphInfo -> IO Result
redisplay gid gv =
  fetch_graph gid gv False (\(g,ev_cnt) -> do
    redraw (theGraph g)
    return (g,0,ev_cnt+1,Nothing)
    )

{- determines from the types of two edges the type of the path replacing them
   (using the edgeComp table of the graph) -}
determineedgetype :: AbstractionGraph -> (String,String) -> Maybe String
determineedgetype g (t1,t2) =
  case result of
    [] -> Nothing
    x:_ -> Just x
  where result = [ t | (tp1,tp2,t) <- (edgeComp g), (tp1==t1)&&(tp2==t2)]

{- returns a pair of lists: one list of all in- and one of all out-going edges
   of the node -}
fetchEdgesOfNode :: AbstractionGraph -> Descr -> Maybe ([Descr],[Descr])
fetchEdgesOfNode g node =
  case sequence (map ((flip lookup) (edges g)) (map fst (edges g))) of
    Just _ ->
      Just ([descr|(descr,(_,t,_,_)) <- (edges g), t == node],
            [descr|(descr,(s,_,_,_)) <- (edges g), s == node])
    Nothing -> Nothing

hidenodes :: Descr -> [Descr] -> GraphInfo -> IO Result
hidenodes gid node_list gv =
  fetch_graph gid gv False (\(g,ev_cnt) ->
    case sequence (map (\node -> lookup node (nodes g)) node_list) of
      Just _ -> do
        -- try to determine the path to add and the edges to remove
        case makepathsMain g node_list of
          -- try to create the paths
          Just (newEdges',delEdges) -> do
            -- save the old edges...
            let
              oeDescr = nub ((concat (map fst delEdges))++
                             (concat (map snd delEdges)))
              oe = map (\ed -> get ed (edges g)) oeDescr
            oldEdges' <- saveOldEdges g oe
            -- ... then try to remove them from the graph
            (gs,_) <- readIORef gv
            writeIORef gv (gs,ev_cnt+1)
            (Result _ error1) <- hideedgesaux gid oeDescr gv
            info1 <- readIORef gv
            case error1 of
              Nothing -> do
                -- determine the _new_ edges...
                let
                  existingEdges =
                    [(src,tgt,tp)|(_,(src,tgt,tp,_)) <-
                     (edges (snd (get gid (fst info1))))]
                  filteredNewEdges =
                    [path| path@(src,tgt,tp) <- newEdges',
                     notElem (src,tgt,tp) existingEdges]
                -- ... and try to add them
                (Result _ error2) <-
                  addpaths gid filteredNewEdges gv --info1
                case error2 of
                  Nothing -> do
                    -- save the old nodes...
                    let on = map (\nd -> get nd (nodes g)) node_list
                    oldNodes' <- saveOldNodes g on
                    -- ... then try to remove them from the graph
                    (Result _ error3) <-
                      hidenodesaux gid node_list gv --info2
                    info3 <- readIORef gv
                    case error3 of
                      Nothing -> do
                        -- save the changes in an entry
                        let
                          g' = snd (get gid (fst info3))
                          newEdges'' = [edge| edge <- (edges g'),
                                       notElem edge (edges g)]
                          newEvent = createEntry [] oldNodes' newEdges''
                                       oldEdges' ev_cnt
                        return (g'{eventTable = newEvent:eventTable g'},ev_cnt,
                                (snd info3)+1,Nothing)
                      Just t ->
                        return (g,0,ev_cnt,
                                Just ("hidenodes: error hiding nodes: "++t))
                  Just text ->
                    return (g,0,ev_cnt,
                            Just ("hidenodes: error adding paths: "++text))
              Just text ->
                return (g,0,ev_cnt,
                        Just ("hidenodes: error deleting edges: "++text))
          Nothing ->
            return (g,0,ev_cnt,
                    Just ("hidenodes: error making paths\n(possible reasons: "
                         ++"an error occured getting the edges of the nodes\n "
                         ++"or a pathtype could not be determined (missing "
                         ++"entry in edgeComp table))"))
      Nothing -> return (g,0,ev_cnt,Just "hidenodes: unknown node(s)")
    )

-- auxiliary function, which removes the nodes from the graph
hidenodesaux :: Descr -> [Descr] -> GraphInfo -> IO Result
hidenodesaux _ [] gv = do
  (_,ev_cnt) <- readIORef gv
  return (Result ev_cnt Nothing)
hidenodesaux gid (d:delNodes) gv = do
  deletedNode@(Result _ error') <- delnode gid d gv
  case error' of
    Nothing -> do hidenodesaux gid delNodes gv
    Just _ -> return deletedNode

-- returns the paths to add and the edges to remove
makepathsMain :: AbstractionGraph -> [Descr]
              -> Maybe ([(Descr,Descr,String)],[([Descr],[Descr])])
makepathsMain g node_list =
  -- try to determine the in- and outgoing edges of the nodes
  case sequence (map (fetchEdgesOfNode g) node_list) of
    -- try to make paths of these edges
    Just edgelistPairs ->
      case sequence (map (makepaths g node_list) edgelistPairs) of
        -- the paths to add (dangling ones are removed) and the edges to remove
        Just paths ->
          Just (removeDanglingEdges (nub (concat paths)) node_list,
                edgelistPairs)
        Nothing -> Nothing
    Nothing -> Nothing

-- removes those edges whose source or target node will be hidden
removeDanglingEdges :: [(Descr,Descr,String)] -> [Descr]
                    -> [(Descr,Descr,String)]
removeDanglingEdges edges' nodes' =
  [edge| edge@(src,tgt,_) <- edges', notElem src nodes' && notElem tgt nodes']

-- returns a list of paths (ie source, target and type) to be added
makepaths :: AbstractionGraph ->  [Descr] -> ([Descr],[Descr])
          -> Maybe [(Descr,Descr,String)]
makepaths g node_list (inEdges,outEdges) =
  -- try to lookup the edges of the node
  case (sequence (map (\ed -> lookup ed (edges g)) inEdges),
        sequence (map (\ed -> lookup ed (edges g)) outEdges)) of
    (Just ie, Just oe) ->
      -- try to make paths out of them
      case sequence (map (makepathsaux g node_list []) (specialzip ie oe)) of
        -- return the paths
        Just paths -> Just (concat paths)
        Nothing -> Nothing
    (Nothing,_) -> Nothing
    (_,Nothing) -> Nothing

{- determines source, target and type of the path to be added and checks it
   using method checkpath -}
makepathsaux :: AbstractionGraph -> [Descr] -> [Descr]
             -> ((Descr,Descr,String,DaVinciArc EdgeValue),
                (Descr,Descr,String,DaVinciArc EdgeValue))
             -> Maybe [(Descr,Descr,String)]
makepathsaux g node_list alreadyPassedNodes ((s1,_,ty1,ed1),(_,t2,ty2,_)) =
  -- try to determine the type of the path
  case determineedgetype g (ty1,ty2) of
    -- return the checked path
    Just ty -> checkpath g node_list alreadyPassedNodes (s1,t2,ty,ed1)
               -- ed1 is just a dummy value (Dummiewert)
    Nothing -> Nothing

{- check, if the source or the target of an edge are element of the list of
   nodes that are to be hidden
   if so, find out the "next" sources/targets and check again
   remember which nodes have been passed to avoid infinite loops -}
checkpath :: AbstractionGraph -> [Descr] -> [Descr]
          -> (Descr,Descr,String,DaVinciArc EdgeValue)
          -> Maybe [(Descr,Descr,String)]
checkpath g node_list alreadyPassedNodes path@(src,tgt,ty,_)
  | elem src alreadyPassedNodes || elem tgt alreadyPassedNodes = Just []
  | elem src node_list =
    -- try to determine the in- and outgoing edges of the source node
    case fetchEdgesOfNode g src of
      -- try to lookup ingoing edges
      Just (inEdges,_) ->
        case sequence (map (\ed' -> lookup ed' (edges g)) inEdges) of
          {- try to make paths of these edges and the "tail" of the path (and
             recursively check them) -}
          Just el ->
            case sequence
              (map (makepathsaux g node_list (src:alreadyPassedNodes))
              (specialzip el [path])) of
              Just p -> Just (concat p)
              Nothing -> Nothing
          Nothing -> Nothing
      Nothing -> Nothing
  | elem tgt node_list =
    -- try to determine the in- and outgoing edges of the target node
    case fetchEdgesOfNode g tgt of
      -- try to lookup the outgoing edges
      Just (_,outEdges) ->
        case sequence (map (\ed' -> lookup ed' (edges g)) outEdges) of
          {- try to make paths of these edges and the "init" of the path (and
             recursively check them) -}
          Just el ->
            case sequence (map (makepathsaux g node_list
                                 (tgt:alreadyPassedNodes))
                          (specialzip [path] el)) of
              Just p -> Just (concat p)
              Nothing -> Nothing
          Nothing -> Nothing
      Nothing -> Nothing
  | otherwise =
    -- nothing to be done
    Just [(src,tgt,ty)]

-- adds the paths (given source, target and type)
addpaths :: Descr -> [(Descr,Descr,String)] -> GraphInfo -> IO Result
addpaths _ [] gv = do
  (_,ev_cnt) <- readIORef gv
  return (Result ev_cnt Nothing)
addpaths gid ((src,tgt,ty):newEdges') gv = do
  edge@(Result _ error') <- addlink gid ty "" Nothing src tgt gv
  case error' of
    Nothing -> do addpaths gid newEdges' gv
    Just _ -> return edge

hideSetOfNodeTypes :: Descr -> [String] -> Bool -> GraphInfo -> IO Result
hideSetOfNodeTypes gid nodetypes showLast gv =
  fetch_graph gid gv False (\(g,ev_cnt) ->
    case sequence [lookup nodetype (nodeTypes g)|nodetype <- nodetypes] of
      Just _ -> do
        let nodelist = [descr|(descr,(tp,_)) <- (nodes g),
                        elem tp nodetypes && (not showLast || (any 
                          (\(_,(descr',_,_,_)) -> descr' == descr) $ edges g))]
        case nodelist of
          [] ->
            return (g,0,ev_cnt,
                    Just ("hidenodetype: no nodes of types "
                          ++(showList nodetypes ",")++" found in graph "
                          ++(show gid)))
          _ -> do
            (Result de error') <- hidenodes gid nodelist gv
            info <- readIORef gv
            return (snd (get gid (fst info)), de, (snd info), error')
      Nothing ->
        return (g,0,ev_cnt,Just ("hidenodetype: illegal node types "
                                 ++"in list: "++(showList nodetypes ",")))
    )

-- an auxiliary function, which removes the edges from the graph
hideedgesaux :: Descr -> [Descr] -> GraphInfo -> IO Result
hideedgesaux _ [] gv = do
  (_,ev_cnt) <- readIORef gv
  return (Result ev_cnt Nothing)
hideedgesaux gid (d:delEdges) gv = do
  dle@(Result _ error') <- dellink gid d gv
  case error' of
    Nothing -> do hideedgesaux gid delEdges gv --info
    Just _ -> return dle

-- | function to check whether the internal nodes are hidden or not
checkHasHiddenNodes :: Descr -> Descr -> GraphInfo -> IO Result
checkHasHiddenNodes gid hide_event gv =
  fetch_graph gid gv False (\(g, ev_cnt) ->
    case lookup hide_event (eventTable g) of
      Just _ -> return (g, 0, ev_cnt, Nothing)
      Nothing -> return (g, 0, ev_cnt,
                         Just "checkHasHiddenNodes: hide events not found")
    )

-- function to undo hide-events
showIt :: Descr -> Descr -> GraphInfo -> IO Result
showIt gid hide_event gv =
  fetch_graph gid gv False (\(g,ev_cnt) ->
    -- try to lookup the hide-event
    case lookup hide_event (eventTable g) of
      Just entry -> do
        -- try to remove the paths that had been added
        (Result _ error1) <- hideedgesaux gid (map fst (newEdges entry)) gv
        case error1 of
          Nothing -> do
            -- try to add the nodes that had been hidden
            (Result _ error2) <- shownodes gid (oldNodes entry) gv
            case error2 of
              Nothing -> do
                -- try to remove the nodes that had been added
                (Result _ error3) <- hidenodesaux gid
                                         (map fst (newNodes entry)) gv
                case error3 of
                  Nothing -> do
                    -- try to add the edges that had been hidden
                    (Result _ error4) <- showedges gid (oldEdges entry) gv
                    info4 <- readIORef gv
                    case error4 of
                      Nothing -> do
                        -- remove the event from the eventTable
                        let g' = snd (get gid (fst info4))
                        return (g'{eventTable = remove hide_event
                                (eventTable g')},0,ev_cnt+1,Nothing)
                      Just t4 ->
                        return (g,0,ev_cnt,Just ("showIt: error restoring old "
                                                 ++"edges:\n-> "++t4))
                  Just t3 ->
                    return (g,0,ev_cnt,
                            Just ("showIt: error removing nodes:\n-> "++t3))
              Just t2 ->
                return (g,0,ev_cnt,Just ("showIt: error restoring nodes:\n-> "
                                         ++t2))
          Just t1 ->
            return (g,0,ev_cnt,Just ("showIt: error removing edges:\n-> "++t1))
      Nothing ->
        return (g,0,ev_cnt,Just ("showIt: invalid event descriptor: "
                                 ++(show hide_event)))
    )

-- adds nodes that had been hidden
shownodes :: Descr -> [(Descr,(String,String))] -> GraphInfo -> IO Result
shownodes _ [] gv = do
  (_,ev_cnt) <- readIORef gv
  return (Result ev_cnt Nothing)
shownodes gid ((d,(tp,name)):list) gv = do
  (gs,_) <- readIORef gv
  -- try to add the first node
  writeIORef gv (gs,d)
  nd@(Result _ error') <- addnode gid tp name gv
  case error' of
    Nothing -> do
      -- try to add the rest
      shownodes gid list gv
    Just _ -> return nd

-- adds edges that had been hidden
showedges :: Descr -> [(Int,(Int,Int,String,EdgeValue))] -> GraphInfo
          -> IO Result
showedges _ [] gv = do
  (_,ev_cnt) <- readIORef gv
  return (Result ev_cnt Nothing)
showedges gid ((d,(src,tgt,tp,value)):list) gv = do
  (gs,_) <- readIORef gv
  -- try to add the first edge
  writeIORef gv (gs,d)
  let
    name = getEdgeName value
    label = getEdgeLabel value
  ed@(Result _ err) <- addlink gid tp name label src tgt gv
  case err of
    Nothing -> do
      -- try to add the rest
      showedges gid list gv
    Just _ -> return ed

{- | creates a list of the nodes that will be hidden (ie descriptor,type and
   name) -}
saveOldNodes :: AbstractionGraph
             -> [(Int,(String,DaVinciNode(String,Int,Int)))]
             -> IO [(Int,(String,String))]
saveOldNodes _ [] = return []
saveOldNodes g ((de,(tp,davincinode)):list) = do
  (name,_,_) <- getNodeValue (theGraph g) davincinode
  restOfList <- saveOldNodes g list
  return ((de,(tp,name)):restOfList)

{- | creates a list of the edges that will be hidden (ie descriptor,source,
   target,type and name) -}
saveOldEdges :: AbstractionGraph
             -> [(Int,(Int,Int,String,DaVinciArc EdgeValue))]
             -> IO [(Int,(Int,Int,String,EdgeValue))]
saveOldEdges _ [] = return []
saveOldEdges g ((de,(src,tgt,tp,davinciarc)):list) = do
  value <- getArcValue (theGraph g) davinciarc
  restOfList <- saveOldEdges g list
  return ((de,(src,tgt,tp,value)):restOfList)

getEdgeName :: EdgeValue -> String
getEdgeName (name,_,_) = name

getEdgeLabel :: EdgeValue -> Maybe (LEdge DGLinkLab)
getEdgeLabel (_,_,label) = label
