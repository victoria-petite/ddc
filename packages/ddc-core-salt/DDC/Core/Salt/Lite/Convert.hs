
-- | Conversion of Disciple Lite to Disciple Salt.
--
module DDC.Core.Salt.Lite.Convert
        ( toSalt
        , Error(..))
where
import DDC.Core.Salt.Platform
import DDC.Core.Module
import DDC.Core.Exp
import DDC.Type.Compounds
import DDC.Type.Universe
import DDC.Type.DataDef
import DDC.Base.Pretty
import DDC.Type.Check.Monad                     (throw, result)
import qualified DDC.Type.Check.Monad           as G
import qualified DDC.Core.Salt.Lite.Layout      as L
import qualified DDC.Core.Salt.Lite.Name        as L
import qualified DDC.Core.Salt.Output.Runtime   as O
import qualified DDC.Core.Salt.Output.Name      as O
import qualified DDC.Core.Salt.Output.Env       as O
import qualified Data.Map                       as Map
import Control.Monad


-- | Convert a Disciple Lite module to Disciple Salt.
--
--   Case expressions on alrebraic data values are converted into ones that just
--   check the tag, while data constructors are unfolded into explicit allocation
--   and field initialization primops. 
--
--   TODO: Add the alternatives that force and follow lazy thunks and indirections.
--   TODO: Expand partial and over-applications into code that explicitly builds
--         and applies thunks.
--
--   The input module needs to be well typed, and have all functions defined at
--   top-level, and be a-normalised. If not then `Error`.
--
--   The output code contains debruijn indices which need to be eliminateed before
--   it will pass the Salt fragment checks.
--
toSalt
        :: Show a 
        => Platform
        -> DataDefs L.Name
        -> Module a L.Name 
        -> Either (Error a) (Module a O.Name)
toSalt pp defs mm
 = result $ convertM pp defs mm

-- | Conversion Monad
type ConvertM a x = G.CheckM (Error a) x


-- | Things that can go wrong during the conversion.
data Error a
        -- | The program is definately not well typed.
        = ErrorMistyped 

        -- | The program wasn't in a-normal form.
        | ErrorNotNormalized

        -- | An invalid name used in a binding position
        | ErrorInvalidBinder L.Name

        -- | An invalid name used for the constructor of an alternative.
        | ErrorInvalidAlt
        deriving Show


instance Pretty (Error a) where
 ppr err
  = case err of
        ErrorMistyped
         -> vcat [ text "Module is mistyped."]

        ErrorNotNormalized
         -> vcat [ text "Module is not in a-normal form."]

        ErrorInvalidBinder n
         -> vcat [ text "Invalid name used in bidner " <> ppr n ]

        ErrorInvalidAlt
         -> vcat [ text "Invalid alternative" ]


-- Module ---------------------------------------------------------------------
convertM 
        :: Platform
        -> DataDefs L.Name 
        -> Module a L.Name 
        -> ConvertM a (Module a O.Name)

