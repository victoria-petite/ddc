
-- | Unification of types.

module Type.Util.Unify
	(unifyTypes)
where
import Type.Exp
import Type.Util.Kind

-- | Unify two types, if possible,
--	returning a list of type constriants arising due to the unification.
unifyTypes :: Type -> Type -> Maybe [(Type, Type)]
unifyTypes t1 t2

	-- applications.
	| TApp t11 t12		<- t1
	, TApp t21 t22		<- t2
	, Just subA		<- unifyTypes t11 t21
	, Just subB		<- unifyTypes t12 t22
	= Just (subA ++ subB)

	-- constructors.
	| TCon tc1		<- t1
	, TCon tc2		<- t2
	, tc1 == tc2
	= Just []

	-- special constructors
	| TDanger{}		<- t1
	, TDanger{}		<- t2
	= Just [(t1, t2)]
	
	| TFree{}		<- t1
	, TFree{}		<- t2
	= Just [(t1, t2)]

	-- We need to factor this one out.
	| TEffect{}		<- t1
	, TEffect{}		<- t2
	= Just [(t1, t2)]
	
	-- same variable.
	| TVar k1 v1		<- t1
	, TVar k2 v2		<- t2
	, k1 == k2
	, v1 == v2		
	= Just []
	
	-- variables match anything.
	| TVar k1 v1		<- t1
	, Just k2		<- kindOfType t2
	, k1 == k2	
	= Just [(t1, t2)]
	
	| TVar k2 v2		<- t2
	, Just k1		<- kindOfType t1
	, k1 == k2
	= Just [(t1, t2)]

	-- Summations.
	-- We just return a constraint for these.
	-- Let the caller decide how to handle it.
	| TSum k1 _		<- t1
	, Just k1 == kindOfType t2
	= Just [(t1, t2)]

	| TSum k2 _		<- t2
	, kindOfType t1 == Just k2
	= Just [(t1, t2)]


	| otherwise	
	= Nothing		


