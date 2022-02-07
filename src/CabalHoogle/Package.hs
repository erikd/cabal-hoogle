{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -funbox-strict-fields #-}
module CabalHoogle.Package
  ( PackageName
  , mkPackageName
  , unPackageName

  , PackageId(..)
  , Version
  , packageId
  , renderPackageId
  , renderShortPackageId
  , renderVersion
  , packageIdTuple
  , parsePackageId
  , parseVersion
  , makeVersion
  , versionNumbers
  ) where

import           Control.Monad (fail)
import           Data.CaseInsensitive (CI)
import qualified Data.CaseInsensitive as CI
import qualified Data.Char as Char
import qualified Data.Text as T
import           Distribution.Version (Version, versionNumbers)
import qualified Distribution.Version as DistVersion

import qualified Distribution.Pretty

import           CabalHoogle.P

import qualified Data.Attoparsec.Text as Parse


-- Similar to Cabal's Distribution.Package

newtype PackageName =
  PackageName {
      ciPackageName :: CI Text
    } deriving (Eq, Ord, Show)

mkPackageName :: Text -> PackageName
mkPackageName =
  PackageName . CI.mk

unPackageName :: PackageName -> Text
unPackageName =
  CI.original . ciPackageName

data PackageId =
  PackageId {
      pkgName :: !PackageName
    , pkgVersion :: !Version
    } deriving (Eq, Show)

instance Ord PackageId where
  compare (PackageId xn xv) (PackageId yn yv) =
    compare
      (ciPackageName xn, xv)
      (ciPackageName yn, yv)

packageId :: Text -> [Int] -> PackageId
packageId n v =
  PackageId (mkPackageName n) (makeVersion v)

renderPackageId :: PackageId -> Text
renderPackageId (PackageId name version) =
  unPackageName name <> "-" <> renderVersion version

renderShortPackageId :: PackageId -> Text
renderShortPackageId (PackageId name version) =
  let a = unPackageName name in
  T.filter (not . flip elem ("aeiou" :: [Char])) a <> "-" <> renderVersion version

renderVersion :: Version -> Text
renderVersion =
  T.pack . Distribution.Pretty.prettyShow

packageIdTuple :: PackageId -> (PackageName, Version)
packageIdTuple (PackageId n v) =
  (n, v)

-- Extract name from `$name-$version`, but consider `unordered-containers-1.2.3` and `cabal-plan-0.7.2.1 exe:cabal-plan`
parsePackageId :: Text -> Maybe PackageId
parsePackageId =
  let parser =
        PackageId
          <$> (PackageName . CI.mk . T.intercalate "-" <$> Parse.sepBy1 component (Parse.char '-'))
          <* Parse.char '-'
          <*> pVersion

          <* ((Parse.many1 Parse.space
               *> Parse.many1 Parse.anyChar
               *> Parse.endOfInput)
               <|> Parse.endOfInput)
  in rightToMaybe . Parse.parseOnly parser
  where
    component = do
      cs <- Parse.takeWhile1 Char.isAlphaNum
      if T.all Char.isDigit cs then fail "" else return cs

parseVersion :: Text -> Maybe Version
parseVersion =
  rightToMaybe . Parse.parseOnly (pVersion <* Parse.endOfInput)

pVersion :: Parse.Parser Version
pVersion = makeVersion <$> Parse.sepBy Parse.decimal (Parse.char '.')

makeVersion :: [Int] -> Version
makeVersion xs =
  DistVersion.mkVersion xs

