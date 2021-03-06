
-- | Types of Disciple Core Salt primops.
module DDC.Core.Salt.Env
        ( primDataDefs
        , primKindEnv
        , primTypeEnv
        , typeOfPrimOp
        , typeOfPrimArith
        , typeOfPrimCast
        , typeOfPrimControl
        , typeOfPrimStore
        , typeOfPrimLit
        , typeIsUnboxed)
where
import DDC.Core.Salt.Compounds.PrimArith
import DDC.Core.Salt.Compounds.PrimCast
import DDC.Core.Salt.Compounds.PrimControl
import DDC.Core.Salt.Compounds.PrimStore
import DDC.Core.Salt.Compounds
import DDC.Core.Salt.Name
import DDC.Core.Module.Name
import DDC.Type.DataDef
import DDC.Type.Exp.Simple
import DDC.Type.Env                             (Env)
import qualified DDC.Type.Env                   as Env


-- DataDefs -------------------------------------------------------------------
-- | Data type definitions for:
--
-- >  Type                        Constructors
-- >  ----                --------------------------
-- >  Bool#               True# False#
-- >  Nat#                0# 1# 2# ...
-- >  Int#                ... -2i# -1i# 0i# 1i# 2i# ...
-- >  Size#               0s# 1s# 2s# ...
-- >  Word{8,16,32,64}#   42w8# 123w64# ...
-- >  Float{32,64}#       (none, convert from Int#)
-- >  Tag#                (none, convert from Nat#)
--
primDataDefs :: DataDefs Name
primDataDefs
 = fromListDataDefs
        -- Bool#
        [ makeDataDefAlg mn
                (NamePrimTyCon PrimTyConBool)
                []
                (Just   [ (NamePrimLit (PrimLitBool True),  [])
                        , (NamePrimLit (PrimLitBool False), []) ])
        -- Nat#
        , makeDataDefAlg mn (NamePrimTyCon PrimTyConNat)        [] Nothing

        -- Int#
        , makeDataDefAlg mn (NamePrimTyCon PrimTyConInt)        [] Nothing

        -- Size#
        , makeDataDefAlg mn (NamePrimTyCon PrimTyConSize)       [] Nothing

        -- Word# 8, 16, 32, 64
        , makeDataDefAlg mn (NamePrimTyCon (PrimTyConWord 8))   [] Nothing
        , makeDataDefAlg mn (NamePrimTyCon (PrimTyConWord 16))  [] Nothing
        , makeDataDefAlg mn (NamePrimTyCon (PrimTyConWord 32))  [] Nothing
        , makeDataDefAlg mn (NamePrimTyCon (PrimTyConWord 64))  [] Nothing

        -- Float# 32, 64
        , makeDataDefAlg mn (NamePrimTyCon (PrimTyConFloat 32)) [] Nothing
        , makeDataDefAlg mn (NamePrimTyCon (PrimTyConFloat 64)) [] Nothing

        -- Tag#
        , makeDataDefAlg mn (NamePrimTyCon PrimTyConTag)        [] Nothing

        -- TextLit#
        , makeDataDefAlg mn (NamePrimTyCon PrimTyConTextLit)    [] Nothing

        -- Ptr#
        , makeDataDefAlg mn (NamePrimTyCon PrimTyConPtr)        [] Nothing
        ]
 where  mn = ModuleName [ "DDC", "Types" ]


-- Kinds ----------------------------------------------------------------------
-- | Kind environment containing kinds of primitive data types.
primKindEnv :: Env Name
primKindEnv = Env.setPrimFun kindOfName Env.empty


-- | Take the kind of a name,
--   or `Nothing` if this is not a type name.
kindOfName :: Name -> Maybe (Kind Name)
kindOfName nn
 = case nn of
        NameObjTyCon      -> Just $ kData
        NamePrimTyCon tc  -> Just $ kindOfPrimTyCon tc
        NameVar "rT"      -> Just $ kRegion
        _                 -> Nothing


-- | Take the kind of a primitive name.
--
--   Returns `Nothing` if the name isn't primitive.
--
kindOfPrimTyCon :: PrimTyCon -> Kind Name
kindOfPrimTyCon tc
 = case tc of
        PrimTyConVoid    -> kData
        PrimTyConBool    -> kData
        PrimTyConNat     -> kData
        PrimTyConInt     -> kData
        PrimTyConSize    -> kData
        PrimTyConWord  _ -> kData
        PrimTyConFloat _ -> kData
        PrimTyConAddr    -> kData
        PrimTyConPtr     -> kRegion `kFun` kData `kFun` kData
        PrimTyConTag     -> kData
        PrimTyConVec   _ -> kData `kFun` kData
        PrimTyConTextLit -> kData


-- Types ----------------------------------------------------------------------
-- | Type environment containing types of primitive operators.
primTypeEnv :: Env Name
primTypeEnv = Env.setPrimFun typeOfName Env.empty


-- | Take the type of a name,
--   or `Nothing` if this is not a value name.
typeOfName :: Name -> Maybe (Type Name)
typeOfName nn
 = case nn of
        NamePrimOp p        -> Just $ typeOfPrimOp p
        NamePrimLit lit     -> Just $ typeOfPrimLit lit
        _                   -> Nothing


-- | Take the type of a primitive operator.
typeOfPrimOp :: PrimOp -> Type Name
typeOfPrimOp pp
 = case pp of
        PrimArith    op -> typeOfPrimArith    op
        PrimCast     cc -> typeOfPrimCast     cc
        PrimControl  pc -> typeOfPrimControl  pc
        PrimStore    ps -> typeOfPrimStore    ps


-- | Take the type of a primitive literal.
typeOfPrimLit :: PrimLit -> Type Name
typeOfPrimLit lit
 = case lit of
        PrimLitVoid             -> tVoid
        PrimLitBool    _        -> tBool
        PrimLitNat     _        -> tNat
        PrimLitInt     _        -> tInt
        PrimLitSize    _        -> tSize
        PrimLitWord    _ bits   -> tWord  bits
        PrimLitFloat   _ bits   -> tFloat bits
        PrimLitChar    _        -> tWord  32
        PrimLitTextLit _        -> tTextLit
        PrimLitTag     _        -> tTag


-------------------------------------------------------------------------------
-- | Check if a type is an unboxed data type.
typeIsUnboxed :: Type Name -> Bool
typeIsUnboxed tt
 = case tt of
        TVar{}          -> False

        -- All plain constructors are unboxed.
        -- The others won't be used as parameters, so don't worry.
        TCon _          -> True

        -- Higher kinded types are not values types,
        -- so we'll say they're not unboxed.
        TAbs{}          -> False

        -- Pointers to objects are boxed.
        TApp{}
         | Just (_tR, tTarget)  <- takeTPtr tt
         , tTarget == tObj
         -> False

        TApp t1 t2      -> typeIsUnboxed t1 || typeIsUnboxed t2
        TForall _ t     -> typeIsUnboxed t

        -- Sums should have effect kind, and are thus not value types.
        TSum{}          -> False

        -- Rows should have row kind, and are thus not value types.
        TRow{}          -> False


