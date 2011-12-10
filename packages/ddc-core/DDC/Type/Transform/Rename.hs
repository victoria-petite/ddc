
module DDC.Type.Transform.Rename
        (Rename(..))
where
import DDC.Type.Exp
import DDC.Type.Sum


class Rename (c :: * -> *) where
 -- | Apply a function to all the names in a thing.
 rename :: forall n1 n2. Ord n2 => (n1 -> n2) -> c n1 -> c n2
 

instance Rename Type where
 rename f tt
  = case tt of
        TVar    u       -> TVar    (rename f u)
        TCon    c       -> TCon    (rename f c)
        TForall b t     -> TForall (rename f b)  (rename f t)
        TApp    t1 t2   -> TApp    (rename f t1) (rename f t2)
        TSum    ts      -> TSum    (rename f ts)


instance Rename TypeSum where
 rename f ts
  = fromList (rename f $ kindOfSum ts) $ map (rename f) $ toList ts


instance Rename Bind where
 rename f bb
  = case bb of
        BName n t       -> BName (f n) (rename f t)
        BAnon   t       -> BAnon (rename f t)
        BNone   t       -> BNone (rename f t)
        

instance Rename Bound where
 rename f uu
  = case uu of
        UIx   i k       -> UIx   i     (rename f k)
        UName n k       -> UName (f n) (rename f k)
        UPrim n k       -> UName (f n) (rename f k)


instance Rename TyCon where
 rename f cc
  = case cc of
        TyConSort sc    -> TyConSort    sc
        TyConKind kc    -> TyConKind    kc
        TyConWitness tc -> TyConWitness tc
        TyConComp tc    -> TyConComp    tc
        TyConBound u    -> TyConBound $ rename f u

