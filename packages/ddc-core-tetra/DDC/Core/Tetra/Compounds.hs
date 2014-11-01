
module DDC.Core.Tetra.Compounds
        ( module DDC.Core.Compounds.Annot

          -- * Types
        , tBool
        , tNat
        , tInt
        , tWord
        , tPtr

        , tRef
        , tTupleN
        , tBoxed
        , tUnboxed
        , tFunValue
        , tCloValue

          -- * Expressions
        , xFunCEval
        , xCastConvert)
where
import DDC.Core.Tetra.Prim.TyConTetra
import DDC.Core.Tetra.Prim.TyConPrim
import DDC.Core.Tetra.Prim
import DDC.Core.Compounds.Annot
import DDC.Core.Exp


xFunCEval     
        :: a 
        -> [Type Name]  -- Argument types.
        -> Type Name    -- Result type.
        -> Exp  a Name  -- Functional expression.
        -> [Exp a Name] -- Argument expressions.
        -> Exp a Name

xFunCEval a tsArg tResult xF xsArg
        = xApps a
                (XVar a (UPrim  (NameOpFun (OpFunCEval (length xsArg)))
                                (typeOpFun (OpFunCEval (length xsArg)))))
                (   (map (XType a) tsArg)
                 ++ [XType a tResult]
                 ++ [xF]
                 ++ xsArg)


xCastConvert :: a -> Type Name -> Type Name -> Exp a Name -> Exp a Name 
xCastConvert a tTo tFrom x
        = xApps a
                (XVar a (UPrim (NamePrimCast PrimCastConvert) 
                               (typePrimCast PrimCastConvert)))
                [ XType a tTo
                , XType a tFrom
                , x ]

