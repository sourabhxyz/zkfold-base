module Main where

import Foreign.C.String
-- import RustFfi
import ZkFold.Base.Algebra.Basic.Number
import ZkFold.Base.Algebra.EllipticCurve.Class
import ZkFold.Base.Algebra.EllipticCurve.BLS12_381

a = Point BLS12_381_G1 0x17f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb
        0x8b3f481e3aaa0f1a09e30ed741d8ae4fcf5e095d5d00af600db18cb2c04b3edd03cc744a2888ae40caa232946c5e7e1
b = Point BLS12_381_G1 0x17f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb
        0x8b3f481e3aaa0f1a09e30ed741d8ae4fcf5e095d5d00af600db18cb2c04b3edd03cc744a2888ae40caa232946c5e7e1

main :: Point BLS12_381_G1
main = add a b
