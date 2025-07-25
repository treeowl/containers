{-# LANGUAGE CPP #-}
{-# LANGUAGE BangPatterns #-}
#if defined(__GLASGOW_HASKELL__)
{-# LANGUAGE Trustworthy #-}
#endif
{-# OPTIONS_HADDOCK not-home #-}

#include "containers.h"

-----------------------------------------------------------------------------
-- |
-- Module      :  Data.Map.Strict.Internal
-- Copyright   :  (c) Daan Leijen 2002
--                (c) Andriy Palamarchuk 2008
-- License     :  BSD-style
-- Maintainer  :  libraries@haskell.org
-- Portability :  portable
--
-- = WARNING
--
-- This module is considered __internal__.
--
-- The Package Versioning Policy __does not apply__.
--
-- The contents of this module may change __in any way whatsoever__
-- and __without any warning__ between minor versions of this package.
--
-- Authors importing this module are expected to track development
-- closely.
--
--
-- = Finite Maps (strict interface internals)
--
-- The @'Map' k v@ type represents a finite map (sometimes called a dictionary)
-- from keys of type @k@ to values of type @v@.
--
--
-- == Implementation
--
-- The implementation of 'Map' is based on /size balanced/ binary trees (or
-- trees of /bounded balance/) as described by:
--
--    * Stephen Adams, \"/Efficient sets—a balancing act/\",
--      Journal of Functional Programming 3(4):553-562, October 1993,
--      <https://doi.org/10.1017/S0956796800000885>,
--      <https://groups.csail.mit.edu/mac/users/adams/BB/index.html>.
--    * J. Nievergelt and E.M. Reingold,
--      \"/Binary search trees of bounded balance/\",
--      SIAM journal of computing 2(1), March 1973.
--      <https://doi.org/10.1137/0202005>.
--    * Yoichi Hirai and Kazuhiko Yamamoto,
--      \"/Balancing weight-balanced trees/\",
--      Journal of Functional Programming 21(3):287-307, 2011,
--      <https://doi.org/10.1017/S0956796811000104>
--
--  Bounds for 'union', 'intersection', and 'difference' are as given
--  by
--
--    * Guy Blelloch, Daniel Ferizovic, and Yihan Sun,
--      \"/Parallel Ordered Sets Using Join/\",
--      <https://arxiv.org/abs/1602.02120v4>.
--
-----------------------------------------------------------------------------

-- See the notes at the beginning of Data.Map.Internal.

module Data.Map.Strict.Internal
    (
    -- * Map type
    Map(..)          -- instance Eq,Show,Read
    , L.Size

    -- * Operators
    , (!), (!?), (\\)

    -- * Query
    , null
    , size
    , member
    , notMember
    , lookup
    , findWithDefault
    , lookupLT
    , lookupGT
    , lookupLE
    , lookupGE

    -- * Construction
    , empty
    , singleton

    -- ** Insertion
    , insert
    , insertWith
    , insertWithKey
    , insertLookupWithKey

    -- ** Delete\/Update
    , delete
    , adjust
    , adjustWithKey
    , update
    , updateWithKey
    , upsert
    , updateLookupWithKey
    , alter
    , alterF

    -- * Combine

    -- ** Union
    , union
    , unionWith
    , unionWithKey
    , unions
    , unionsWith

    -- ** Difference
    , difference
    , differenceWith
    , differenceWithKey

    -- ** Intersection
    , intersection
    , intersectionWith
    , intersectionWithKey

    -- ** Symmetric difference
    , symmetricDifference

    -- ** Disjoint
    , disjoint

    -- ** Compose
    , compose

    -- ** General combining function
    , SimpleWhenMissing
    , SimpleWhenMatched
    , merge
    , runWhenMatched
    , runWhenMissing

    -- *** @WhenMatched@ tactics
    , zipWithMaybeMatched
    , zipWithMatched

    -- *** @WhenMissing@ tactics
    , mapMaybeMissing
    , dropMissing
    , preserveMissing
    , preserveMissing'
    , mapMissing
    , filterMissing

    -- ** Applicative general combining function
    , WhenMissing (..)
    , WhenMatched (..)
    , mergeA

    -- *** @WhenMatched@ tactics
    -- | The tactics described for 'merge' work for
    -- 'mergeA' as well. Furthermore, the following
    -- are available.
    , zipWithMaybeAMatched
    , zipWithAMatched

    -- *** @WhenMissing@ tactics
    -- | The tactics described for 'merge' work for
    -- 'mergeA' as well. Furthermore, the following
    -- are available.
    , traverseMaybeMissing
    , traverseMissing
    , filterAMissing

    -- *** Covariant maps for tactics
    , mapWhenMissing
    , mapWhenMatched

    -- ** Deprecated general combining function

    , mergeWithKey

    -- * Traversal
    -- ** Map
    , map
    , mapWithKey
    , traverseWithKey
    , traverseMaybeWithKey
    , mapAccum
    , mapAccumWithKey
    , mapAccumRWithKey
    , mapKeys
    , mapKeysWith
    , mapKeysMonotonic

    -- * Folds
    , foldr
    , foldl
    , foldrWithKey
    , foldlWithKey
    , foldMapWithKey

    -- ** Strict folds
    , foldr'
    , foldl'
    , foldrWithKey'
    , foldlWithKey'

    -- * Conversion
    , elems
    , keys
    , assocs
    , keysSet
    , argSet
    , fromSet
    , fromArgSet

    -- ** Lists
    , toList
    , fromList
    , fromListWith
    , fromListWithKey

    -- ** Ordered lists
    , toAscList
    , toDescList
    , fromAscList
    , fromAscListWith
    , fromAscListWithKey
    , fromDistinctAscList
    , fromDescList
    , fromDescListWith
    , fromDescListWithKey
    , fromDistinctDescList

    -- * Filter
    , filter
    , filterKeys
    , filterWithKey
    , restrictKeys
    , withoutKeys
    , partition
    , partitionWithKey
    , takeWhileAntitone
    , dropWhileAntitone
    , spanAntitone

    , mapMaybe
    , mapMaybeWithKey
    , mapEither
    , mapEitherWithKey

    , split
    , splitLookup
    , splitRoot

    -- * Submap
    , isSubmapOf, isSubmapOfBy
    , isProperSubmapOf, isProperSubmapOfBy

    -- * Indexed
    , lookupIndex
    , findIndex
    , elemAt
    , updateAt
    , deleteAt
    , take
    , drop
    , splitAt

    -- * Min\/Max
    , lookupMin
    , lookupMax
    , findMin
    , findMax
    , deleteMin
    , deleteMax
    , deleteFindMin
    , deleteFindMax
    , updateMin
    , updateMax
    , updateMinWithKey
    , updateMaxWithKey
    , minView
    , maxView
    , minViewWithKey
    , maxViewWithKey

    -- * Debugging
    , valid
    ) where

import Utils.Containers.Internal.Prelude hiding
  (lookup,map,filter,foldr,foldl,foldl',null,take,drop,splitAt)
import Prelude ()

import Data.Map.Internal
  ( Map (..)
  , AreWeStrict (..)
  , WhenMissing (..)
  , WhenMatched (..)
  , runWhenMatched
  , runWhenMissing
  , SimpleWhenMissing
  , SimpleWhenMatched
  , preserveMissing
  , preserveMissing'
  , dropMissing
  , filterMissing
  , filterAMissing
  , merge
  , mergeA
  , ascLinkTop
  , ascLinkAll
  , descLinkTop
  , descLinkAll
  , Stack (..)
  , MapBuilder(..)
  , emptyB
  , insertB
  , finishB
  , (!)
  , (!?)
  , (\\)
  , argSet
  , assocs
  , atKeyImpl
#ifdef __GLASGOW_HASKELL__
  , atKeyPlain
#endif
  , balance
  , balanceL
  , balanceR
  , compose
  , elemAt
  , elems
  , empty
  , delete
  , deleteAt
  , deleteFindMax
  , deleteFindMin
  , deleteMin
  , deleteMax
  , difference
  , disjoint
  , drop
  , dropWhileAntitone
  , filter
  , filterKeys
  , filterWithKey
  , findIndex
  , findMax
  , findMin
  , foldl
  , foldl'
  , foldlWithKey
  , foldlWithKey'
  , foldMapWithKey
  , foldr
  , foldr'
  , foldrWithKey
  , foldrWithKey'
  , glue
  , intersection
  , isProperSubmapOf
  , isProperSubmapOfBy
  , isSubmapOf
  , isSubmapOfBy
  , keys
  , keysSet
  , link
  , lookup
  , findWithDefault
  , lookupGE
  , lookupGT
  , lookupIndex
  , lookupLE
  , lookupLT
  , lookupMin
  , lookupMax
  , mapKeys
  , mapKeysMonotonic
  , maxView
  , maxViewWithKey
  , member
  , link2
  , minView
  , minViewWithKey
  , notMember
  , null
  , partition
  , partitionWithKey
  , restrictKeys
  , size
  , spanAntitone
  , split
  , splitAt
  , splitLookup
  , splitRoot
  , symmetricDifference
  , take
  , takeWhileAntitone
  , toList
  , toAscList
  , toDescList
  , union
  , unions
  , withoutKeys )

import Data.Map.Internal.Debug (valid)

import Control.Applicative (Const (..), liftA3)
import Data.Semigroup (Arg (..))
import qualified Data.Set.Internal as Set
import qualified Data.Map.Internal as L
import Utils.Containers.Internal.StrictPair

#ifdef __GLASGOW_HASKELL__
import Data.Coerce
#endif

#ifdef __GLASGOW_HASKELL__
import Data.Functor.Identity (Identity (..))
#endif

import qualified Data.Foldable as Foldable

-- [Note: Pointer equality for sharing]
--
-- We use pointer equality to enhance sharing between the arguments
-- of some functions and their results. Notably, we use it
-- for insert, delete, union, intersection, and difference. We do
-- *not* use it for functions, like insertWith, unionWithKey,
-- intersectionWith, etc., that allow the user to modify the elements.
-- While we *could* do so, we would only get sharing under fairly
-- narrow conditions and at a relatively high cost. It does not seem
-- worth the price.

{--------------------------------------------------------------------
  Construction
--------------------------------------------------------------------}

-- | \(O(1)\). A map with a single element.
--
-- > singleton 1 'a'        == fromList [(1, 'a')]
-- > size (singleton 1 'a') == 1

singleton :: k -> a -> Map k a
singleton k x = x `seq` Bin 1 k x Tip Tip
{-# INLINE singleton #-}

{--------------------------------------------------------------------
  Insertion
--------------------------------------------------------------------}
-- | \(O(\log n)\). Insert a new key and value in the map.
-- If the key is already present in the map, the associated value is
-- replaced with the supplied value. 'insert' is equivalent to
-- @'insertWith' 'const'@.
--
-- > insert 5 'x' (fromList [(5,'a'), (3,'b')]) == fromList [(3, 'b'), (5, 'x')]
-- > insert 7 'x' (fromList [(5,'a'), (3,'b')]) == fromList [(3, 'b'), (5, 'a'), (7, 'x')]
-- > insert 5 'x' empty                         == singleton 5 'x'

-- See Map.Internal.Note: Type of local 'go' function
insert :: Ord k => k -> a -> Map k a -> Map k a
insert = go
  where
    go :: Ord k => k -> a -> Map k a -> Map k a
    go !kx !x Tip = singleton kx x
    go kx x (Bin sz ky y l r) =
        case compare kx ky of
            LT -> balanceL ky y (go kx x l) r
            GT -> balanceR ky y l (go kx x r)
            EQ -> Bin sz kx x l r
#if __GLASGOW_HASKELL__
{-# INLINABLE insert #-}
#else
{-# INLINE insert #-}
#endif

-- | \(O(\log n)\). Insert with a function, combining new value and old value.
-- @'insertWith' f key value mp@
-- will insert the pair (key, value) into @mp@ if key does
-- not exist in the map. If the key does exist, the function will
-- insert the pair @(key, f new_value old_value)@.
--
-- > insertWith (++) 5 "xxx" (fromList [(5,"a"), (3,"b")]) == fromList [(3, "b"), (5, "xxxa")]
-- > insertWith (++) 7 "xxx" (fromList [(5,"a"), (3,"b")]) == fromList [(3, "b"), (5, "a"), (7, "xxx")]
-- > insertWith (++) 5 "xxx" empty                         == singleton 5 "xxx"
--
-- Also see the performance note on 'fromListWith'.

insertWith :: Ord k => (a -> a -> a) -> k -> a -> Map k a -> Map k a
insertWith = go
  where
    go :: Ord k => (a -> a -> a) -> k -> a -> Map k a -> Map k a
    go _ !kx x Tip = singleton kx x
    go f !kx x (Bin sy ky y l r) =
        case compare kx ky of
            LT -> balanceL ky y (go f kx x l) r
            GT -> balanceR ky y l (go f kx x r)
            EQ -> let !y' = f x y in Bin sy kx y' l r
#if __GLASGOW_HASKELL__
{-# INLINABLE insertWith #-}
#else
{-# INLINE insertWith #-}
#endif

insertWithR :: Ord k => (a -> a -> a) -> k -> a -> Map k a -> Map k a
insertWithR = go
  where
    go :: Ord k => (a -> a -> a) -> k -> a -> Map k a -> Map k a
    go _ !kx x Tip = singleton kx x
    go f !kx x (Bin sy ky y l r) =
        case compare kx ky of
            LT -> balanceL ky y (go f kx x l) r
            GT -> balanceR ky y l (go f kx x r)
            EQ -> let !y' = f y x in Bin sy ky y' l r
#if __GLASGOW_HASKELL__
{-# INLINABLE insertWithR #-}
#else
{-# INLINE insertWithR #-}
#endif

-- | \(O(\log n)\). Insert with a function, combining key, new value and old value.
-- @'insertWithKey' f key value mp@
-- will insert the pair (key, value) into @mp@ if key does
-- not exist in the map. If the key does exist, the function will
-- insert the pair @(key,f key new_value old_value)@.
-- Note that the key passed to f is the same key passed to 'insertWithKey'.
--
-- > let f key new_value old_value = (show key) ++ ":" ++ new_value ++ "|" ++ old_value
-- > insertWithKey f 5 "xxx" (fromList [(5,"a"), (3,"b")]) == fromList [(3, "b"), (5, "5:xxx|a")]
-- > insertWithKey f 7 "xxx" (fromList [(5,"a"), (3,"b")]) == fromList [(3, "b"), (5, "a"), (7, "xxx")]
-- > insertWithKey f 5 "xxx" empty                         == singleton 5 "xxx"
--
-- Also see the performance note on 'fromListWith'.

-- See Map.Internal.Note: Type of local 'go' function
insertWithKey :: Ord k => (k -> a -> a -> a) -> k -> a -> Map k a -> Map k a
insertWithKey = go
  where
    go :: Ord k => (k -> a -> a -> a) -> k -> a -> Map k a -> Map k a
    -- Forcing `kx` may look redundant, but it's possible `compare` will
    -- be lazy.
    go _ !kx x Tip = singleton kx x
    go f kx x (Bin sy ky y l r) =
        case compare kx ky of
            LT -> balanceL ky y (go f kx x l) r
            GT -> balanceR ky y l (go f kx x r)
            EQ -> let !x' = f kx x y
                  in Bin sy kx x' l r
#if __GLASGOW_HASKELL__
{-# INLINABLE insertWithKey #-}
#else
{-# INLINE insertWithKey #-}
#endif

insertWithKeyR :: Ord k => (k -> a -> a -> a) -> k -> a -> Map k a -> Map k a
insertWithKeyR = go
  where
    go :: Ord k => (k -> a -> a -> a) -> k -> a -> Map k a -> Map k a
    -- Forcing `kx` may look redundant, but it's possible `compare` will
    -- be lazy.
    go _ !kx x Tip = singleton kx x
    go f kx x (Bin sy ky y l r) =
        case compare kx ky of
            LT -> balanceL ky y (go f kx x l) r
            GT -> balanceR ky y l (go f kx x r)
            EQ -> let !y' = f ky y x
                  in Bin sy ky y' l r
#if __GLASGOW_HASKELL__
{-# INLINABLE insertWithKeyR #-}
#else
{-# INLINE insertWithKeyR #-}
#endif

-- | \(O(\log n)\). Combines insert operation with old value retrieval.
-- The expression (@'insertLookupWithKey' f k x map@)
-- is a pair where the first element is equal to (@'lookup' k map@)
-- and the second element equal to (@'insertWithKey' f k x map@).
--
-- > let f key new_value old_value = (show key) ++ ":" ++ new_value ++ "|" ++ old_value
-- > insertLookupWithKey f 5 "xxx" (fromList [(5,"a"), (3,"b")]) == (Just "a", fromList [(3, "b"), (5, "5:xxx|a")])
-- > insertLookupWithKey f 7 "xxx" (fromList [(5,"a"), (3,"b")]) == (Nothing,  fromList [(3, "b"), (5, "a"), (7, "xxx")])
-- > insertLookupWithKey f 5 "xxx" empty                         == (Nothing,  singleton 5 "xxx")
--
-- This is how to define @insertLookup@ using @insertLookupWithKey@:
--
-- > let insertLookup kx x t = insertLookupWithKey (\_ a _ -> a) kx x t
-- > insertLookup 5 "x" (fromList [(5,"a"), (3,"b")]) == (Just "a", fromList [(3, "b"), (5, "x")])
-- > insertLookup 7 "x" (fromList [(5,"a"), (3,"b")]) == (Nothing,  fromList [(3, "b"), (5, "a"), (7, "x")])
--
-- Also see the performance note on 'fromListWith'.

-- See Map.Internal.Note: Type of local 'go' function
insertLookupWithKey :: Ord k => (k -> a -> a -> a) -> k -> a -> Map k a
                    -> (Maybe a, Map k a)
insertLookupWithKey f0 kx0 x0 t0 = toPair $ go f0 kx0 x0 t0
  where
    go :: Ord k => (k -> a -> a -> a) -> k -> a -> Map k a -> StrictPair (Maybe a) (Map k a)
    go _ !kx x Tip = Nothing :*: singleton kx x
    go f kx x (Bin sy ky y l r) =
        case compare kx ky of
            LT -> let (found :*: l') = go f kx x l
                  in found :*: balanceL ky y l' r
            GT -> let (found :*: r') = go f kx x r
                  in found :*: balanceR ky y l r'
            EQ -> let x' = f kx x y
                  in x' `seq` (Just y :*: Bin sy kx x' l r)
#if __GLASGOW_HASKELL__
{-# INLINABLE insertLookupWithKey #-}
#else
{-# INLINE insertLookupWithKey #-}
#endif

{--------------------------------------------------------------------
  Deletion
--------------------------------------------------------------------}

-- | \(O(\log n)\). Update a value at a specific key with the result of the provided function.
-- When the key is not
-- a member of the map, the original map is returned.
--
-- > adjust ("new " ++) 5 (fromList [(5,"a"), (3,"b")]) == fromList [(3, "b"), (5, "new a")]
-- > adjust ("new " ++) 7 (fromList [(5,"a"), (3,"b")]) == fromList [(3, "b"), (5, "a")]
-- > adjust ("new " ++) 7 empty                         == empty

adjust :: Ord k => (a -> a) -> k -> Map k a -> Map k a
adjust f = adjustWithKey (\_ x -> f x)
#if __GLASGOW_HASKELL__
{-# INLINABLE adjust #-}
#else
{-# INLINE adjust #-}
#endif

-- | \(O(\log n)\). Adjust a value at a specific key. When the key is not
-- a member of the map, the original map is returned.
--
-- > let f key x = (show key) ++ ":new " ++ x
-- > adjustWithKey f 5 (fromList [(5,"a"), (3,"b")]) == fromList [(3, "b"), (5, "5:new a")]
-- > adjustWithKey f 7 (fromList [(5,"a"), (3,"b")]) == fromList [(3, "b"), (5, "a")]
-- > adjustWithKey f 7 empty                         == empty

adjustWithKey :: Ord k => (k -> a -> a) -> k -> Map k a -> Map k a
adjustWithKey = go
  where
    go :: Ord k => (k -> a -> a) -> k -> Map k a -> Map k a
    go _ !_ Tip = Tip
    go f k (Bin sx kx x l r) =
        case compare k kx of
           LT -> Bin sx kx x (go f k l) r
           GT -> Bin sx kx x l (go f k r)
           EQ -> Bin sx kx x' l r
             where !x' = f kx x
#if __GLASGOW_HASKELL__
{-# INLINABLE adjustWithKey #-}
#else
{-# INLINE adjustWithKey #-}
#endif

-- | \(O(\log n)\). The expression (@'update' f k map@) updates the value @x@
-- at @k@ (if it is in the map). If (@f x@) is 'Nothing', the element is
-- deleted. If it is (@'Just' y@), the key @k@ is bound to the new value @y@.
--
-- > let f x = if x == "a" then Just "new a" else Nothing
-- > update f 5 (fromList [(5,"a"), (3,"b")]) == fromList [(3, "b"), (5, "new a")]
-- > update f 7 (fromList [(5,"a"), (3,"b")]) == fromList [(3, "b"), (5, "a")]
-- > update f 3 (fromList [(5,"a"), (3,"b")]) == singleton 5 "a"

update :: Ord k => (a -> Maybe a) -> k -> Map k a -> Map k a
update f = updateWithKey (\_ x -> f x)
#if __GLASGOW_HASKELL__
{-# INLINABLE update #-}
#else
{-# INLINE update #-}
#endif

-- | \(O(\log n)\). The expression (@'updateWithKey' f k map@) updates the
-- value @x@ at @k@ (if it is in the map). If (@f k x@) is 'Nothing',
-- the element is deleted. If it is (@'Just' y@), the key @k@ is bound
-- to the new value @y@.
--
-- > let f k x = if x == "a" then Just ((show k) ++ ":new a") else Nothing
-- > updateWithKey f 5 (fromList [(5,"a"), (3,"b")]) == fromList [(3, "b"), (5, "5:new a")]
-- > updateWithKey f 7 (fromList [(5,"a"), (3,"b")]) == fromList [(3, "b"), (5, "a")]
-- > updateWithKey f 3 (fromList [(5,"a"), (3,"b")]) == singleton 5 "a"

-- See Map.Internal.Note: Type of local 'go' function
updateWithKey :: Ord k => (k -> a -> Maybe a) -> k -> Map k a -> Map k a
updateWithKey = go
  where
    go :: Ord k => (k -> a -> Maybe a) -> k -> Map k a -> Map k a
    go _ !_ Tip = Tip
    go f k(Bin sx kx x l r) =
        case compare k kx of
           LT -> balanceR kx x (go f k l) r
           GT -> balanceL kx x l (go f k r)
           EQ -> case f kx x of
                   Just x' -> x' `seq` Bin sx kx x' l r
                   Nothing -> glue l r
#if __GLASGOW_HASKELL__
{-# INLINABLE updateWithKey #-}
#else
{-# INLINE updateWithKey #-}
#endif

-- | \(O(\log n)\). Update the value at a key or insert a value if the key is
-- not in the map.
--
-- @
-- let inc = maybe 1 (+1)
-- upsert inc \'a\' (fromList [(\'a\',1),(\'c\',2)]) == fromList [(\'a\',2),(\'c\',2)]
-- upsert inc \'b\' (fromList [(\'a\',1),(\'c\',2)]) == fromList [(\'a\',1),(\'b\',1),(\'c\',2)]
-- @
--
-- @since FIXME
upsert :: Ord k => (Maybe a -> a) -> k -> Map k a -> Map k a
upsert f !k (Bin sz kx x l r) =
  case compare k kx of
    LT -> balanceL kx x (upsert f k l) r
    EQ -> let !x' = f (Just x) in Bin sz kx x' l r
    GT -> balanceR kx x l (upsert f k r)
upsert f !k Tip = singleton k (f Nothing)
{-# INLINABLE upsert #-}

-- | \(O(\log n)\). Look up and update. See also 'updateWithKey'.
-- This function returns the changed value, if it is updated.
-- Returns the original key value if the map entry is deleted.
--
-- > let f k x = if x == "a" then Just ((show k) ++ ":new a") else Nothing
-- > updateLookupWithKey f 5 (fromList [(5,"a"), (3,"b")]) == (Just "5:new a", fromList [(3, "b"), (5, "5:new a")])
-- > updateLookupWithKey f 7 (fromList [(5,"a"), (3,"b")]) == (Nothing,  fromList [(3, "b"), (5, "a")])
-- > updateLookupWithKey f 3 (fromList [(5,"a"), (3,"b")]) == (Just "b", singleton 5 "a")

-- See Map.Internal.Note: Type of local 'go' function
updateLookupWithKey :: Ord k => (k -> a -> Maybe a) -> k -> Map k a -> (Maybe a,Map k a)
updateLookupWithKey f0 k0 t0 = toPair $ go f0 k0 t0
 where
   go :: Ord k => (k -> a -> Maybe a) -> k -> Map k a -> StrictPair (Maybe a) (Map k a)
   go _ !_ Tip = (Nothing :*: Tip)
   go f k (Bin sx kx x l r) =
          case compare k kx of
               LT -> let (found :*: l') = go f k l
                     in found :*: balanceR kx x l' r
               GT -> let (found :*: r') = go f k r
                     in found :*: balanceL kx x l r'
               EQ -> case f kx x of
                       Just x' -> x' `seq` (Just x' :*: Bin sx kx x' l r)
                       Nothing -> (Just x :*: glue l r)
#if __GLASGOW_HASKELL__
{-# INLINABLE updateLookupWithKey #-}
#else
{-# INLINE updateLookupWithKey #-}
#endif

-- | \(O(\log n)\). The expression (@'alter' f k map@) alters the value @x@ at @k@, or absence thereof.
-- 'alter' can be used to insert, delete, or update a value in a 'Map'.
-- In short : @'lookup' k ('alter' f k m) = f ('lookup' k m)@.
--
-- > let f _ = Nothing
-- > alter f 7 (fromList [(5,"a"), (3,"b")]) == fromList [(3, "b"), (5, "a")]
-- > alter f 5 (fromList [(5,"a"), (3,"b")]) == singleton 3 "b"
-- >
-- > let f _ = Just "c"
-- > alter f 7 (fromList [(5,"a"), (3,"b")]) == fromList [(3, "b"), (5, "a"), (7, "c")]
-- > alter f 5 (fromList [(5,"a"), (3,"b")]) == fromList [(3, "b"), (5, "c")]
--
-- Note that @'adjust' = alter . fmap@.

-- See Map.Internal.Note: Type of local 'go' function
alter :: Ord k => (Maybe a -> Maybe a) -> k -> Map k a -> Map k a
alter = go
  where
    go :: Ord k => (Maybe a -> Maybe a) -> k -> Map k a -> Map k a
    go f !k Tip = case f Nothing of
               Nothing -> Tip
               Just x  -> singleton k x

    go f k (Bin sx kx x l r) = case compare k kx of
               LT -> balance kx x (go f k l) r
               GT -> balance kx x l (go f k r)
               EQ -> case f (Just x) of
                       Just x' -> x' `seq` Bin sx kx x' l r
                       Nothing -> glue l r
#if __GLASGOW_HASKELL__
{-# INLINABLE alter #-}
#else
{-# INLINE alter #-}
#endif

-- | \(O(\log n)\). The expression (@'alterF' f k map@) alters the value @x@ at @k@, or absence thereof.
-- 'alterF' can be used to inspect, insert, delete, or update a value in a 'Map'.
-- In short: @'lookup' k \<$\> 'alterF' f k m = f ('lookup' k m)@.
--
-- Example:
--
-- @
-- interactiveAlter :: Int -> Map Int String -> IO (Map Int String)
-- interactiveAlter k m = alterF f k m where
--   f Nothing = do
--      putStrLn $ show k ++
--          " was not found in the map. Would you like to add it?"
--      getUserResponse1 :: IO (Maybe String)
--   f (Just old) = do
--      putStrLn $ "The key is currently bound to " ++ show old ++
--          ". Would you like to change or delete it?"
--      getUserResponse2 :: IO (Maybe String)
-- @
--
-- 'alterF' is the most general operation for working with an individual
-- key that may or may not be in a given map. When used with trivial
-- functors like 'Identity' and 'Const', it is often slightly slower than
-- more specialized combinators like 'lookup' and 'insert'. However, when
-- the functor is non-trivial and key comparison is not particularly cheap,
-- it is the fastest way.
--
-- Note on rewrite rules:
--
-- This module includes GHC rewrite rules to optimize 'alterF' for
-- the 'Const' and 'Identity' functors. In general, these rules
-- improve performance. The sole exception is that when using
-- 'Identity', deleting a key that is already absent takes longer
-- than it would without the rules. If you expect this to occur
-- a very large fraction of the time, you might consider using a
-- private copy of the 'Identity' type.
--
-- Note: 'alterF' is a flipped version of the @at@ combinator from
-- @Control.Lens.At@.
--
-- @since 0.5.8
alterF :: (Functor f, Ord k)
       => (Maybe a -> f (Maybe a)) -> k -> Map k a -> f (Map k a)
alterF f k m = atKeyImpl Strict k f m

#ifndef __GLASGOW_HASKELL__
{-# INLINE alterF #-}
#else
{-# INLINABLE [2] alterF #-}

-- We can save a little time by recognizing the special case of
-- `Control.Applicative.Const` and just doing a lookup.
{-# RULES
"alterF/Const" forall k (f :: Maybe a -> Const b (Maybe a)) . alterF f k = \m -> Const . getConst . f $ lookup k m
"alterF/Identity" forall k f . alterF f k = atKeyIdentity k f
 #-}

atKeyIdentity :: Ord k => k -> (Maybe a -> Identity (Maybe a)) -> Map k a -> Identity (Map k a)
atKeyIdentity k f t = Identity $ atKeyPlain Strict k (coerce f) t
{-# INLINABLE atKeyIdentity #-}
#endif

{--------------------------------------------------------------------
  Indexing
--------------------------------------------------------------------}

-- | \(O(\log n)\). Update the element at /index/. Calls 'error' when an
-- invalid index is used.
--
-- __Note__: This function is partial.
--
-- > updateAt (\ _ _ -> Just "x") 0    (fromList [(5,"a"), (3,"b")]) == fromList [(3, "x"), (5, "a")]
-- > updateAt (\ _ _ -> Just "x") 1    (fromList [(5,"a"), (3,"b")]) == fromList [(3, "b"), (5, "x")]
-- > updateAt (\ _ _ -> Just "x") 2    (fromList [(5,"a"), (3,"b")])    Error: index out of range
-- > updateAt (\ _ _ -> Just "x") (-1) (fromList [(5,"a"), (3,"b")])    Error: index out of range
-- > updateAt (\_ _  -> Nothing)  0    (fromList [(5,"a"), (3,"b")]) == singleton 5 "a"
-- > updateAt (\_ _  -> Nothing)  1    (fromList [(5,"a"), (3,"b")]) == singleton 3 "b"
-- > updateAt (\_ _  -> Nothing)  2    (fromList [(5,"a"), (3,"b")])    Error: index out of range
-- > updateAt (\_ _  -> Nothing)  (-1) (fromList [(5,"a"), (3,"b")])    Error: index out of range

updateAt :: (k -> a -> Maybe a) -> Int -> Map k a -> Map k a
updateAt f i t = i `seq`
  case t of
    Tip -> error "Map.updateAt: index out of range"
    Bin sx kx x l r -> case compare i sizeL of
      LT -> balanceR kx x (updateAt f i l) r
      GT -> balanceL kx x l (updateAt f (i-sizeL-1) r)
      EQ -> case f kx x of
              Just x' -> x' `seq` Bin sx kx x' l r
              Nothing -> glue l r
      where
        sizeL = size l

{--------------------------------------------------------------------
  Minimal, Maximal
--------------------------------------------------------------------}

-- | \(O(\log n)\). Update the value at the minimal key.
--
-- > updateMin (\ a -> Just ("X" ++ a)) (fromList [(5,"a"), (3,"b")]) == fromList [(3, "Xb"), (5, "a")]
-- > updateMin (\ _ -> Nothing)         (fromList [(5,"a"), (3,"b")]) == singleton 5 "a"

updateMin :: (a -> Maybe a) -> Map k a -> Map k a
updateMin f m
  = updateMinWithKey (\_ x -> f x) m

-- | \(O(\log n)\). Update the value at the maximal key.
--
-- > updateMax (\ a -> Just ("X" ++ a)) (fromList [(5,"a"), (3,"b")]) == fromList [(3, "b"), (5, "Xa")]
-- > updateMax (\ _ -> Nothing)         (fromList [(5,"a"), (3,"b")]) == singleton 3 "b"

updateMax :: (a -> Maybe a) -> Map k a -> Map k a
updateMax f m
  = updateMaxWithKey (\_ x -> f x) m


-- | \(O(\log n)\). Update the value at the minimal key.
--
-- > updateMinWithKey (\ k a -> Just ((show k) ++ ":" ++ a)) (fromList [(5,"a"), (3,"b")]) == fromList [(3,"3:b"), (5,"a")]
-- > updateMinWithKey (\ _ _ -> Nothing)                     (fromList [(5,"a"), (3,"b")]) == singleton 5 "a"

updateMinWithKey :: (k -> a -> Maybe a) -> Map k a -> Map k a
updateMinWithKey _ Tip                 = Tip
updateMinWithKey f (Bin sx kx x Tip r) = case f kx x of
                                           Nothing -> r
                                           Just x' -> x' `seq` Bin sx kx x' Tip r
updateMinWithKey f (Bin _ kx x l r)    = balanceR kx x (updateMinWithKey f l) r

-- | \(O(\log n)\). Update the value at the maximal key.
--
-- > updateMaxWithKey (\ k a -> Just ((show k) ++ ":" ++ a)) (fromList [(5,"a"), (3,"b")]) == fromList [(3,"b"), (5,"5:a")]
-- > updateMaxWithKey (\ _ _ -> Nothing)                     (fromList [(5,"a"), (3,"b")]) == singleton 3 "b"

updateMaxWithKey :: (k -> a -> Maybe a) -> Map k a -> Map k a
updateMaxWithKey _ Tip                 = Tip
updateMaxWithKey f (Bin sx kx x l Tip) = case f kx x of
                                           Nothing -> l
                                           Just x' -> x' `seq` Bin sx kx x' l Tip
updateMaxWithKey f (Bin _ kx x l r)    = balanceL kx x l (updateMaxWithKey f r)

{--------------------------------------------------------------------
  Union.
--------------------------------------------------------------------}

-- | The union of a list of maps, with a combining operation:
--   (@'unionsWith' f == 'Prelude.foldl' ('unionWith' f) 'empty'@).
--
-- > unionsWith (++) [(fromList [(5, "a"), (3, "b")]), (fromList [(5, "A"), (7, "C")]), (fromList [(5, "A3"), (3, "B3")])]
-- >     == fromList [(3, "bB3"), (5, "aAA3"), (7, "C")]

unionsWith :: (Foldable f, Ord k) => (a->a->a) -> f (Map k a) -> Map k a
unionsWith f ts
  = Foldable.foldl' (unionWith f) empty ts
#if __GLASGOW_HASKELL__
{-# INLINABLE unionsWith #-}
#endif

{--------------------------------------------------------------------
  Union with a combining function
--------------------------------------------------------------------}
-- | \(O\bigl(m \log\bigl(\frac{n}{m}+1\bigr)\bigr), \; 0 < m \leq n\). Union with a combining function.
--
-- > unionWith (++) (fromList [(5, "a"), (3, "b")]) (fromList [(5, "A"), (7, "C")]) == fromList [(3, "b"), (5, "aA"), (7, "C")]
--
-- Also see the performance note on 'fromListWith'.

unionWith :: Ord k => (a -> a -> a) -> Map k a -> Map k a -> Map k a
unionWith _f t1 Tip = t1
unionWith f t1 (Bin _ k x Tip Tip) = insertWithR f k x t1
unionWith f (Bin _ k x Tip Tip) t2 = insertWith f k x t2
unionWith _f Tip t2 = t2
unionWith f (Bin _ k1 x1 l1 r1) t2 = case splitLookup k1 t2 of
  (l2, mb, r2) -> link k1 x1' (unionWith f l1 l2) (unionWith f r1 r2)
    where !x1' = maybe x1 (f x1) mb
#if __GLASGOW_HASKELL__
{-# INLINABLE unionWith #-}
#endif

-- | \(O\bigl(m \log\bigl(\frac{n}{m}+1\bigr)\bigr), \; 0 < m \leq n\).
-- Union with a combining function.
--
-- > let f key left_value right_value = (show key) ++ ":" ++ left_value ++ "|" ++ right_value
-- > unionWithKey f (fromList [(5, "a"), (3, "b")]) (fromList [(5, "A"), (7, "C")]) == fromList [(3, "b"), (5, "5:a|A"), (7, "C")]
--
-- Also see the performance note on 'fromListWith'.

unionWithKey :: Ord k => (k -> a -> a -> a) -> Map k a -> Map k a -> Map k a
unionWithKey _f t1 Tip = t1
unionWithKey f t1 (Bin _ k x Tip Tip) = insertWithKeyR f k x t1
unionWithKey f (Bin _ k x Tip Tip) t2 = insertWithKey f k x t2
unionWithKey _f Tip t2 = t2
unionWithKey f (Bin _ k1 x1 l1 r1) t2 = case splitLookup k1 t2 of
  (l2, mb, r2) -> link k1 x1' (unionWithKey f l1 l2) (unionWithKey f r1 r2)
    where !x1' = maybe x1 (f k1 x1) mb
#if __GLASGOW_HASKELL__
{-# INLINABLE unionWithKey #-}
#endif

{--------------------------------------------------------------------
  Difference
--------------------------------------------------------------------}

-- | \(O(n+m)\). Difference with a combining function.
-- When two equal keys are
-- encountered, the combining function is applied to the values of these keys.
-- If it returns 'Nothing', the element is discarded (proper set difference). If
-- it returns (@'Just' y@), the element is updated with a new value @y@.
--
-- > let f al ar = if al == "b" then Just (al ++ ":" ++ ar) else Nothing
-- > differenceWith f (fromList [(5, "a"), (3, "b")]) (fromList [(5, "A"), (3, "B"), (7, "C")])
-- >     == singleton 3 "b:B"

differenceWith :: Ord k => (a -> b -> Maybe a) -> Map k a -> Map k b -> Map k a
differenceWith f = merge preserveMissing dropMissing (zipWithMaybeMatched $ \_ x1 x2 -> f x1 x2)
#if __GLASGOW_HASKELL__
{-# INLINABLE differenceWith #-}
#endif

-- | \(O(n+m)\). Difference with a combining function. When two equal keys are
-- encountered, the combining function is applied to the key and both values.
-- If it returns 'Nothing', the element is discarded (proper set difference). If
-- it returns (@'Just' y@), the element is updated with a new value @y@.
--
-- > let f k al ar = if al == "b" then Just ((show k) ++ ":" ++ al ++ "|" ++ ar) else Nothing
-- > differenceWithKey f (fromList [(5, "a"), (3, "b")]) (fromList [(5, "A"), (3, "B"), (10, "C")])
-- >     == singleton 3 "3:b|B"

differenceWithKey :: Ord k => (k -> a -> b -> Maybe a) -> Map k a -> Map k b -> Map k a
differenceWithKey f = merge preserveMissing dropMissing (zipWithMaybeMatched f)
#if __GLASGOW_HASKELL__
{-# INLINABLE differenceWithKey #-}
#endif


{--------------------------------------------------------------------
  Intersection
--------------------------------------------------------------------}

-- | \(O\bigl(m \log\bigl(\frac{n}{m}+1\bigr)\bigr), \; 0 < m \leq n\). Intersection with a combining function.
--
-- > intersectionWith (++) (fromList [(5, "a"), (3, "b")]) (fromList [(5, "A"), (7, "C")]) == singleton 5 "aA"

intersectionWith :: Ord k => (a -> b -> c) -> Map k a -> Map k b -> Map k c
intersectionWith _f Tip _ = Tip
intersectionWith _f _ Tip = Tip
intersectionWith f (Bin _ k x1 l1 r1) t2 = case mb of
    Just x2 -> let !x1' = f x1 x2 in link k x1' l1l2 r1r2
    Nothing -> link2 l1l2 r1r2
  where
    !(l2, mb, r2) = splitLookup k t2
    !l1l2 = intersectionWith f l1 l2
    !r1r2 = intersectionWith f r1 r2
#if __GLASGOW_HASKELL__
{-# INLINABLE intersectionWith #-}
#endif

-- | \(O\bigl(m \log\bigl(\frac{n}{m}+1\bigr)\bigr), \; 0 < m \leq n\). Intersection with a combining function.
--
-- > let f k al ar = (show k) ++ ":" ++ al ++ "|" ++ ar
-- > intersectionWithKey f (fromList [(5, "a"), (3, "b")]) (fromList [(5, "A"), (7, "C")]) == singleton 5 "5:a|A"

intersectionWithKey :: Ord k => (k -> a -> b -> c) -> Map k a -> Map k b -> Map k c
intersectionWithKey _f Tip _ = Tip
intersectionWithKey _f _ Tip = Tip
intersectionWithKey f (Bin _ k x1 l1 r1) t2 = case mb of
    Just x2 -> let !x1' = f k x1 x2 in link k x1' l1l2 r1r2
    Nothing -> link2 l1l2 r1r2
  where
    !(l2, mb, r2) = splitLookup k t2
    !l1l2 = intersectionWithKey f l1 l2
    !r1r2 = intersectionWithKey f r1 r2
#if __GLASGOW_HASKELL__
{-# INLINABLE intersectionWithKey #-}
#endif

-- | Map covariantly over a @'WhenMissing' f k x@.
mapWhenMissing :: Functor f => (a -> b) -> WhenMissing f k x a -> WhenMissing f k x b
mapWhenMissing f q = WhenMissing
  { missingSubtree = fmap (map f) . missingSubtree q
  , missingKey = \k x -> fmap (forceMaybe . fmap f) $ missingKey q k x}

-- | Map covariantly over a @'WhenMatched' f k x y@.
mapWhenMatched :: Functor f => (a -> b) -> WhenMatched f k x y a -> WhenMatched f k x y b
mapWhenMatched f q = WhenMatched
  { matchedKey = \k x y -> fmap (forceMaybe . fmap f) $ runWhenMatched q k x y }

-- | When a key is found in both maps, apply a function to the
-- key and values and maybe use the result in the merged map.
--
-- @
-- zipWithMaybeMatched :: (k -> x -> y -> Maybe z)
--                     -> SimpleWhenMatched k x y z
-- @
zipWithMaybeMatched :: Applicative f
                    => (k -> x -> y -> Maybe z)
                    -> WhenMatched f k x y z
zipWithMaybeMatched f = WhenMatched $
  \k x y -> pure $! forceMaybe $! f k x y
{-# INLINE zipWithMaybeMatched #-}

-- | When a key is found in both maps, apply a function to the
-- key and values, perform the resulting action, and maybe use
-- the result in the merged map.
--
-- This is the fundamental 'WhenMatched' tactic.
zipWithMaybeAMatched :: Applicative f
                     => (k -> x -> y -> f (Maybe z))
                     -> WhenMatched f k x y z
zipWithMaybeAMatched f = WhenMatched $
  \ k x y -> forceMaybe <$> f k x y
{-# INLINE zipWithMaybeAMatched #-}

-- | When a key is found in both maps, apply a function to the
-- key and values to produce an action and use its result in the merged map.
zipWithAMatched :: Applicative f
                => (k -> x -> y -> f z)
                -> WhenMatched f k x y z
zipWithAMatched f = WhenMatched $
  \ k x y -> (Just $!) <$> f k x y
{-# INLINE zipWithAMatched #-}

-- | When a key is found in both maps, apply a function to the
-- key and values and use the result in the merged map.
--
-- @
-- zipWithMatched :: (k -> x -> y -> z)
--                -> SimpleWhenMatched k x y z
-- @
zipWithMatched :: Applicative f
               => (k -> x -> y -> z) -> WhenMatched f k x y z
zipWithMatched f = WhenMatched $
  \k x y -> pure $! Just $! f k x y
{-# INLINE zipWithMatched #-}

-- | Map over the entries whose keys are missing from the other map,
-- optionally removing some. This is the most powerful 'SimpleWhenMissing'
-- tactic, but others are usually more efficient.
--
-- @
-- mapMaybeMissing :: (k -> x -> Maybe y) -> SimpleWhenMissing k x y
-- @
--
-- prop> mapMaybeMissing f = traverseMaybeMissing (\k x -> pure (f k x))
--
-- but @mapMaybeMissing@ uses fewer unnecessary 'Applicative' operations.
mapMaybeMissing :: Applicative f => (k -> x -> Maybe y) -> WhenMissing f k x y
mapMaybeMissing f = WhenMissing
  { missingSubtree = \m -> pure $! mapMaybeWithKey f m
  , missingKey = \k x -> pure $! forceMaybe $! f k x }
{-# INLINE mapMaybeMissing #-}

-- | Map over the entries whose keys are missing from the other map.
--
-- @
-- mapMissing :: (k -> x -> y) -> SimpleWhenMissing k x y
-- @
--
-- prop> mapMissing f = mapMaybeMissing (\k x -> Just $ f k x)
--
-- but @mapMissing@ is somewhat faster.
mapMissing :: Applicative f => (k -> x -> y) -> WhenMissing f k x y
mapMissing f = WhenMissing
  { missingSubtree = \m -> pure $! mapWithKey f m
  , missingKey = \k x -> pure $! Just $! f k x }
{-# INLINE mapMissing #-}

-- | Traverse over the entries whose keys are missing from the other map,
-- optionally producing values to put in the result.
-- This is the most powerful 'WhenMissing' tactic, but others are usually
-- more efficient.
traverseMaybeMissing :: Applicative f
                     => (k -> x -> f (Maybe y)) -> WhenMissing f k x y
traverseMaybeMissing f = WhenMissing
  { missingSubtree = traverseMaybeWithKey f
  , missingKey = \k x -> forceMaybe <$> f k x }
{-# INLINE traverseMaybeMissing #-}

-- | Traverse over the entries whose keys are missing from the other map.
traverseMissing :: Applicative f
                     => (k -> x -> f y) -> WhenMissing f k x y
traverseMissing f = WhenMissing
  { missingSubtree = traverseWithKey f
  , missingKey = \k x -> (Just $!) <$> f k x }
{-# INLINE traverseMissing #-}

forceMaybe :: Maybe a -> Maybe a
forceMaybe Nothing = Nothing
forceMaybe m@(Just !_) = m
{-# INLINE forceMaybe #-}

{--------------------------------------------------------------------
  MergeWithKey
--------------------------------------------------------------------}

-- | \(O(n+m)\). An unsafe universal combining function.
--
-- __Warning__: This function can produce corrupt maps and its results
-- may depend on the internal structures of its inputs. Users should
-- prefer 'Data.Map.Merge.Strict.merge' or
-- 'Data.Map.Merge.Strict.mergeA'.
--
-- When 'mergeWithKey' is given three arguments, it is inlined to the call
-- site. You should therefore use 'mergeWithKey' only to define custom
-- combining functions. For example, you could define 'unionWithKey',
-- 'differenceWithKey' and 'intersectionWithKey' as
--
-- > myUnionWithKey f m1 m2 = mergeWithKey (\k x1 x2 -> Just (f k x1 x2)) id id m1 m2
-- > myDifferenceWithKey f m1 m2 = mergeWithKey f id (const empty) m1 m2
-- > myIntersectionWithKey f m1 m2 = mergeWithKey (\k x1 x2 -> Just (f k x1 x2)) (const empty) (const empty) m1 m2
--
-- When calling @'mergeWithKey' combine only1 only2@, a function combining two
-- 'Map's is created, such that
--
-- * if a key is present in both maps, it is passed with both corresponding
--   values to the @combine@ function. Depending on the result, the key is either
--   present in the result with specified value, or is left out;
--
-- * a nonempty subtree present only in the first map is passed to @only1@ and
--   the output is added to the result;
--
-- * a nonempty subtree present only in the second map is passed to @only2@ and
--   the output is added to the result.
--
-- The @only1@ and @only2@ methods /must return a map with a subset (possibly empty) of the keys of the given map/.
-- The values can be modified arbitrarily. Most common variants of @only1@ and
-- @only2@ are 'id' and @'const' 'empty'@, but for example @'map' f@ or
-- @'filterWithKey' f@ could be used for any @f@.

mergeWithKey :: Ord k
             => (k -> a -> b -> Maybe c)
             -> (Map k a -> Map k c)
             -> (Map k b -> Map k c)
             -> Map k a -> Map k b -> Map k c
mergeWithKey f g1 g2 = go
  where
    go Tip Tip = Tip
    go Tip t2 = g2 t2
    go t1 Tip = g1 t1
    go (Bin _ kx x l1 r1) t2 =
      case found of
        Nothing -> case g1 (singleton kx x) of
                     Tip -> link2 l' r'
                     (Bin _ _ x' Tip Tip) -> link kx x' l' r'
                     _ -> error "mergeWithKey: Given function only1 does not fulfill required conditions (see documentation)"
        Just x2 -> case f kx x x2 of
                     Nothing -> link2 l' r'
                     Just !x' -> link kx x' l' r'
      where
        (l2, found, r2) = splitLookup kx t2
        l' = go l1 l2
        r' = go r1 r2
{-# INLINE mergeWithKey #-}

{--------------------------------------------------------------------
  Filter and partition
--------------------------------------------------------------------}

-- | \(O(n)\). Map values and collect the 'Just' results.
--
-- > let f x = if x == "a" then Just "new a" else Nothing
-- > mapMaybe f (fromList [(5,"a"), (3,"b")]) == singleton 5 "new a"

mapMaybe :: (a -> Maybe b) -> Map k a -> Map k b
mapMaybe f = mapMaybeWithKey (\_ x -> f x)

-- | \(O(n)\). Map keys\/values and collect the 'Just' results.
--
-- > let f k _ = if k < 5 then Just ("key : " ++ (show k)) else Nothing
-- > mapMaybeWithKey f (fromList [(5,"a"), (3,"b")]) == singleton 3 "key : 3"

mapMaybeWithKey :: (k -> a -> Maybe b) -> Map k a -> Map k b
mapMaybeWithKey _ Tip = Tip
mapMaybeWithKey f (Bin _ kx x l r) = case f kx x of
  Just y  -> y `seq` link kx y (mapMaybeWithKey f l) (mapMaybeWithKey f r)
  Nothing -> link2 (mapMaybeWithKey f l) (mapMaybeWithKey f r)

-- | \(O(n)\). Traverse keys\/values and collect the 'Just' results.
--
-- @since 0.5.8

traverseMaybeWithKey :: Applicative f
                     => (k -> a -> f (Maybe b)) -> Map k a -> f (Map k b)
traverseMaybeWithKey = go
  where
    go _ Tip = pure Tip
    go f (Bin _ kx x Tip Tip) = maybe Tip (\ !x' -> Bin 1 kx x' Tip Tip) <$> f kx x
    go f (Bin _ kx x l r) = liftA3 combine (go f l) (f kx x) (go f r)
      where
        combine !l' mx !r' = case mx of
          Nothing -> link2 l' r'
          Just !x' -> link kx x' l' r'

-- | \(O(n)\). Map values and separate the 'Left' and 'Right' results.
--
-- > let f a = if a < "c" then Left a else Right a
-- > mapEither f (fromList [(5,"a"), (3,"b"), (1,"x"), (7,"z")])
-- >     == (fromList [(3,"b"), (5,"a")], fromList [(1,"x"), (7,"z")])
-- >
-- > mapEither (\ a -> Right a) (fromList [(5,"a"), (3,"b"), (1,"x"), (7,"z")])
-- >     == (empty, fromList [(5,"a"), (3,"b"), (1,"x"), (7,"z")])

mapEither :: (a -> Either b c) -> Map k a -> (Map k b, Map k c)
mapEither f m
  = mapEitherWithKey (\_ x -> f x) m

-- | \(O(n)\). Map keys\/values and separate the 'Left' and 'Right' results.
--
-- > let f k a = if k < 5 then Left (k * 2) else Right (a ++ a)
-- > mapEitherWithKey f (fromList [(5,"a"), (3,"b"), (1,"x"), (7,"z")])
-- >     == (fromList [(1,2), (3,6)], fromList [(5,"aa"), (7,"zz")])
-- >
-- > mapEitherWithKey (\_ a -> Right a) (fromList [(5,"a"), (3,"b"), (1,"x"), (7,"z")])
-- >     == (empty, fromList [(1,"x"), (3,"b"), (5,"a"), (7,"z")])

mapEitherWithKey :: (k -> a -> Either b c) -> Map k a -> (Map k b, Map k c)
mapEitherWithKey f0 t0 = toPair $ go f0 t0
  where
    go _ Tip = (Tip :*: Tip)
    go f (Bin _ kx x l r) = case f kx x of
      Left y  -> y `seq` (link kx y l1 r1 :*: link2 l2 r2)
      Right z -> z `seq` (link2 l1 r1 :*: link kx z l2 r2)
     where
        (l1 :*: l2) = go f l
        (r1 :*: r2) = go f r

{--------------------------------------------------------------------
  Mapping
--------------------------------------------------------------------}
-- | \(O(n)\). Map a function over all values in the map.
--
-- > map (++ "x") (fromList [(5,"a"), (3,"b")]) == fromList [(3, "bx"), (5, "ax")]

map :: (a -> b) -> Map k a -> Map k b
map f = go
  where
    go Tip = Tip
    go (Bin sx kx x l r) = let !x' = f x in Bin sx kx x' (go l) (go r)
-- We use `go` to let `map` inline. This is important if `f` is a constant
-- function.

#ifdef __GLASGOW_HASKELL__
{-# NOINLINE [1] map #-}
{-# RULES
"map/map" forall f g xs . map f (map g xs) = map (\x -> f $! g x) xs
"map/mapL" forall f g xs . map f (L.map g xs) = map (\x -> f (g x)) xs
 #-}
#endif

-- | \(O(n)\). Map a function over all values in the map.
--
-- > let f key x = (show key) ++ ":" ++ x
-- > mapWithKey f (fromList [(5,"a"), (3,"b")]) == fromList [(3, "3:b"), (5, "5:a")]

mapWithKey :: (k -> a -> b) -> Map k a -> Map k b
mapWithKey _ Tip = Tip
mapWithKey f (Bin sx kx x l r) =
  let x' = f kx x
  in x' `seq` Bin sx kx x' (mapWithKey f l) (mapWithKey f r)

#ifdef __GLASGOW_HASKELL__
{-# NOINLINE [1] mapWithKey #-}
{-# RULES
"mapWithKey/mapWithKey" forall f g xs . mapWithKey f (mapWithKey g xs) =
  mapWithKey (\k a -> f k $! g k a) xs
"mapWithKey/mapWithKeyL" forall f g xs . mapWithKey f (L.mapWithKey g xs) =
  mapWithKey (\k a -> f k (g k a)) xs
"mapWithKey/map" forall f g xs . mapWithKey f (map g xs) =
  mapWithKey (\k a -> f k $! g a) xs
"mapWithKey/mapL" forall f g xs . mapWithKey f (L.map g xs) =
  mapWithKey (\k a -> f k (g a)) xs
"map/mapWithKey" forall f g xs . map f (mapWithKey g xs) =
  mapWithKey (\k a -> f $! g k a) xs
"map/mapWithKeyL" forall f g xs . map f (L.mapWithKey g xs) =
  mapWithKey (\k a -> f (g k a)) xs
 #-}
#endif

-- | \(O(n)\).
-- @'traverseWithKey' f m == 'fromList' \<$\> 'traverse' (\\(k, v) -> (\v' -> v' \`seq\` (k,v')) \<$\> f k v) ('toList' m)@
-- That is, it behaves much like a regular 'traverse' except that the traversing
-- function also has access to the key associated with a value and the values are
-- forced before they are installed in the result map.
--
-- > traverseWithKey (\k v -> if odd k then Just (succ v) else Nothing) (fromList [(1, 'a'), (5, 'e')]) == Just (fromList [(1, 'b'), (5, 'f')])
-- > traverseWithKey (\k v -> if odd k then Just (succ v) else Nothing) (fromList [(2, 'c')])           == Nothing
traverseWithKey :: Applicative t => (k -> a -> t b) -> Map k a -> t (Map k b)
traverseWithKey f = go
  where
    go Tip = pure Tip
    go (Bin 1 k v _ _) = (\ !v' -> Bin 1 k v' Tip Tip) <$> f k v
    go (Bin s k v l r) = liftA3 (\ l' !v' r' -> Bin s k v' l' r') (go l) (f k v) (go r)
{-# INLINE traverseWithKey #-}

-- | \(O(n)\). The function 'mapAccum' threads an accumulating
-- argument through the map in ascending order of keys.
--
-- > let f a b = (a ++ b, b ++ "X")
-- > mapAccum f "Everything: " (fromList [(5,"a"), (3,"b")]) == ("Everything: ba", fromList [(3, "bX"), (5, "aX")])

mapAccum :: (a -> b -> (a,c)) -> a -> Map k b -> (a,Map k c)
mapAccum f a m
  = mapAccumWithKey (\a' _ x' -> f a' x') a m

-- | \(O(n)\). The function 'mapAccumWithKey' threads an accumulating
-- argument through the map in ascending order of keys.
--
-- > let f a k b = (a ++ " " ++ (show k) ++ "-" ++ b, b ++ "X")
-- > mapAccumWithKey f "Everything:" (fromList [(5,"a"), (3,"b")]) == ("Everything: 3-b 5-a", fromList [(3, "bX"), (5, "aX")])

mapAccumWithKey :: (a -> k -> b -> (a,c)) -> a -> Map k b -> (a,Map k c)
mapAccumWithKey f a t
  = mapAccumL f a t

-- | \(O(n)\). The function 'mapAccumL' threads an accumulating
-- argument through the map in ascending order of keys.
mapAccumL :: (a -> k -> b -> (a,c)) -> a -> Map k b -> (a,Map k c)
mapAccumL _ a Tip               = (a,Tip)
mapAccumL f a (Bin sx kx x l r) =
  let (a1,l') = mapAccumL f a l
      (a2,x') = f a1 kx x
      (a3,r') = mapAccumL f a2 r
  in x' `seq` (a3,Bin sx kx x' l' r')

-- | \(O(n)\). The function 'mapAccumRWithKey' threads an accumulating
-- argument through the map in descending order of keys.
mapAccumRWithKey :: (a -> k -> b -> (a,c)) -> a -> Map k b -> (a,Map k c)
mapAccumRWithKey _ a Tip = (a,Tip)
mapAccumRWithKey f a (Bin sx kx x l r) =
  let (a1,r') = mapAccumRWithKey f a r
      (a2,x') = f a1 kx x
      (a3,l') = mapAccumRWithKey f a2 l
  in x' `seq` (a3,Bin sx kx x' l' r')

-- | \(O(n \log n)\).
-- @'mapKeysWith' c f s@ is the map obtained by applying @f@ to each key of @s@.
--
-- If `f` is monotonically non-decreasing, this function takes \(O(n)\) time.
--
-- The size of the result may be smaller if @f@ maps two or more distinct
-- keys to the same new key.  In this case the associated values will be
-- combined using @c@. The value at the greater of the two original keys
-- is used as the first argument to @c@.
--
-- > mapKeysWith (++) (\ _ -> 1) (fromList [(1,"b"), (2,"a"), (3,"d"), (4,"c")]) == singleton 1 "cdab"
-- > mapKeysWith (++) (\ _ -> 3) (fromList [(1,"b"), (2,"a"), (3,"d"), (4,"c")]) == singleton 3 "cdab"
--
-- Also see the performance note on 'fromListWith'.

mapKeysWith :: Ord k2 => (a -> a -> a) -> (k1->k2) -> Map k1 a -> Map k2 a
mapKeysWith c f m =
  finishB (foldlWithKey' (\b kx x -> insertWithB c (f kx) x b) emptyB m)
#if __GLASGOW_HASKELL__
{-# INLINABLE mapKeysWith #-}
#endif

{--------------------------------------------------------------------
  Conversions
--------------------------------------------------------------------}

-- | \(O(n)\). Build a map from a set of keys and a function which for each key
-- computes its value.
--
-- > fromSet (\k -> replicate k 'a') (Data.Set.fromList [3, 5]) == fromList [(5,"aaaaa"), (3,"aaa")]
-- > fromSet undefined Data.Set.empty == empty

fromSet :: (k -> a) -> Set.Set k -> Map k a
fromSet _ Set.Tip = Tip
fromSet f (Set.Bin sz x l r) = case f x of v -> v `seq` Bin sz x v (fromSet f l) (fromSet f r)

-- | \(O(n)\). Build a map from a set of elements contained inside 'Arg's.
--
-- > fromArgSet (Data.Set.fromList [Arg 3 "aaa", Arg 5 "aaaaa"]) == fromList [(5,"aaaaa"), (3,"aaa")]
-- > fromArgSet Data.Set.empty == empty

fromArgSet :: Set.Set (Arg k a) -> Map k a
fromArgSet Set.Tip = Tip
fromArgSet (Set.Bin sz (Arg x v) l r) = v `seq` Bin sz x v (fromArgSet l) (fromArgSet r)

{--------------------------------------------------------------------
  Lists
--------------------------------------------------------------------}
-- | \(O(n \log n)\). Build a map from a list of key\/value pairs. See also 'fromAscList'.
-- If the list contains more than one value for the same key, the last value
-- for the key is retained.
--
-- If the keys are in non-decreasing order, this function takes \(O(n)\) time.
--
-- > fromList [] == empty
-- > fromList [(5,"a"), (3,"b"), (5, "c")] == fromList [(5,"c"), (3,"b")]
-- > fromList [(5,"c"), (3,"b"), (5, "a")] == fromList [(5,"a"), (3,"b")]

fromList :: Ord k => [(k,a)] -> Map k a
fromList xs =
  finishB (Foldable.foldl' (\b (kx, !x) -> insertB kx x b) emptyB xs)
{-# INLINE fromList #-} -- INLINE for fusion

-- | \(O(n \log n)\). Build a map from a list of key\/value pairs with a combining function. See also 'fromAscListWith'.
--
-- If the keys are in non-decreasing order, this function takes \(O(n)\) time.
--
-- > fromListWith (++) [(5,"a"), (5,"b"), (3,"x"), (5,"c")] == fromList [(3, "x"), (5, "cba")]
-- > fromListWith (++) [] == empty
--
-- Note the reverse ordering of @"cba"@ in the example.
--
-- The symmetric combining function @f@ is applied in a left-fold over the list, as @f new old@.
--
-- === Performance
--
-- You should ensure that the given @f@ is fast with this order of arguments.
--
-- Symmetric functions may be slow in one order, and fast in another.
-- For the common case of collecting values of matching keys in a list, as above:
--
-- The complexity of @(++) a b@ is \(O(a)\), so it is fast when given a short list as its first argument.
-- Thus:
--
-- > fromListWith       (++)  (replicate 1000000 (3, "x"))   -- O(n),  fast
-- > fromListWith (flip (++)) (replicate 1000000 (3, "x"))   -- O(n²), extremely slow
--
-- because they evaluate as, respectively:
--
-- > fromList [(3, "x" ++ ("x" ++ "xxxxx..xxxxx"))]   -- O(n)
-- > fromList [(3, ("xxxxx..xxxxx" ++ "x") ++ "x")]   -- O(n²)
--
-- Thus, to get good performance with an operation like @(++)@ while also preserving
-- the same order as in the input list, reverse the input:
--
-- > fromListWith (++) (reverse [(5,"a"), (5,"b"), (5,"c")]) == fromList [(5, "abc")]
--
-- and it is always fast to combine singleton-list values @[v]@ with @fromListWith (++)@, as in:
--
-- > fromListWith (++) $ reverse $ map (\(k, v) -> (k, [v])) someListOfTuples

fromListWith :: Ord k => (a -> a -> a) -> [(k,a)] -> Map k a
fromListWith f xs =
  finishB (Foldable.foldl' (\b (kx, x) -> insertWithB f kx x b) emptyB xs)
{-# INLINE fromListWith #-}  -- INLINE for fusion

-- | \(O(n \log n)\). Build a map from a list of key\/value pairs with a combining function. See also 'fromAscListWithKey'.
--
-- If the keys are in non-decreasing order, this function takes \(O(n)\) time.
--
-- > let f key new_value old_value = show key ++ ":" ++ new_value ++ "|" ++ old_value
-- > fromListWithKey f [(5,"a"), (5,"b"), (3,"b"), (3,"a"), (5,"c")] == fromList [(3, "3:a|b"), (5, "5:c|5:b|a")]
-- > fromListWithKey f [] == empty
--
-- Also see the performance note on 'fromListWith'.

fromListWithKey :: Ord k => (k -> a -> a -> a) -> [(k,a)] -> Map k a
fromListWithKey f xs =
  finishB (Foldable.foldl' (\b (kx, x) -> insertWithB (f kx) kx x b) emptyB xs)
{-# INLINE fromListWithKey #-}  -- INLINE for fusion

{--------------------------------------------------------------------
  Building trees from ascending/descending lists can be done in linear time.

  Note that if [xs] is ascending then:
    fromAscList xs       == fromList xs
    fromAscListWith f xs == fromListWith f xs

  If [xs] is descending then:
    fromDescList xs       == fromList xs
    fromDescListWith f xs == fromListWith f xs
--------------------------------------------------------------------}

-- | \(O(n)\). Build a map from an ascending list in linear time.
--
-- __Warning__: This function should be used only if the keys are in
-- non-decreasing order. This precondition is not checked. Use 'fromList' if the
-- precondition may not hold.
--
-- > fromAscList [(3,"b"), (5,"a")]          == fromList [(3, "b"), (5, "a")]
-- > fromAscList [(3,"b"), (5,"a"), (5,"b")] == fromList [(3, "b"), (5, "b")]
-- > valid (fromAscList [(3,"b"), (5,"a"), (5,"b")]) == True
-- > valid (fromAscList [(5,"a"), (3,"b"), (5,"b")]) == False
fromAscList :: Eq k => [(k,a)] -> Map k a
fromAscList xs
  = fromAscListWithKey (\_ x _ -> x) xs
{-# INLINE fromAscList #-}  -- INLINE for fusion

-- | \(O(n)\). Build a map from a descending list in linear time.
--
-- __Warning__: This function should be used only if the keys are in
-- non-increasing order. This precondition is not checked. Use 'fromList' if the
-- precondition may not hold.
--
-- > fromDescList [(5,"a"), (3,"b")]          == fromList [(3, "b"), (5, "a")]
-- > fromDescList [(5,"a"), (5,"b"), (3,"a")] == fromList [(3, "b"), (5, "b")]
-- > valid (fromDescList [(5,"a"), (5,"b"), (3,"b")]) == True
-- > valid (fromDescList [(5,"a"), (3,"b"), (5,"b")]) == False
fromDescList :: Eq k => [(k,a)] -> Map k a
fromDescList xs
  = fromDescListWithKey (\_ x _ -> x) xs
{-# INLINE fromDescList #-}  -- INLINE for fusion

-- | \(O(n)\). Build a map from an ascending list in linear time with a combining function for equal keys.
--
-- __Warning__: This function should be used only if the keys are in
-- non-decreasing order. This precondition is not checked. Use 'fromListWith' if
-- the precondition may not hold.
--
-- > fromAscListWith (++) [(3,"b"), (5,"a"), (5,"b")] == fromList [(3, "b"), (5, "ba")]
-- > valid (fromAscListWith (++) [(3,"b"), (5,"a"), (5,"b")]) == True
-- > valid (fromAscListWith (++) [(5,"a"), (3,"b"), (5,"b")]) == False
--
-- Also see the performance note on 'fromListWith'.

fromAscListWith :: Eq k => (a -> a -> a) -> [(k,a)] -> Map k a
fromAscListWith f xs
  = fromAscListWithKey (\_ x y -> f x y) xs
{-# INLINE fromAscListWith #-}  -- INLINE for fusion

-- | \(O(n)\). Build a map from a descending list in linear time with a combining function for equal keys.
--
-- __Warning__: This function should be used only if the keys are in
-- non-increasing order. This precondition is not checked. Use 'fromListWith' if
-- the precondition may not hold.
--
-- > fromDescListWith (++) [(5,"a"), (5,"b"), (3,"b")] == fromList [(3, "b"), (5, "ba")]
-- > valid (fromDescListWith (++) [(5,"a"), (5,"b"), (3,"b")]) == True
-- > valid (fromDescListWith (++) [(5,"a"), (3,"b"), (5,"b")]) == False
--
-- Also see the performance note on 'fromListWith'.

fromDescListWith :: Eq k => (a -> a -> a) -> [(k,a)] -> Map k a
fromDescListWith f xs
  = fromDescListWithKey (\_ x y -> f x y) xs
{-# INLINE fromDescListWith #-}  -- INLINE for fusion

-- | \(O(n)\). Build a map from an ascending list in linear time with a
-- combining function for equal keys.
--
-- __Warning__: This function should be used only if the keys are in
-- non-decreasing order. This precondition is not checked. Use 'fromListWithKey'
-- if the precondition may not hold.
--
-- > let f k a1 a2 = (show k) ++ ":" ++ a1 ++ a2
-- > fromAscListWithKey f [(3,"b"), (5,"a"), (5,"b"), (5,"b")] == fromList [(3, "b"), (5, "5:b5:ba")]
-- > valid (fromAscListWithKey f [(3,"b"), (5,"a"), (5,"b"), (5,"b")]) == True
-- > valid (fromAscListWithKey f [(5,"a"), (3,"b"), (5,"b"), (5,"b")]) == False
--
-- Also see the performance note on 'fromListWith'.

fromAscListWithKey :: Eq k => (k -> a -> a -> a) -> [(k,a)] -> Map k a
fromAscListWithKey f xs = ascLinkAll (Foldable.foldl' next Nada xs)
  where
    next stk (!ky, y) = case stk of
      Push kx x l stk'
        | ky == kx -> let !y' = f ky y x in Push ky y' l stk'
        | Tip <- l -> y `seq` ascLinkTop stk' 1 (singleton kx x) ky y
        | otherwise -> push ky y Tip stk
      Nada -> push ky y Tip stk
    push kx !x = Push kx x
{-# INLINE fromAscListWithKey #-}  -- INLINE for fusion

-- | \(O(n)\). Build a map from a descending list in linear time with a
-- combining function for equal keys.
--
-- __Warning__: This function should be used only if the keys are in
-- non-increasing order. This precondition is not checked. Use 'fromListWithKey'
-- if the precondition may not hold.
--
-- > let f k a1 a2 = (show k) ++ ":" ++ a1 ++ a2
-- > fromDescListWithKey f [(5,"a"), (5,"b"), (5,"b"), (3,"b")] == fromList [(3, "b"), (5, "5:b5:ba")]
-- > valid (fromDescListWithKey f [(5,"a"), (5,"b"), (5,"b"), (3,"b")]) == True
-- > valid (fromDescListWithKey f [(5,"a"), (3,"b"), (5,"b"), (5,"b")]) == False
--
-- Also see the performance note on 'fromListWith'.

fromDescListWithKey :: Eq k => (k -> a -> a -> a) -> [(k,a)] -> Map k a
fromDescListWithKey f xs = descLinkAll (Foldable.foldl' next Nada xs)
  where
    next stk (!ky, y) = case stk of
      Push kx x r stk'
        | ky == kx -> let !y' = f ky y x in Push ky y' r stk'
        | Tip <- r -> y `seq` descLinkTop ky y 1 (singleton kx x) stk'
        | otherwise -> push ky y Tip stk
      Nada -> push ky y Tip stk
    push kx !x = Push kx x
{-# INLINE fromDescListWithKey #-}  -- INLINE for fusion

-- | \(O(n)\). Build a map from an ascending list of distinct elements in linear time.
--
-- __Warning__: This function should be used only if the keys are in
-- strictly increasing order. This precondition is not checked. Use 'fromList'
-- if the precondition may not hold.
--
-- > fromDistinctAscList [(3,"b"), (5,"a")] == fromList [(3, "b"), (5, "a")]
-- > valid (fromDistinctAscList [(3,"b"), (5,"a")])          == True
-- > valid (fromDistinctAscList [(3,"b"), (5,"a"), (5,"b")]) == False

-- See Note [fromDistinctAscList implementation] in Data.Set.Internal.
fromDistinctAscList :: [(k,a)] -> Map k a
fromDistinctAscList xs = ascLinkAll (Foldable.foldl' next Nada xs)
  where
    next :: Stack k a -> (k, a) -> Stack k a
    next (Push kx x Tip stk) (!ky, !y) = ascLinkTop stk 1 (singleton kx x) ky y
    next stk (!kx, !x) = Push kx x Tip stk
{-# INLINE fromDistinctAscList #-}  -- INLINE for fusion

-- | \(O(n)\). Build a map from a descending list of distinct elements in linear time.
--
-- __Warning__: This function should be used only if the keys are in
-- strictly decreasing order. This precondition is not checked. Use 'fromList'
-- if the precondition may not hold.
--
-- > fromDistinctDescList [(5,"a"), (3,"b")] == fromList [(3, "b"), (5, "a")]
-- > valid (fromDistinctDescList [(5,"a"), (3,"b")])          == True
-- > valid (fromDistinctDescList [(5,"a"), (3,"b"), (3,"a")]) == False

-- See Note [fromDistinctAscList implementation] in Data.Set.Internal.
fromDistinctDescList :: [(k,a)] -> Map k a
fromDistinctDescList xs = descLinkAll (Foldable.foldl' next Nada xs)
  where
    next :: Stack k a -> (k, a) -> Stack k a
    next (Push ky y Tip stk) (!kx, !x) = descLinkTop kx x 1 (singleton ky y) stk
    next stk (!ky, !y) = Push ky y Tip stk
{-# INLINE fromDistinctDescList #-}  -- INLINE for fusion

{--------------------------------------------------------------------
  MapBuilder
--------------------------------------------------------------------}

-- Insert a key and value. The new value is combined with the old value if one
-- already exists for the key. Strict in the inserted value.
insertWithB
  :: Ord k => (a -> a -> a) -> k -> a -> MapBuilder k a -> MapBuilder k a
insertWithB f !ky y b = case b of
  BAsc stk -> case stk of
    Push kx x l stk' -> case compare ky kx of
      LT -> BMap (insertWith f ky y (ascLinkAll stk))
      EQ -> BAsc (push' ky (f y x) l stk')
      GT -> case l of
        Tip -> y `seq` BAsc (ascLinkTop stk' 1 (singleton kx x) ky y)
        Bin{} -> BAsc (push' ky y Tip stk)
    Nada -> BAsc (push' ky y Tip Nada)
  BMap m -> BMap (insertWith f ky y m)
  where
    push' kx !x = Push kx x
{-# INLINE insertWithB #-}
