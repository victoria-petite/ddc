
module Type.Base
	( module DDC.Solve.Node
	, Class (..),	classInit
	, Graph (..),	graphInit
	
	, graphSize_init)
where
import Type.Location
import Util
import Data.Array.IO
import DDC.Var
import DDC.Type.Exp
import DDC.Solve.Node
import DDC.Type.Pretty		()
import Data.Sequence		(Seq)
import qualified Data.Map	as Map
import qualified Data.Set	as Set


-- | A Node in the type graph
data Class 
	
	-- | An unallocated class
	= ClassUnallocated						

	-- | Reference to another class.
	--	A Forward is to the resulting class when classes are merged.
	| ClassForward 
		{ classId		:: !ClassId
		, classIdFwd		:: !ClassId }

	-- | Some auxilliary constraint between classes.
	| ClassFetter
		{ classId		:: ClassId
		, classFetter		:: Fetter 
		, classSource		:: TypeSource }

	-- | A deleted fetter
	| ClassFetterDeleted Class

	-- | An equivalence class.
	| Class
		{
		-- | A unique id for this class
		  classId		:: ClassId

		-- | The kind of this class.
		, classKind		:: Kind	
		
		-- | Why this class was allocated. 
		--   This can be used as an overall source of the classTypeSources list is empty.
		, classSource		:: TypeSource			

		-- | A (non-unique) name for this class.
		--	This is taken as one of the vars from the nodes list, or generated fresh if 
		--	none exists. 
		, className		:: Maybe Var

		-- | Whether this class has been quantified
		, classQuant		:: Bool

		-- Type constraints contributing to this class ------------------------------------

		-- | The type of this class (if available).
		--	If any constraints were recently added to this class then this will be Nothing, 
		--	and the unifier will have to work out what type to used based on the
		--	classTypeSources field.
		, classType		:: Maybe Node

		-- | Constraints that have been added to this class, including source information.
		--	If a type error is encountered, then this information can be used to reconstruct
		--	/why/ this particular node has the type it does.
		, classTypeSources	:: [(Node, TypeSource)]	 

		-- | Single parameter type class constraints on this equivalence class.
		--	Maps var on constraint (like Eq) to the source of the constraint.
		--	If a type error is encountered, then this information can be used to reconstruct
		--	/why/ this particular node has the type it does.
		, classFetters		:: Map Var (Seq TypeSource)

		-- | Multi-parameter type class constraints acting on this equivalence class.
		--	MPTC's are stored in their own ClassFetter nodes, and this list points to all
		--	the MPTC's which are constraining this node.
		, classFettersMulti	:: Set ClassId }
		deriving (Show)


classInit cid kind src
	= Class
	{ classId		= cid
	, classKind		= kind
	, classSource		= src
	, className		= Nothing
	, classQuant		= False
	, classType		= Nothing
	, classTypeSources	= []
	, classFetters		= Map.empty
	, classFettersMulti	= Set.empty }
	
		
-- | The Type Graph.
data Graph
	= Graph { 
		-- | The classes
		graphClass		:: IOArray ClassId Class		

		-- | Generator for new ClassIds.
		, graphClassIdGen	:: !Int					

		-- | Type Var -> ClassId Map.
		, graphVarToClassId	:: Map Var ClassId

		-- | The classes which are active, 
		--	ie waiting to be unified or crushed.
		, graphActive		:: Set ClassId }	
					

-- | Initial size of the graph.
graphSize_init	= (1000 :: Int)


graphInit :: IO Graph
graphInit
 = do
	class1		<- newArray 
				(ClassId 0, ClassId graphSize_init) 
				ClassUnallocated
 	return	Graph
		{ graphClass		= class1
		, graphClassIdGen	= 0
		, graphVarToClassId	= Map.empty 
		, graphActive		= Set.empty }
