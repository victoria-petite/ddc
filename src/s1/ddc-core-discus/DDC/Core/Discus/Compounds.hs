module DDC.Core.Discus.Compounds
        ( module DDC.Core.Exp.Annot

          -- * Primitive
        , tVoid, tBool, tNat, tInt, tSize, tWord, tFloat
        , tAddr, tPtr

          -- * Discus types.
        , tTupleN, tUnboxed, tFunValue, tTextLit

          -- * Expressions
        , xFunReify, xFunApply, xFunCurry
        , xCastConvert

          -- * Info table primitive
        , xInfoFrameNew,        tInfoFrameNew
        , xInfoFramePush,       tInfoFramePush
        , xInfoFrameAddData,    tInfoFrameAddData
        , xInfoFrameAddSuper,   tInfoFrameAddSuper)
where
import DDC.Core.Discus.Prim.TyConDiscus
import DDC.Core.Discus.Prim.TyConPrim
import DDC.Core.Discus.Prim.OpFun
import DDC.Core.Discus.Prim.Base
import DDC.Core.Exp.Annot
import Data.Word


-- Fun --------------------------------------------------------------------------------------------
-- | Reify a super or foreign function into a closure.
xFunReify
        :: a
        -> Type Name    -- ^ Parameter type.
        -> Type Name    -- ^ Result type.
        -> Exp a Name   -- ^ Input closure.
        -> Exp a Name   -- ^ Resulting closure.

xFunReify a tParam tResult xF
 = xApps a
        (XVar a (UName  (NameOpFun OpFunReify)))
        [RType tParam, RType tResult, RTerm xF]


-- | Construct a closure consisting of a top-level super and some arguments.
xFunCurry
        :: a
        -> [Type Name]  -- ^ Parameter types.
        -> Type Name    -- ^ Result type.
        -> Exp a Name   -- ^ Input closure.
        -> Exp a Name   -- ^ Resulting closure.

xFunCurry a tsParam tResult xF
 = xApps a
         (XVar a (UName  (NameOpFun (OpFunCurry (length tsParam)))))
         ((map RType tsParam) ++ [RType tResult] ++ [RTerm xF])



-- | Apply a closure to more arguments.
xFunApply
        :: a
        -> [Type Name]  -- ^ Argument types.
        -> Type Name    -- ^ Result type.
        -> Exp  a Name  -- ^ Functional expression.
        -> [Exp a Name] -- ^ Argument expressions.
        -> Exp a Name

xFunApply a tsArg tResult xF xsArg
 = xApps a
         (XVar a (UName  (NameOpFun (OpFunApply (length xsArg)))))
         ((map RType tsArg) ++ [RType tResult] ++ [RTerm xF] ++ (map RTerm xsArg))


-- Convert ----------------------------------------------------------------------------------------
xCastConvert :: a -> Type Name -> Type Name -> Exp a Name -> Exp a Name
xCastConvert a tTo tFrom xx
 | Just ( NamePrimCast PrimCastConvert _
        , [ RType tTo', RType tFrom', RTerm xxOrig ])
        <- takeXNameApps xx
 , tTo == tFrom', tFrom == tTo'
 = xxOrig

 | otherwise
 = xApps a
        (XVar a (UName (NamePrimCast PrimCastConvert False)))
        [ RType tTo, RType tFrom
        , RTerm xx ]


-- Info -------------------------------------------------------------------------------------------
-- | Allocate a new info table frame with the given number of entries.
--   This function is defined in the runtime system.
xInfoFrameNew :: a -> Int -> Exp a Name
xInfoFrameNew a iCount
 = xApps a
        (XVar a (UName (NameOpInfo OpInfoFrameNew False)))
        [ RTerm $ XCon a (DaConPrim (NameLitNat $ fromIntegral iCount))]


-- | Type of the ddcInfoFrameNew runtime primitive.
tInfoFrameNew :: Type Name
tInfoFrameNew
        = tNat `tFun` tAddr


-- | Push an info table frame onto the stack.
xInfoFramePush :: a -> Exp a Name -> Exp a Name
xInfoFramePush a xFrame
 = xApps a
        (XVar a (UName (NameOpInfo OpInfoFramePush False)))
        [ RTerm xFrame ]


-- | Type of the ddcInfoFramePush runtime primitive.
tInfoFramePush :: Type Name
tInfoFramePush
        = tAddr `tFun` tUnit


-- | Add the name of a data constructor to an info-table frame.
--   This function is defined in the runtime system.
xInfoFrameAddData
        :: a
        -> Exp a Name   -- ^ Frame pointer.
        -> Int          -- ^ Tag of data constructor.
        -> Int          -- ^ Arity of data constructor.
        -> Exp a Name   -- ^ Name of defining module.
        -> Exp a Name   -- ^ Name of data constructor.
        -> Exp a Name

xInfoFrameAddData a xPtr iTag iArity xNameModule xNameData
 = xApps a
        (XVar a (UName (NameOpInfo OpInfoFrameAddData False)))
        [ RTerm xPtr
        , RTerm $ XCon a (DaConPrim (NameLitWord (fromIntegral iTag)   16))
        , RTerm $ XCon a (DaConPrim (NameLitWord (fromIntegral iArity) 16))
        , RTerm xNameModule
        , RTerm xNameData]


-- | Type of the ddcInfoFrameAddData runtime primitive.
tInfoFrameAddData :: Type Name
tInfoFrameAddData
        = tAddr `tFun` tWord 16 `tFun` tWord 16
        `tFun` tTextLit `tFun` tTextLit `tFun` tWord 32


-- | Add the name of a super definition to an info-table frame.
--   This function is defined in the runtime system.
xInfoFrameAddSuper
        :: a
        -> Exp a Name   -- ^ Frame pointer.
        -> Int          -- ^ Number of parameters of super.
        -> Int          -- ^ Number of boxes of super.
        -> Exp a Name   -- ^ Name of defining module.
        -> Exp a Name   -- ^ Name of super.
        -> Word64       -- ^ First word of hash value
        -> Word64       -- ^ ...
        -> Word64       -- ^ ...
        -> Word64       -- ^ ...
        -> Exp a Name

xInfoFrameAddSuper
        a xPtr iParams iBoxes xNameModule xNameSuper
        wHash0 wHash1 wHash2 wHash3
 = xApps a
        (XVar a (UName (NameOpInfo OpInfoFrameAddSuper False)))
        [ RTerm xPtr
        , RTerm $ XCon a (DaConPrim (NameLitWord (fromIntegral iParams) 16))
        , RTerm $ XCon a (DaConPrim (NameLitWord (fromIntegral iBoxes)  16))
        , RTerm xNameModule
        , RTerm xNameSuper
        , RTerm $ xWord a (fromIntegral wHash0) 64
        , RTerm $ xWord a (fromIntegral wHash1) 64
        , RTerm $ xWord a (fromIntegral wHash2) 64
        , RTerm $ xWord a (fromIntegral wHash3) 64 ]

xWord a i bits
 = XCon a (DaConPrim (NameLitWord i bits))


-- | Type of the ddcInfoFrameAddData runtime primitive.
tInfoFrameAddSuper :: Type Name
tInfoFrameAddSuper
        = tAddr `tFun` tWord 16 `tFun` tWord 16
        `tFun` tTextLit `tFun` tTextLit `tFun` tWord 32

