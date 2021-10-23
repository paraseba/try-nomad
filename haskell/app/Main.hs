{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module Main where

import qualified Network.Wai.Handler.Warp as Warp
import qualified Network.Wai  as Wai
import Network.Wai (Application)
import Network.HTTP.Types.URI (queryToQueryText)
import Network.HTTP.Types (status200)
import Control.Exception (bracket_)
import Data.Binary.Builder (putStringUtf8)
import qualified Data.Text as Text
import Data.Maybe (fromMaybe)
import Text.Read (readMaybe)
import Control.Monad (join)

port :: Int
port = 8080


main :: IO ()
main = do
  putStrLn $ "Starting in port " ++ show port
  Warp.run port app

app :: Application
app req respond = bracket_
  (putStrLn "Calculating...")
  (putStrLn "Done")
  (respond $ Wai.responseBuilder status200 [] body)
  where
    mn :: Maybe Integer
    mn = do
      let q = queryToQueryText . Wai.queryString $ req
      str <- join (lookup "n" q)
      readMaybe @Integer (Text.unpack str)

    n :: Integer
    n = fromMaybe 0 mn

    body = putStringUtf8 $ show (n*n)
