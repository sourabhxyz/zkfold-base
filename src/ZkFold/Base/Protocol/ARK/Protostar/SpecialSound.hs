{-# LANGUAGE AllowAmbiguousTypes #-}

module ZkFold.Base.Protocol.ARK.Protostar.SpecialSound where

import           Numeric.Natural                              (Natural)
import           Prelude                                      hiding (length)

import           ZkFold.Base.Algebra.Polynomials.Multivariate (Polynomial')
import           ZkFold.Base.Data.Vector                      (Vector)
import           ZkFold.Symbolic.Compiler.Arithmetizable      (Arithmetic)

type SpecialSoundTranscript t a = [(ProverMessage t a, VerifierMessage t a)]

class Arithmetic f => SpecialSoundProtocol f a where
      type Witness f a
      type Input f a
      type ProverMessage t a
      type VerifierMessage t a

      type Dimension a :: Natural
      -- ^ l in the paper
      type Degree a :: Natural
      -- ^ d in the paper

      rounds :: a -> Natural
      -- ^ k in the paper

      prover :: a -> Witness f a -> Input f a -> SpecialSoundTranscript f a -> ProverMessage f a

      verifier' :: a -> Input f a -> SpecialSoundTranscript Natural a
            -> Vector (Dimension a) (Polynomial' f)

      verifier :: a -> Input f a -> SpecialSoundTranscript f a -> Bool

