
module DDC.Core.Salt.Lite.Convert.Base
        (  ConvertM(..)
        ,  Error (..))
where
import DDC.Core.Exp
import DDC.Base.Pretty
import DDC.Core.Check                           (AnTEC(..))
import qualified DDC.Type.Check.Monad           as G
import qualified DDC.Core.Salt.Lite.Name        as L


-- | Conversion Monad
type ConvertM a x = G.CheckM (Error a) x


-- | Things that can go wrong during the conversion.
data Error a
        -- | The program is definately not well typed.
        = ErrorMistyped  (Exp (AnTEC a L.Name) L.Name)

        -- | The program wasn't in a-normal form.
        | ErrorNotNormalized

        -- | The program has bottom type annotations.
        | ErrorBotAnnot

        -- | Found unexpected type sum.
        | ErrorUnexpectedSum

        -- | An invalid name used in a binding position
        | ErrorInvalidBinder L.Name

        -- | An invalid name used for the constructor of an alternative.
        | ErrorInvalidAlt


instance Show a => Pretty (Error a) where
 ppr err
  = case err of
        ErrorMistyped xx
         -> vcat [ text "Module is mistyped." <> (text $ show xx) ]

        ErrorNotNormalized
         -> vcat [ text "Module is not in a-normal form."]

        ErrorBotAnnot
         -> vcat [ text "Found bottom type annotation."]

        ErrorUnexpectedSum
         -> vcat [ text "Unexpected type sum."]

        ErrorInvalidBinder n
         -> vcat [ text "Invalid name used in bidner " <> ppr n ]

        ErrorInvalidAlt
         -> vcat [ text "Invalid alternative" ]



