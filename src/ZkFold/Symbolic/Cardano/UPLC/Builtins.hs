{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE TypeApplications    #-}

module ZkFold.Symbolic.Cardano.UPLC.Builtins where

import           Data.Typeable                     (Proxy (..), Typeable)
import           Prelude                           (($))

import           ZkFold.Base.Algebra.Basic.Class
import           ZkFold.Symbolic.Cardano.UPLC.Type
import           ZkFold.Symbolic.Compiler          (Arithmetic, ArithmeticCircuit, SomeArithmetizable (..))

-- TODO: Add the actual builtins available on-chain in Plutus V3

-- | A class for built-in functions in Plutus.
class PlutusBuiltinFunction a fun where
    builtinFunctionType :: fun -> SomeType a
    builtinFunctionRep  :: fun -> SomeArithmetizable a

data BuiltinFunctions =
      AddField
    | MulField

-- TODO: use shortcuts to make these definitions more readable
instance forall a . (Arithmetic a, Typeable a) => PlutusBuiltinFunction a BuiltinFunctions where
    builtinFunctionType AddField =
          SomeFunction (SomeSym $ SomeData $ Proxy @(ArithmeticCircuit a))
        $ SomeFunction (SomeSym $ SomeData $ Proxy @(ArithmeticCircuit a))
        $ SomeSym $ SomeData $ Proxy @(ArithmeticCircuit a)
    builtinFunctionType MulField =
        SomeFunction (SomeSym $ SomeData $ Proxy @(ArithmeticCircuit a))
        $ SomeFunction (SomeSym $ SomeData $ Proxy @(ArithmeticCircuit a))
        $ SomeSym $ SomeData $ Proxy @(ArithmeticCircuit a)

    builtinFunctionRep AddField = SomeArithmetizable $ \(x :: ArithmeticCircuit a) (y :: ArithmeticCircuit a) -> x + y
    builtinFunctionRep MulField = SomeArithmetizable $ \(x :: ArithmeticCircuit a) (y :: ArithmeticCircuit a) -> x * y
