{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DerivingVia         #-}
{-# LANGUAGE TypeApplications    #-}

module ZkFold.Symbolic.Data.Ord (Ord (..), Lexicographical (..), circuitGE, circuitGT, getBitsBE) where

import qualified Data.Bool                                              as Haskell
import           Prelude                                                (reverse, zipWith, ($), (.))
import qualified Prelude                                                as Haskell

import           ZkFold.Base.Algebra.Basic.Class
import           ZkFold.Base.Algebra.Basic.Field                        (Zp)
import           ZkFold.Base.Algebra.Basic.Number                       (Prime, KnownNat)
import           ZkFold.Symbolic.Compiler
import           ZkFold.Symbolic.Compiler.ArithmeticCircuit.Combinators (boolCheckC)
import           ZkFold.Symbolic.Data.Bool                              (Bool (..), BoolType (..))
import           ZkFold.Symbolic.Data.Conditional                       (Conditional (..))
import           ZkFold.Symbolic.Data.DiscreteField                     (DiscreteField (..))

-- TODO (Issue #23): add `compare`
class Ord b a where
    (<=) :: a -> a -> b

    (<) :: a -> a -> b

    (>=) :: a -> a -> b

    (>) :: a -> a -> b

    max :: a -> a -> a
    -- max x y = bool @b y x $ x <= y

    min :: a -> a -> a
    -- min x y = bool @b y x $ x >= y

instance Haskell.Ord a => Ord Haskell.Bool a where
    (<=) = (Haskell.<=)

    (<) = (Haskell.<)

    (>=) = (Haskell.>=)

    (>) = (Haskell.>)

    max = Haskell.max

    min = Haskell.min

instance (Prime p, Haskell.Ord x) => Ord (Bool (Zp p)) x where
    x <= y = Bool $ Haskell.bool zero one (x Haskell.<= y)

    x <  y = Bool $ Haskell.bool zero one (x Haskell.<  y)

    x >= y = Bool $ Haskell.bool zero one (x Haskell.>= y)

    x >  y = Bool $ Haskell.bool zero one (x Haskell.>  y)

    max x y = Haskell.bool x y $ x <= y

    min x y = Haskell.bool x y $ x >= y

newtype Lexicographical a = Lexicographical a
-- ^ A newtype wrapper for easy definition of Ord instances
-- (though not necessarily a most effective one)

deriving newtype instance SymbolicData a 1 x => SymbolicData a 1 (Lexicographical x)

deriving via (Lexicographical (ArithmeticCircuit 1 a))
    instance Arithmetic a => Ord (Bool (ArithmeticCircuit 1 a)) (ArithmeticCircuit 1 a)

-- | Every @SymbolicData@ type can be compared lexicographically.
instance SymbolicData a 1 x => Ord (Bool (ArithmeticCircuit 1 a)) (Lexicographical x) where
    x <= y = y >= x

    x <  y = y > x

    x >= y = circuitGE (getBitsBE x) (getBitsBE y)

    x > y = circuitGT (getBitsBE x) (getBitsBE y)

    max x y = bool @(Bool (ArithmeticCircuit 1 a)) x y $ x < y

    min x y = bool @(Bool (ArithmeticCircuit 1 a)) x y $ x > y

getBitsBE :: SymbolicData a 1 x => x -> [ArithmeticCircuit 1 a]
-- ^ @getBitsBE x@ returns a list of circuits computing bits of @x@, eldest to
-- youngest.
getBitsBE x = reverse . binaryExpansion $ pieces @_ @1 x

circuitGE :: Arithmetic a => [ArithmeticCircuit 1 a] -> [ArithmeticCircuit 1 a] -> Bool (ArithmeticCircuit 1 a)
-- ^ Given two lists of bits of equal length, compares them lexicographically.
circuitGE xs ys = bitCheckGE dor boolCheckC (zipWith (-) xs ys)

circuitGT :: Arithmetic a => [ArithmeticCircuit 1 a] -> [ArithmeticCircuit 1 a] -> Bool (ArithmeticCircuit 1 a)
-- ^ Given two lists of bits of equal length, compares them lexicographically.
circuitGT xs ys = bitCheckGT dor (zipWith (-) xs ys)

dor ::
  Arithmetic a =>
  KnownNat n =>
  Bool (ArithmeticCircuit n a) ->
  Bool (ArithmeticCircuit n a) ->
  Bool (ArithmeticCircuit n a)
-- ^ @dorAnd a b@ is a schema which computes @a || b@ given @a && b@ is false.
dor (Bool a) (Bool b) = Bool (a + b)

bitCheckGE :: DiscreteField b x => (b -> b -> b) -> (x -> x) -> [x] -> b
-- ^ @bitCheckGE pl bc ds@ checks if @ds@ contains delta lexicographically
-- greater than or equal to 0, given @pl a b = a || b@ when @a && b@ is false
-- and @bc d = d (d - 1)@.
bitCheckGE _  _  []     = true
bitCheckGE _  bc [d]    = isZero (bc d)
bitCheckGE pl bc (d:ds) = pl (isZero $ d - one) (isZero d && bitCheckGE pl bc ds)

bitCheckGT :: DiscreteField b x => (b -> b -> b) -> [x] -> b
-- ^ @bitCheckGT pl ds@ checks if @ds@ contains delta lexicographically greater
-- than 0, given @pl a b = a || b@ when @a && b@ is false.
bitCheckGT _  []     = false
bitCheckGT _  [d]    = isZero (d - one)
bitCheckGT pl (d:ds) = pl (isZero $ d - one) (isZero d && bitCheckGT pl ds)
