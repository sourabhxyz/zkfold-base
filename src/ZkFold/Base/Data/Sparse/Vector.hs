module ZkFold.Base.Data.Sparse.Vector where

import           Data.Map                         (Map, empty, filter)
import           Data.These                       (These (..))
import           Data.Zip                         (Semialign (..), Zip (..))
import           Prelude                          hiding (Num (..), filter, length, sum, zip, zipWith, (/))
import           Test.QuickCheck                  (Arbitrary (..))

import           ZkFold.Base.Algebra.Basic.Class
import           ZkFold.Base.Algebra.Basic.Field  (Zp)
import           ZkFold.Base.Algebra.Basic.Number (KnownNat)
import           ZkFold.Base.Data.ByteString      (ToByteString (..))

newtype SVector size a = SVector { fromSVector :: Map (Zp size) a }
    deriving (Show, Eq)

instance ToByteString a => ToByteString (SVector n a) where
    toByteString = toByteString . fromSVector

instance Foldable (SVector size) where
    foldr f z (SVector as) = foldr f z as

instance Functor (SVector size) where
    fmap f (SVector as) = SVector $ fmap f as

instance KnownNat size => Semialign (SVector size) where
    align (SVector as) (SVector bs) = SVector $ align as bs

    alignWith f (SVector as) (SVector bs) = SVector $ alignWith f as bs

instance KnownNat size => Zip (SVector size) where
    zip (SVector as) (SVector bs) = SVector $ zip as bs

    zipWith f (SVector as) (SVector bs) = SVector $ zipWith f as bs

instance (KnownNat size, Arbitrary a) => Arbitrary (SVector size a) where
    arbitrary = SVector <$> arbitrary

instance (KnownNat size, AdditiveMonoid a, Eq a) => AdditiveSemigroup (SVector size a) where
    va + vb = SVector $ filter (/= zero) $ fromSVector $ alignWith (\case
        This a -> a
        That b -> b
        These a b -> a + b) va vb

(.+) :: (KnownNat size, AdditiveMonoid a, Eq a) => SVector size a -> SVector size a -> SVector size a
(.+) = (+)

instance (KnownNat size, AdditiveMonoid a, Eq a) => AdditiveMonoid (SVector size a) where
    zero = SVector empty

instance (KnownNat size, AdditiveGroup a, Eq a) => AdditiveGroup (SVector size a) where
    negate = fmap negate

(.-) :: (KnownNat size, AdditiveGroup a, Eq a) => SVector size a -> SVector size a -> SVector size a
(.-) = (-)

(.*) :: (KnownNat size, MultiplicativeSemigroup a) => SVector size a -> SVector size a -> SVector size a
(.*) = zipWith (*)

(./) :: (KnownNat size, MultiplicativeGroup a) => SVector size a -> SVector size a -> SVector size a
(./) = zipWith (/)
