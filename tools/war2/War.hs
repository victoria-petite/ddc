
module War where

import System.Environment
import System.Exit
import Control.Monad.Error
import Control.Monad.Reader

import Config
import Test
import Command

type War a	= ReaderT Config (ErrorT TestFail IO) a

debug :: String -> War ()
debug str	
 = do	debug	<- asks configDebug
	when debug $ io $ putStr str
	
debugLn :: String -> War ()
debugLn str	= debug $ str ++ "\n"

-- Lift a possibly failing IO action into the War monad.
--	If the IO action fails then the failure is associated with the given test.
--
liftIOF :: IOF a -> War a
liftIOF iof
 = do	result <- liftIO (runErrorT iof)
	case result of
		Left  err -> throwError (TestFailIO err)
		Right x	  -> return x

-- | Try this IO action, 
--	If if fails then build a test test exception
--
catchTestIOF :: IOF a -> (IOFail -> TestFail) -> War a
catchTestIOF iof makeFailure
 = do	result	<- liftIO (runErrorT iof)
	case result of
		Left err  -> throwError (makeFailure err)
		Right x	  -> return x


tryWar :: War a -> War (Either TestFail a)
tryWar warf
 = do	config	<- ask
	result	<- liftIO (runErrorT (runReaderT warf config))
	return result


runWar :: Config -> War a -> IO (Either TestFail a)
runWar config warf
 = do	result	<- liftIO (runErrorT (runReaderT warf config))
	return result
