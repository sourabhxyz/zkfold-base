{-# LANGUAGE UndecidableInstances #-}

module ZkFold.Symbolic.Data.Maybe (
    Maybe, just, nothing, fromMaybe
) where

import           Data.Distributive
import           Data.Functor.Adjunction
import           Data.Functor.Rep
import qualified Prelude                         as Haskell

import           ZkFold.Base.Algebra.Basic.Class

data Maybe u a = Maybe {headMaybe :: a, tailMaybe :: u a}
  deriving stock
    ( Haskell.Eq
    , Haskell.Functor
    , Haskell.Foldable
    , Haskell.Traversable
    )

just :: Field a => u a -> Maybe u a
just = Maybe one

nothing
  :: forall a u. (Field a, Representable u)
  => Maybe u a
nothing = Maybe zero (tabulate (Haskell.const zero))

fromMaybe :: (Field a, Adjunction f u) => u a -> Maybe u a -> u a
fromMaybe a (Maybe h t) =
  Haskell.fmap (\(a',t') -> (t' - a') * h + a') (zipR (a, t))

instance Distributive u => Distributive (Maybe u) where
  distribute fmu = Maybe
    (Haskell.fmap headMaybe fmu)
    (distribute (Haskell.fmap tailMaybe fmu))

instance Representable u => Representable (Maybe u) where
  type Rep (Maybe u) = Haskell.Maybe (Rep u)
  tabulate g = Maybe
    (g Haskell.Nothing)
    (tabulate (g Haskell.. Haskell.Just))
  index (Maybe h _) Haskell.Nothing = h
  index (Maybe _ t) (Haskell.Just x) = index t x

data Maybe1 f a
  = Nothing1 a
  | Just1 (f a)
  deriving stock
    ( Haskell.Functor
    , Haskell.Foldable
    , Haskell.Traversable
    )

instance (Adjunction f u) => Adjunction (Maybe1 f) (Maybe u) where
  unit a = Maybe (Nothing1 a) (leftAdjunct Just1 a)
  counit (Nothing1 a) = headMaybe a
  counit (Just1 t) = rightAdjunct tailMaybe t