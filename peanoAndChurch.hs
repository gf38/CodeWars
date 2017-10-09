{-# LANGUAGE 
  FlexibleInstances, 
  UndecidableInstances, 
  InstanceSigs,
  ScopedTypeVariables,
  RankNTypes #-}

module PC where

import Data.List

type ISO a b = (a -> b, b -> a)
-- See https://www.codewars.com/kata/isomorphism

symm :: ISO a b -> ISO b a
symm (ab, ba) = (ba, ab)

substL :: ISO a b -> (a -> b)
substL = fst

substR :: ISO a b -> (b -> a)
substR = snd

liftISO2 :: ISO a b -> ISO (a -> a -> a) (b -> b -> b)
liftISO2 (ab, ba) = (liftAB, liftBA)
  where liftAB f = \b1 b2 -> ab $ f (ba b1) (ba b2)
        liftBA f = \a1 a2 -> ba $ f (ab a1) (ab a2)

-- A Natural Number is either Zero,
-- or a Successor (1 +) of Natural Number.
-- We have (+)/(*) on Natural Number, or (-) it.
-- Since Natrual Number do not have negative, forall x, 0 - x = 0.
-- We also have pow on Natrual Number
-- Since Haskell is lazy, we also have infinity

class Nat n where
  zero :: n
  successor :: n -> n
  nat :: a -> (n -> a) -> n -> a -- Pattern Matching
  iter :: a -> (a -> a) -> n -> a -- Induction
  plus, minus, mult, pow :: n -> n -> n
  inf :: n
  inf = successor inf
  divide :: n -> n -> n
  l `divide` r | l == 0 && r == 0 = undefined
  l `divide` r | l < r = 0
  l `divide` r | otherwise = successor $ (l `minus` r) `divide` r
  -- notice (l `divide` 0) when l is not 0 will return inf
  isoP :: ISO n Peano -- See below for the definition of Peano
  isoP = (iter zero successor, iter zero successor)
  toP :: n -> Peano
  toP = substL isoP

instance {-# OVERLAPPABLE #-} Nat n => Show n where
  show = show . toP

instance {-# OVERLAPPABLE #-} Nat n => Eq n where
  l == r = toP l == toP r

instance {-# OVERLAPPABLE #-} Nat n => Ord n where
  l `compare` r = toP l `compare` toP r

instance {-# OVERLAPPABLE #-} Nat n => Num n where
  abs = id
  signum = nat zero (const 1)
  fromInteger 0 = zero
  fromInteger n | n > 0 = successor $ fromInteger (n - 1)
  (+) = plus
  (*) = mult
  (-) = minus

-- We can encode Natrual Number directly as Algebraic Data Type(ADT).
data Peano = O | S Peano deriving (Show, Eq, Ord)

-- Remember, 0 - x = 0 for all x.
instance Nat Peano where

  zero = O

  successor n = S n

  nat unit _ O = unit
  nat _ convFn (S n) = convFn n

  iter acc _ O = acc
  iter acc iterFn (S numIter) = iter (iterFn acc) (iterFn) numIter

  plus O n = n
  plus (S n) m = plus n (S m)

  minus O _ = O
  minus n O = n
  minus (S n) (S m) = minus n m

  mult a b = iter zero (+a) b

  pow a b = iter (S O) (*a) b
-- Peano is very similar to a basic data type in Haskell - List!
-- O is like [], and S is like :: (except it lack the head part)
-- When we want to store no information, we can use (), a empty tuple
-- This is different from storing nothing (called Void in Haskell),
-- as we can create a value of () by using (), 
-- but we cannot create a value of Void.

-- Notice how you can implement everything once you have isoP,
-- By converting to Peano and using Nat Peano?
-- Dont do that. You wont learn anything.
-- Try to use operation specific to list.
instance Nat [()] where
  zero = []

  successor n = ():n

  nat unit _ [] = unit
  nat _ convFn (():n) = convFn n

  iter acc _ [] = acc
  iter acc iterFn (():numIter) = iter (iterFn acc) (iterFn) numIter

  plus = (++)

  minus [] _ = []
  minus n [] = n
  minus (():n) (():m) = minus n m

  mult a b = concat $ map (\_ -> b) a

  pow a b = iter [()] (* a) b

-- Instead of defining Nat from zero, sucessor (and get Peano),
-- We can define it from Pattern Matching
newtype Scott = Scott { runScott :: forall a. a -> (Scott -> a) -> a }
instance Nat Scott where

  zero = Scott (\x _ -> x)

  successor n = Scott (\_ s -> s n )

  nat unit convFn (Scott n) = n unit (convFn)

  iter acc iterFn (Scott n) = n acc (\m -> iter (iterFn acc) iterFn m)
  -- Other operation on Scott numeral is sort of boring,
  -- So we implement it using operation on Peano.
  -- You shouldnt do this - I had handled all the boring case for you.
  plus = substR (liftISO2 isoP) plus
  minus = substR (liftISO2 isoP) minus
  mult = substR (liftISO2 isoP) mult
  pow = substR (liftISO2 isoP) pow

-- Or from induction!
newtype Church = Church { runChurch :: forall a. (a -> a) -> a -> a }
instance Nat Church where

  zero = Church (\_ x -> x)

  successor (Church f) = Church(\s x -> s $ f s x)

  nat unit convFn cn@(Church n) = n (\_ -> convFn $ predec cn) unit

  iter acc iterFn (Church n) = n (\accum -> iterFn accum) acc

  plus (Church f) (Church g) = Church (\s x -> f s (g s x))

  mult (Church f) (Church g) = Church (\s x -> f (g s) x )

  pow (Church f) (Church g) = Church (\s x -> (g f) s x)

  minus f g = iter f (predec) g

  -- Try to implement the calculation (except minus) in the primitive way.
  -- Implement them by constructing Church explicitly.
  -- So plus should not use successor,
  -- mult should not use plus,
  -- exp should not use mult.
predec :: Church -> Church
predec (Church n) = Church (\f x -> n (\g h -> h (g f)) (\_ -> x) (\u -> u))
