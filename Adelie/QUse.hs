-- QUse.hs
--
-- Module to describe the use flags of an installed package.

module Adelie.QUse (qUse) where

import qualified Data.HashTable.IO as HT
import Control.Monad (unless)

import Adelie.Colour
import Adelie.ListEx
import Adelie.Portage
import Adelie.Pretty
import Adelie.Use
import Adelie.UseDesc

----------------------------------------------------------------

qUse :: [String] -> IO ()
qUse args = qUse' =<< findInstalledPackages args

qUse' :: [(String, String)] -> IO ()
qUse' [] = return ()
qUse' catnames = do
  useDesc' <- readUseDesc
  useDescPackage' <- readUseDescPackage min' max'
  useDescExpand'  <- readUseExpDesc
  mapM_ (use useDesc' useDescPackage' useDescExpand') catnames
  where min' = dropVersion $ fullnameFromCatName $ minimum catnames
        max' = dropVersion $ fullnameFromCatName $ maximum catnames

use :: UseDescriptions -> UseDescriptions -> UseDescriptions
    -> (String, String) -> IO ()
use useDesc' useDescPackage' useDescExpand' catname = do
  iUse <- readIUse fnIUse
  pUse <- readUse  fnPUse
  let iUse' = fmap stripUse iUse
      len   = maximum $ map length iUse'
  use' catname len useDesc' useDescPackage' useDescExpand' iUse' pUse
  where fnIUse = iUseFromCatName catname
        fnPUse = useFromCatName catname

use' :: (String, String) -> Int -> UseDescriptions -> UseDescriptions
     -> UseDescriptions -> [String] -> [String] -> IO ()
use' catname _ _ _ _ [] _ = putStr "No USE flags for " >> putCatNameLn catname
use' catname len useDesc' useDescPackage' useDescExpand' iUse pUse = do
  putStr "USE flags for " >> putCatNameLn catname
  mapM_ (format len useDesc' useDescPackage' useDescExpand' pUse) iUse
  putChar '\n'


-- |Strip prefixed '+' and '-' settings from a USE flag string.
stripUse :: String -> String
stripUse ('-':xs) = xs
stripUse ('+':xs) = xs
stripUse xs       = xs


----------------------------------------------------------------

format :: Int -> UseDescriptions -> UseDescriptions
       -> UseDescriptions -> [String] -> String -> IO ()

format len useDesc' useDescPackage' useDescExpand' pUse iUse =
  inst >> putStr (pad len ' ' iUse) >> off >> putStr " : " >> desc
  where
    inst = if iUse `elem` pUse
            then putStr " + " >> red
            else putStr "   " >> blue

    desc =
      desc' useDescExpand'    >>= \x -> unless x
        $ desc' useDescPackage' >>= \y -> unless y
          $ desc' useDesc'        >>= \z -> unless z
            $ putStrLn "<< no description >>"

    desc' descs = do
      r <- HT.lookup descs iUse
      case r of
        Just d  -> puts d >> return True
        Nothing -> return False

puts :: String -> IO ()
puts d@('!':'!':_) = red >> putStr d >> off2
puts d = putStrLn d