convertM pp defsPrim mm
  = do  let defs = defsPrim
        x'       <- convertBodyX pp defs $ moduleBody mm

        return $ ModuleCore
         { moduleName           = moduleName mm
         , moduleExportKinds    = Map.empty
         , moduleExportTypes    = Map.empty
         , moduleImportKinds    = Map.empty
         , moduleImportTypes    = O.runtimeImportSigs 
         , moduleBody           = x' }


-- Exp -------------------------------------------------------------------------
convertBodyX 
        :: Platform
        -> DataDefs L.Name 
        -> Exp a L.Name -> ConvertM a (Exp a O.Name)

convertBodyX pp defs xx
 = case xx of
        XVar a u
         -> do  u'      <- convertU u
                let xx' =  XVar a u'
                t'      <- convertT $ typeOfBound u
                return  $  O.xReturn a t' xx'

        XCon a u
         -> do  (xx', t') <- convertC defs a u
                return  $  O.xReturn a t' xx'

        -- Strip out type lambdas.
        XLAM _ _ x
         -> convertBodyX pp defs x

        -- Keep value binders but ditch witness binders for now.
        XLam a b x
         -> case universeFromType1 (typeOfBind b) of
             Just UniverseData    -> liftM3 XLam (return a) (convertB b) (convertBodyX pp defs x)
             Just UniverseWitness -> convertBodyX pp defs x
             _                    -> throw ErrorMistyped

        XApp{}  -> error "toBrineX: XApp"

        XLet a (LRec bxs) x2
         -> do  let (bs, xs)    = unzip bxs
                bs'             <- mapM convertB bs
                xs'             <- mapM (convertBodyX pp defs) xs
                x2'             <- convertBodyX pp defs x2
                return $ XLet a (LRec $ zip bs' xs') x2'

        XLet{}          -> error "toBrineX: XLet"

        -- TODO: add default alternative to check for other tags
        --       if there isn't one already.
        XCase a x@(XVar _ uX) alts  
         -> do  x'              <- convertArgX pp defs x
                alts'           <- mapM (convertA pp defs a uX) alts
                return  $ XCase a (XApp a (O.xGetTag a) x') alts'

        XCase{}         -> throw $ ErrorNotNormalized

        XCast _ _ x     -> convertBodyX pp defs x

        XType{}         -> throw $ ErrorMistyped
        XWitness{}      -> throw $ ErrorMistyped



-- | Convert a function argument.
convertArgX
        :: Platform
        -> DataDefs L.Name
        -> Exp a L.Name
        -> ConvertM a (Exp a O.Name)

convertArgX pp defs xx
  = case xx of
        XVar a u        -> liftM2 XVar (return a) (convertU u)
        XCon a u        -> liftM fst $ convertC defs a u
        XApp{}          -> error "toBrineX: XApp"
        XCast _ _ x     -> convertArgX pp defs x

        -- Lambdas, should have been split out to top-level bindintg.
        XLAM{}          -> throw ErrorNotNormalized
        XLam{}          -> throw ErrorNotNormalized

        -- Lets and cases should 
        XLet{}          -> throw ErrorNotNormalized
        XCase{}         -> throw ErrorNotNormalized 

        -- Types and witness arguments should have been discarded already.
        XType{}         -> throw ErrorMistyped
        XWitness{}      -> throw ErrorMistyped


-- Alt ------------------------------------------------------------------------
convertA 
        :: Platform
        -> DataDefs L.Name 
        -> a
        -> Bound L.Name -> Alt a L.Name 
        -> ConvertM a (Alt a O.Name)

convertA pp defs a uScrut alt
 = case alt of
        AAlt PDefault x
         -> do  x'      <- convertBodyX pp defs x
                return  $ AAlt PDefault x'


        AAlt (PData uCtor bsFields) x
         | Just nCtor    <- case uCtor of
                                UName n _ -> Just n
                                UPrim n _ -> Just n
                                _         -> Nothing
         , Just ctorDef   <- Map.lookup nCtor $ dataDefsCtors defs
         -> do  
                uScrut'         <- convertU uScrut

                -- Get the tag of this alternative.
                let iTag        = fromIntegral $ dataCtorTag ctorDef
                let uTag        = UPrim (O.NameTag iTag) O.tTag

                -- Get the address of the payload.
                bsFields'       <- mapM convertB bsFields

                -- TODO: lift body
                xBody1          <- convertBodyX pp defs x

                -- Let bindings to unpack the constructor
                xBody2          <- bindCtorFields pp a uScrut' ctorDef bsFields' xBody1

                return  $ AAlt (PData uTag []) xBody2


        AAlt{}          -> throw ErrorInvalidAlt


-- | Wrap an body expression let-binding which bind the fields of a 
--   data constructor.
bindCtorFields 
        :: Platform 
        -> a
        -> Bound O.Name         -- ^ Bound of Scruitinee.
        -> DataCtor L.Name      -- ^ Definition of the data constructor to unpack
        -> [Bind O.Name]        -- ^ Binders for each of the fields.
        -> Exp a O.Name         -- ^ Body expression that uses the field binders.
        -> ConvertM a (Exp a O.Name)

bindCtorFields pp a uScrut ctorDef bsFields xBody

 | Just L.HeapObjectBoxed    <- L.heapObjectOfDataCtor ctorDef
 = do   
        -- Bind pattern variables to each of the fields.
        let lsFields    = [ LLet LetStrict bField 
                                (O.xFieldOfBoxed a (XVar a uScrut) ix)
                                | bField        <- bsFields
                                | ix            <- [0..] ]

        return  $ foldr (XLet a) xBody lsFields

 | Just L.HeapObjectRawSmall <- L.heapObjectOfDataCtor ctorDef
 , Just offsets              <- L.fieldOffsetsOfDataCtor pp ctorDef
 = do   
        -- Get the address of the payload.
        let bPayload    = BAnon O.tAddr
        let xPayload    = O.xPayloadOfRawSmall a (XVar a uScrut)

        -- Bind pattern variables to the fields.
        let uPayload    = UIx 0 O.tAddr
        let lsFields    = [ LLet LetStrict bField 
                                (O.xRead a tField (XVar a uPayload) offset) 
                                | bField        <- bsFields
                                | tField        <- map typeOfBind bsFields
                                | offset        <- offsets ]

        -- TODO: lift body expression
        return  $ foldr (XLet a) xBody
                $ LLet LetStrict bPayload xPayload
                : lsFields


 | otherwise
 = throw ErrorInvalidAlt


-- Data Constructor -----------------------------------------------------------
convertC :: DataDefs L.Name
         -> a -> Bound L.Name -> ConvertM a (Exp a O.Name, Type O.Name)
convertC _defs a uu
 = case uu of
        UPrim (L.NameInt i bits) _   
          -> return ( XCon a (UPrim (O.NameInt i bits) (O.tInt bits))
                    , O.tInt bits)

        -- TODO: expand out code to construct algebraic data.
        _ -> error "convertC"


-- Type -----------------------------------------------------------------------
convertT :: Type L.Name -> ConvertM a (Type O.Name)
convertT tt
  = case tt of
        -- Convert type variables an constructors.
        TVar u          -> liftM TVar (convertU u)
        TCon tc         -> convertTyCon tc

        -- Strip off foralls, as the Brine fragment doesn't care about quantifiers.
        TForall _ t     -> convertT t

        TApp{}  
         -- Strip off effect and closure information.
         |  Just (t1, _, _, t2)  <- takeTFun tt
         -> liftM2 tFunPE (convertT t1) (convertT t2)

         -- Boxed data values are represented in generic form.
         | otherwise
         -> return $ O.tPtr O.tObj

        -- We shouldn't find any TSums, as they should be thrown away by
        -- toBrineType above. We also don't call this converter on witness types.
        TSum{}          -> throw ErrorMistyped


-- | Convert a simple type constructor to a Brine type.
convertTyCon :: TyCon L.Name -> ConvertM a (Type O.Name)
convertTyCon tc
 = case tc of
        -- Higher universe constructors are passed through unharmed.
        TyConSort    c           -> return $ TCon $ TyConSort    c 
        TyConKind    c           -> return $ TCon $ TyConKind    c 
        TyConWitness c           -> return $ TCon $ TyConWitness c 
        TyConSpec    c           -> return $ TCon $ TyConSpec    c 

        -- Convert primitive TyCons to Brine form.
        TyConBound   (UPrim n _) -> convertTyConPrim n

        -- Boxed data values are represented in generic form.
        TyConBound   _           -> return $ O.tPtr O.tObj


-- | Convert a primitive type constructor to Brine form.
convertTyConPrim :: L.Name -> ConvertM a (Type O.Name)
convertTyConPrim n
 = case n of
        L.NamePrimTyCon pc      
          -> return $ TCon $ TyConBound (UPrim (O.NamePrimTyCon pc) kData)
        _ -> throw ErrorMistyped


-- Names ----------------------------------------------------------------------
convertB :: Bind L.Name -> ConvertM a (Bind O.Name)
convertB bb
  = case bb of
        BNone t         -> liftM  BNone (convertT t)        
        BAnon t         -> liftM  BAnon (convertT t)
        BName n t       -> liftM2 BName (convertBindNameM n) (convertT t)


convertU :: Bound L.Name -> ConvertM a (Bound O.Name)
convertU uu
  = case uu of
        UIx i t         -> liftM2 UIx   (return i) (convertT t)
        UName n t       -> liftM2 UName (convertBoundNameM n) (convertT t)
        UPrim n t       -> liftM2 UPrim (convertBoundNameM n) (convertT t)
        UHole   t       -> liftM  UHole (convertT t)


convertBindNameM :: L.Name -> ConvertM a O.Name
convertBindNameM nn
 = case nn of
        L.NameVar str   -> return $ O.NameVar str
        _               -> throw $ ErrorInvalidBinder nn


convertBoundNameM :: L.Name -> ConvertM a O.Name
convertBoundNameM nn
 = case nn of
        L.NameVar str   -> return $ O.NameVar str
        _               -> error "convertBoundName"
