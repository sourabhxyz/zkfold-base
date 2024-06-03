{-# LANGUAGE AllowAmbiguousTypes #-}

module ZkFold.Symbolic.Compiler.ArithmeticCircuit.Map (
        mapVarArithmeticCircuit,
        mapVarWitness
    ) where

import           Data.Containers.ListUtils                           (nubOrd)
import           Data.List                                           (sort)
import           Data.Map                                            hiding (drop, foldl, foldr, fromList, map, null,
                                                                      splitAt, take, toList)
import           GHC.IsList                                          (IsList (..))
import           Numeric.Natural                                     (Natural)
import           Prelude                                             hiding (Num (..), drop, length, product, splitAt,
                                                                      sum, take, (!!), (^))

import           ZkFold.Base.Algebra.Basic.Class                     (MultiplicativeMonoid (..))
import           ZkFold.Base.Algebra.Polynomials.Multivariate
import           ZkFold.Symbolic.Compiler.ArithmeticCircuit.Internal (ArithmeticCircuit (..), Circuit (..))

-- This module contains functions for mapping variables in arithmetic circuits.

mapVarWitness :: [Natural] -> (Map Natural a -> Map Natural a)
mapVarWitness vars = mapKeys (mapVar vars)

mapVarArithmeticCircuit :: MultiplicativeMonoid a => ArithmeticCircuit n a -> ArithmeticCircuit n a
mapVarArithmeticCircuit (ArithmeticCircuit ac out) =
    let vars = nubOrd $ sort $ 0 : concatMap (toList . variables) (elems $ acSystem ac)
        mappedCircuit = ac
            {
                acSystem  = fromList $ zip [0..] $ mapVarPolynomial vars <$> elems (acSystem ac),
                -- TODO: the new arithmetic circuit expects the old input variables! We should make this safer.
                acWitness = mapVarWitness vars . acWitness ac
            }
        mappedOutputs = mapVar vars <$> out
     in ArithmeticCircuit mappedCircuit mappedOutputs

