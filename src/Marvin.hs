{-|
Module      : $Header$
Description : Marvin the modular bot
Copyright   : (c) Justus Adam, 2016
License     : BSD3
Maintainer  : dev@justus.science
Stability   : experimental
Portability : POSIX

-}
module Marvin
    ( -- * Scripts
      Script(..), defineScript, ScriptInit
    , ScriptId
    , ScriptDefinition
    , IsAdapter
      -- * Reacting
    , hear, respond, enter, exit, enterIn, exitFrom, topic, topicIn, customTrigger
    , send, reply, messageChannel, messageChannel'
    , getData, getMessage, getMatch, getTopic, getChannel, getUser, getUsername, getChannelName
    , Message(..), User, Channel
    , getConfigVal, requireConfigVal
    , BotReacting, Get(getLens)
    -- ** Advanced actions
    , extractAction, extractReaction
    ) where


import           Marvin.Adapter        (IsAdapter)
import           Marvin.Internal
import           Marvin.Internal.Types hiding (getChannelName, getUsername, messageChannel)
