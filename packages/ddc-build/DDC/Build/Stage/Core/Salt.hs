
module DDC.Build.Stage.Core.Salt
        ( saltToSea 
        , saltToLlvm)
where
import Control.Monad.Trans.Except
import Control.Monad.IO.Class

import DDC.Data.Pretty

import qualified DDC.Build.Pipeline.Error               as B
import qualified DDC.Build.Pipeline.Sink                as B
import qualified DDC.Build.Stage.Core                   as BC
import qualified DDC.Build.Language.Salt                as BA

import qualified DDC.Core.Module                        as C
import qualified DDC.Core.Check                         as C
import qualified DDC.Core.Simplifier.Recipe             as C
import qualified DDC.Core.Transform.Namify              as CNamify
import qualified DDC.Core.Transform.Reannotate          as CReannotate

import qualified DDC.Core.Salt                          as A
import qualified DDC.Core.Salt.Platform                 as A
import qualified DDC.Core.Salt.Transfer                 as ATransfer
import qualified DDC.Core.Salt.Transform.Slotify        as ASlotify
import qualified DDC.Core.Llvm.Convert                  as ALlvm

import qualified DDC.Llvm.Syntax                        as L


---------------------------------------------------------------------------------------------------
-- | Convert Salt code to sea.
saltToSea
        :: (Show a, Pretty a)
        => String               -- ^ Name of source module, for error messages.
        -> A.Platform           -- ^ Platform to produce code for.
        -> C.Module a A.Name    -- ^ Core Salt module.
        -> ExceptT [B.Error] IO String

saltToSea srcName platform mm
 = do
        -- Normalize code in preparation for conversion.
        mm_simpl
         <- BC.coreSimplify
                BA.fragment (0 :: Int) 
                (C.anormalize (CNamify.makeNamifier A.freshT)
                              (CNamify.makeNamifier A.freshX))
                mm

        -- Check normalized to produce type annotations on every node.
        mm_checked
         <- BC.coreCheck
                srcName BA.fragment C.Recon
                B.SinkDiscard B.SinkDiscard mm_simpl

        -- Insert control transfer primops.
        mm_transfer
         <- case ATransfer.transferModule mm_checked of
                Left err        -> throwE [B.ErrorSaltConvert err]
                Right mm'       -> return mm'

        -- Convert to Sea source code.
        case A.seaOfSaltModule True platform mm_transfer of
         Left  err -> throwE [B.ErrorSaltConvert err]
         Right str -> return (renderIndent str)


---------------------------------------------------------------------------------------------------
-- | Convert Salt code to Shadow Stack Slotted LLVM.
saltToLlvm
        :: (Show a, Pretty a)
        => String               -- ^ Name of source module, for error messages.
        -> A.Platform           -- ^ Platform to produce code for.
        -> Bool                 -- ^ Whether to introduce stack slots.
        -> B.Sink               -- ^ Sink after prep simplification.
        -> B.Sink               -- ^ Sink after introducing stack slots.
        -> B.Sink               -- ^ Sink after transfer transform.
        -> C.Module a A.Name    -- ^ Core Salt module.
        -> ExceptT [B.Error] IO L.Module

saltToLlvm 
        srcName platform bAddSlots
        sinkPrep sinkSlots sinkTransfer 
        mm
 = do   
        -- Normalize code in preparation for conversion.
        mm_simpl
         <- BC.coreSimplify
                BA.fragment (0 :: Int)
                (C.anormalize (CNamify.makeNamifier A.freshT)
                              (CNamify.makeNamifier A.freshX))
                mm


        -- Check normalized code to produce type annotations on every node.
        mm_checked
         <- BC.coreCheck
                srcName BA.fragment C.Recon
                B.SinkDiscard B.SinkDiscard mm_simpl

        liftIO $ B.pipeSink (renderIndent $ ppr mm_simpl) sinkPrep


        -- Insert shadow stack slot management instructions,
        --  if we were asked for them.
        mm_slotify
         <- if bAddSlots
             then do mm' <- case ASlotify.slotifyModule () mm_checked of
                                Left err        -> throwE [B.ErrorSaltConvert err]
                                Right mm''       -> return mm''

                     liftIO $ B.pipeSink (renderIndent $ ppr mm_simpl) sinkSlots
                     return mm'

             else return mm_checked


        -- Insert control transfer primops.
        mm_transfer
         <- case ATransfer.transferModule mm_slotify of
                Left err        -> throwE [B.ErrorSaltConvert err]
                Right mm'       -> return mm'

        liftIO $ B.pipeSink (renderIndent $ ppr mm_transfer) sinkTransfer


        -- Convert to LLVM source code.
        srcLlvm
         <- case ALlvm.convertModule platform 
                  (CReannotate.reannotate (const ()) mm_transfer) of
                Left  err       -> throwE [B.ErrorSaltConvert err]
                Right mm'       -> return mm'

        return srcLlvm

