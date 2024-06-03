{-# LANGUAGE DeriveAnyClass   #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators    #-}

module ZkFold.Symbolic.Compiler.ArithmeticCircuit.Internal (
        ArithmeticCircuit(..),
        Circuit (..),
        Arithmetic,
        ConstraintMonomial,
        Constraint,

        constraintSystem,
        inputVariables,
        witnessGenerator,
        varOrder,
        -- low-level functions
        constraint,
        assignment,
        addVariable,
        newVariableWithSource,
        input,
        eval,
        apply,
        forceZero,
        joinCircuits,
        concatCircuits
    ) where

import           Control.DeepSeq                              (NFData)
import           Control.Monad.State                          (MonadState (..), State, modify)
import           Data.List                                    (nub)
import           Data.Map.Strict                              hiding (drop, foldl, foldr, map, null, splitAt, take)
import qualified Data.Zip                                     as Z
import           GHC.Generics
import           Numeric.Natural                              (Natural)
import           Optics
import           Prelude                                      hiding (Num (..), drop, length, product, splitAt, sum,
                                                               take, (!!), (^))
import qualified Prelude                                      as Haskell
import           System.Random                                (StdGen, mkStdGen, uniform, uniformR)

import           ZkFold.Base.Algebra.Basic.Class
import           ZkFold.Base.Algebra.Basic.Field              (Zp, fromZp, toZp)
import           ZkFold.Base.Algebra.Basic.Number
import           ZkFold.Base.Algebra.EllipticCurve.BLS12_381  (BLS12_381_Scalar)
import           ZkFold.Base.Algebra.Polynomials.Multivariate (Monomial', Polynomial', evalMapM, evalPolynomial,
                                                               mapCoeffs, var)
import qualified ZkFold.Base.Data.Vector                      as V
import           ZkFold.Base.Data.Vector                      (Vector (..))
import           ZkFold.Prelude                               (drop, length)

    {--
-- | Arithmetic circuit in the form of a system of polynomial constraints.
data ArithmeticCircuit a = ArithmeticCircuit
    {
        acSystem   :: Map Natural (Constraint a),
        -- ^ The system of polynomial constraints
        acInput    :: [Natural],
        -- ^ The input variables
        acWitness  :: Map Natural a -> Map Natural a,
        -- ^ The witness generation function
        acOutput   :: Natural,
        -- ^ The output variable
        acVarOrder :: Map (Natural, Natural) Natural,
        -- ^ The order of variable assignments
        acRNG      :: StdGen
    } deriving (Generic, NFData)
--}

data Circuit a = Circuit
    {
        acSystem   :: Map Natural (Constraint a),
        -- ^ The system of polynomial constraints
        acInput    :: [Natural],
        -- ^ The input variables
        acWitness  :: Map Natural a -> Map Natural a,
        -- ^ The witness generation function
        acVarOrder :: Map (Natural, Natural) Natural,
        -- ^ The order of variable assignments
        acRNG      :: StdGen
    } deriving (Generic, NFData)

data ArithmeticCircuit n a = ArithmeticCircuit
  { acCircuit :: Circuit a
  , acOutput  :: Vector n Natural
  } deriving (Generic, NFData)

constraintSystem :: ArithmeticCircuit n a -> Map Natural (Constraint a)
constraintSystem = acSystem . acCircuit

inputVariables :: ArithmeticCircuit n a -> [Natural]
inputVariables = acInput . acCircuit

witnessGenerator :: ArithmeticCircuit n a -> Map Natural a -> Map Natural a
witnessGenerator = acWitness . acCircuit

varOrder :: ArithmeticCircuit n a -> Map (Natural, Natural) Natural
varOrder = acVarOrder . acCircuit

----------------------------------- Circuit monoid ----------------------------------

instance Eq a => Semigroup (Circuit a) where
    c1 <> c2 =
        Circuit
           {
               acSystem   = acSystem c1 `union` acSystem c2
               -- NOTE: is it possible that we get a wrong argument order when doing `apply` because of this concatenation?
               -- We need a way to ensure the correct order no matter how `(<>)` is used.
           ,   acInput    = nub $ acInput c1 ++ acInput c2
           ,   acWitness  = union <$> acWitness c1 <*> acWitness c2
           ,   acVarOrder = acVarOrder c1 `union` acVarOrder c2
           ,   acRNG      = mkStdGen $ fst (uniform (acRNG c1)) Haskell.* fst (uniform (acRNG c2))
           }

instance (Eq a, MultiplicativeMonoid a) => Monoid (Circuit a) where
    mempty =
        Circuit
           {
               acSystem   = empty,
               acInput    = [],
               acWitness  = insert 0 one,
               acVarOrder = empty,
               acRNG      = mkStdGen 0
           }

instance Eq a => Semigroup (ArithmeticCircuit n a) where
    r1 <> r2 =
        ArithmeticCircuit
            {
                acCircuit = acCircuit r1 <> acCircuit r2
            ,   acOutput  = Z.zipWith max (acOutput r1) (acOutput r2)
            }

instance (KnownNat n, Eq a, MultiplicativeMonoid a) => Monoid (ArithmeticCircuit n a) where
    mempty =
        ArithmeticCircuit
            {
                acCircuit = mempty
            ,   acOutput  = Vector (replicate (fromIntegral $ value @n) 0)
            }

joinCircuits :: Eq a => ArithmeticCircuit ol a -> ArithmeticCircuit or a -> ArithmeticCircuit (ol + or) a
joinCircuits r1 r2 =
    ArithmeticCircuit
        {
            acCircuit = acCircuit r1 <> acCircuit r2
        ,   acOutput = (acOutput r1 `V.append` acOutput r2)
        }

concatCircuits :: (Eq a, MultiplicativeMonoid a) => Vector n (ArithmeticCircuit m a) -> ArithmeticCircuit (n * m) a
concatCircuits cs =
    ArithmeticCircuit
        {
            acCircuit = mconcat . V.fromVector $ acCircuit <$> cs
        ,   acOutput = V.concat $ acOutput <$> cs
        }

------------------------------------- Variables -------------------------------------

-- | A finite field of a large order.
-- It is used in the compiler for generating new variable indices.
type VarField = Zp BLS12_381_Scalar

toField :: Arithmetic a => a -> VarField
toField = toZp . fromConstant . fromBinary @Natural . castBits . binaryExpansion

type Arithmetic a = (FiniteField a, Eq a, BinaryExpansion a)

-- TODO: Remove the hardcoded constant.
toVar :: forall a . Arithmetic a => [Natural] -> Constraint a -> Natural
toVar srcs c = fromZp ex
    where
        r  = toZp 903489679376934896793395274328947923579382759823 :: VarField
        g  = toZp 89175291725091202781479751781509570912743212325 :: VarField
        v  = (+ r) . fromConstant
        x  = g ^ fromZp (evalPolynomial evalMapM v $ mapCoeffs toField c)
        ex = foldr (\p y -> x ^ p + y) x srcs

newVariableWithSource :: Arithmetic a => [Natural] -> (Natural -> Constraint a) -> State (ArithmeticCircuit n a) Natural
newVariableWithSource srcs con = toVar srcs . con . fst <$> do
    zoom #acCircuit . zoom #acRNG $ get >>= traverse put . uniformR (0, order @VarField -! 1)

addVariable :: Natural -> State (ArithmeticCircuit n a) Natural
addVariable x = do
    zoom #acCircuit . zoom #acVarOrder . modify
        $ \vo -> insert (length vo, x) x vo
    pure x

---------------------------------- Low-level functions --------------------------------

type ConstraintMonomial = Monomial'

-- | The type that represents a constraint in the arithmetic circuit.
type Constraint c = Polynomial' c

-- | Adds a constraint to the arithmetic circuit.
constraint :: Arithmetic a => Constraint a -> State (ArithmeticCircuit n a) ()
constraint c = zoom #acCircuit . zoom #acSystem . modify $ insert (toVar [] c) c

-- | Forces the current variable to be zero.
forceZero :: forall n a . Arithmetic a => State (ArithmeticCircuit n a) ()
forceZero = zoom #acOutput get >>= mapM_ (constraint . var)

-- | Adds a new variable assignment to the arithmetic circuit.
-- TODO: forbid reassignment of variables
assignment :: Natural -> (Map Natural a -> a) -> State (ArithmeticCircuit n a) ()
assignment i f = zoom #acCircuit . zoom #acWitness . modify $ (.) (\m -> insert i (f m) m)

-- | Adds a new input variable to the arithmetic circuit.
input :: forall n a . State (ArithmeticCircuit n a) Natural
input = do
  inputs <- zoom #acCircuit $ zoom #acInput get
  let s = if null inputs then 1 else maximum inputs + 1
  zoom #acCircuit . zoom #acInput $ modify (++ [s])
  zoom #acCircuit . zoom #acVarOrder . modify
      $ \vo -> insert (length vo, s) s vo
  return s

-- | Evaluates the arithmetic circuit using the supplied input map.
eval :: ArithmeticCircuit n a -> Map Natural a -> Vector n a
eval ctx i = (witness !) <$> acOutput ctx
    where
        witness = acWitness (acCircuit ctx) i

-- | Applies the values of the first `n` inputs to the arithmetic circuit.
-- TODO: make this safe
apply :: [a] -> State (ArithmeticCircuit n a) ()
apply xs = do
    inputs <- (acInput . acCircuit) <$> get
    zoom #acCircuit . zoom #acInput . put $ drop (length xs) inputs
    zoom #acCircuit . zoom #acWitness . modify $ (. union (fromList $ zip inputs xs))

-- TODO: Add proper symbolic application functions

-- applySymOne :: ArithmeticCircuit a -> State (ArithmeticCircuit a) ()
-- applySymOne x = modify (\(f :: ArithmeticCircuit a) ->
--     let ins = acInput f
--     in f
--     {
--         acInput = tail ins,
--         acWitness = acWitness f . (singleton (head ins) (eval x empty)  `union`)
--     })

-- applySym :: [ArithmeticCircuit a] -> State (ArithmeticCircuit a) ()
-- applySym = foldr ((>>) . applySymOne) (return ())

-- applySymArgs :: ArithmeticCircuit a -> [ArithmeticCircuit a] -> ArithmeticCircuit a
-- applySymArgs x xs = execState (applySym xs) x
