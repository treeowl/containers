{-# language MagicHash, UnboxedSums, UnboxedTuples, PatternSynonyms #-}

module Utils.Containers.Internal.UnboxedMaybe (Maybe#, pattern Nothing#, pattern Just#,
  toMaybe) where

type Maybe# a = (# (# #) | a #)

pattern Nothing# :: Maybe# a
pattern Nothing# = (# (# #) | #)

pattern Just# :: a -> Maybe# a
pattern Just# a = (# | a #)

{-# COMPLETE Nothing#, Just# #-}

toMaybe :: Maybe# a -> Maybe a
toMaybe (Just# a) = Just a
toMaybe _ = Nothing
{-# INLINE toMaybe #-}
