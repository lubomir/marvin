{-# LANGUAGE FlexibleInstances          #-}
{-# LANGUAGE FunctionalDependencies     #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TypeSynonymInstances       #-}
module Marvin.Adapter.Slack.Types where

import           Control.Concurrent.MVar.Lifted (MVar)
import           Control.Concurrent.STM         (TMVar)
import           Control.Lens                   hiding ((.=))
import           Data.Aeson                     hiding (Error)
import           Data.Aeson.TH
import           Data.Aeson.Types               hiding (Error)
import qualified Data.ByteString.Lazy.Char8     as BS
import           Data.Foldable                  (toList)
import           Data.Hashable
import           Data.HashMap.Strict            (HashMap)
import           Data.Sequences
import           Data.String                    (IsString (..))
import qualified Data.Text                      as T
import qualified Data.Text.Lazy                 as L
import           Network.URI
import           Network.WebSockets


jsonParseURI :: Value -> Parser URI
jsonParseURI =  withText "expected text" $ maybe (fail "string not parseable as uri") return . parseURI . unpack


data RTMData = RTMData
    { ok  :: Bool
    , url :: URI
    }

type APIResponse a = Either String a


-- | Identifier for a user (internal and not equal to the username)
newtype SlackUserId = SlackUserId T.Text deriving (IsString, Eq, Hashable)
-- | Identifier for a channel (internal and not equal to the channel name)
newtype SlackChannelId = SlackChannelId T.Text deriving (IsString, Eq, Show, Hashable)


deriveJSON defaultOptions { unwrapUnaryRecords = True } ''SlackUserId
deriveJSON defaultOptions { unwrapUnaryRecords = True } ''SlackChannelId



declareFields [d|
    data LimitedChannelInfo = LimitedChannelInfo
        { limitedChannelInfoIdValue :: SlackChannelId
        , limitedChannelInfoName    :: L.Text
        , limitedChannelInfoTopic   :: L.Text
        } deriving Show
    |]

declareFields [d|
    data UserInfo = UserInfo
        { userInfoUsername :: L.Text
        , userInfoIdValue  :: SlackUserId
        }
    |]


declareFields [d|
    data ChannelCache = ChannelCache
        { channelCacheInfoCache    :: HashMap SlackChannelId LimitedChannelInfo
        , channelCacheNameResolver :: HashMap L.Text SlackChannelId
        }
    |]


declareFields [d|
    data UserCache = UserCache
        { userCacheInfoCache    :: HashMap SlackUserId UserInfo
        , userCacheNameResolver :: HashMap L.Text SlackUserId
        }
    |]



data InternalType
    = Error
        { code :: Int
        , msg  :: String
        }
    | Unhandeled String
    | Ignored
    | ChannelArchiveStatusChange SlackChannelId Bool
    | ChannelCreated LimitedChannelInfo
    | ChannelDeleted SlackChannelId
    | ChannelRename LimitedChannelInfo
    | UserChange UserInfo


data SlackAdapter a = SlackAdapter
    { midTracker        :: TMVar Int
    , channelCache      :: MVar ChannelCache
    , userInfoCache     :: MVar UserCache
    , connectionTracker :: MVar Connection
    }


data EventsAPI
data RTM



instance FromJSON RTMData where
    parseJSON = withObject "expected object" $ \o ->
        RTMData <$> o .: "ok" <*> (o .: "url" >>= jsonParseURI)


rawBS :: BS.ByteString -> String
rawBS bs = "\"" ++ BS.unpack bs ++ "\""


helloParser :: Value -> Parser Bool
helloParser = withObject "expected object" $ \o -> do
    t <- o .: "type"
    return $ (t :: T.Text) == "hello"


userInfoParser :: Value -> Parser UserInfo
userInfoParser = withObject "expected object" $ \o ->
    o .: "user" >>= withObject "expected object" (\o' -> UserInfo <$> o' .: "name" <*> o' .: "id")


userInfoListParser :: Value -> Parser [UserInfo]
userInfoListParser = withArray "expected array" (fmap toList . mapM userInfoParser)


apiResponseParser :: (Object -> Parser a) -> Value -> Parser (APIResponse a)
apiResponseParser f = withObject "expected object" $ \o -> do
    succ <- o .: "ok"
    if succ
        then Right <$> f o
        else Left <$> o .: "error"


lciParser :: Value -> Parser LimitedChannelInfo
lciParser = withObject "expected object" $ \o ->
    LimitedChannelInfo
        <$> o .: "id"
        <*> o .: "name"
        <*> (o .: "topic" >>= withObject "object" (.: "value"))

lciListParser :: Value -> Parser [LimitedChannelInfo]
lciListParser = withArray "array" $ fmap toList . mapM lciParser
