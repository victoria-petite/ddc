
module DDC.Driver.Config
        ( Config        (..)
        
        , ConfigPretty  (..)
        , defaultConfigPretty
        , prettyModeOfConfig
        
        , ViaBackend    (..))
where
import DDC.Build.Builder                        
import DDC.Core.Simplifier              (Simplifier)
import DDC.Core.Pretty
import DDC.Core.Module
import qualified DDC.Core.Salt.Runtime  as Salt
import qualified DDC.Core.Salt          as Salt
import qualified DDC.Core.Lite          as Lite


---------------------------------------------------------------------------------------------------
-- | Configuration for main compiler stages.
data Config
        = Config
        { -- | Dump intermediate code.
          configDump                    :: Bool

          -- | Use bidirectional type inference on the input code.
        , configInferTypes              :: Bool

          -- | Simplifiers to apply to intermediate code
        , configSimplLite               :: Simplifier Int () Lite.Name
        , configSimplSalt               :: Simplifier Int () Salt.Name

          -- | Backend code generator to use
        , configViaBackend              :: ViaBackend

          -- | Runtime system configuration
        , configRuntime                 :: Salt.Config

          -- | The builder to use for the target architecture
        , configBuilder                 :: Builder

          -- | Core langauge pretty printer configuration.
        , configPretty                  :: ConfigPretty

          -- | Suppress the #import prelude in C modules
        , configSuppressHashImports     :: Bool 

          -- | Override output file
        , configOutputFile              :: Maybe FilePath

          -- | Override directory for build products
        , configOutputDir               :: Maybe FilePath

          -- | Keep intermediate .ddc.ll files
        , configKeepLlvmFiles           :: Bool

          -- | Keep intermediate .ddc.c files
        , configKeepSeaFiles            :: Bool

          -- | Keep intermediate .ddc.s files
        , configKeepAsmFiles            :: Bool

          -- | Avoid running the type checker where possible.
          --   When debugging program transformations, use this to get
          --   the invalid code rather than just the type error message.
        , configTaintAvoidTypeChecks    :: Bool
        }


---------------------------------------------------------------------------------------------------
-- | Core language pretty printer configuration.
data ConfigPretty
        = ConfigPretty
        { configPrettyUseLetCase        :: Bool 
        , configPrettyVarTypes          :: Bool
        , configPrettyConTypes          :: Bool
        , configPrettySuppressImports   :: Bool
        , configPrettySuppressExports   :: Bool 
        , configPrettySuppressLetTypes  :: Bool }


-- | Default pretty printer configuration.
defaultConfigPretty :: ConfigPretty
defaultConfigPretty
        = ConfigPretty
        { configPrettyUseLetCase        = False
        , configPrettyVarTypes          = False
        , configPrettyConTypes          = False 
        , configPrettySuppressImports   = False
        , configPrettySuppressExports   = False
        , configPrettySuppressLetTypes  = False }


-- | Convert a the pretty configuration into the mode to use to print a module.
--   We keep the 'ConfigPretty' type separate from PrettyMode because the 
--   former can be non-recursive with other types, and does not need to be
--   parameterised by the annotation or name types.
prettyModeOfConfig
        :: (Eq n, Pretty n) 
        => ConfigPretty -> PrettyMode (Module a n)

prettyModeOfConfig config
 = modeModule
 where
        modeModule      
         = PrettyModeModule
         { modeModuleLets               = modeLets
         , modeModuleSuppressImports    = configPrettySuppressImports config
         , modeModuleSuppressExports    = configPrettySuppressExports config }

        modeExp         
         = PrettyModeExp
         { modeExpLets                  = modeLets
         , modeExpAlt                   = modeAlt
         , modeExpConTypes              = configPrettyConTypes config
         , modeExpVarTypes              = configPrettyVarTypes config
         , modeExpUseLetCase            = configPrettyUseLetCase config }

        modeLets        
         = PrettyModeLets
         { modeLetsExp                  = modeExp 
         , modeLetsSuppressTypes        = configPrettySuppressLetTypes config }

        modeAlt
         = PrettyModeAlt
         { modeAltExp                   = modeExp }
        

---------------------------------------------------------------------------------------------------
data ViaBackend
        -- | Compile via the C backend.
        = ViaC

        -- | Compile via the LLVM backend.
        | ViaLLVM
        deriving Show

