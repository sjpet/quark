{-# LANGUAGE OverloadedStrings #-}

---------------------------------------------------------------
--
-- Module:      Quark.Lexer.Window.Core
-- Author:      Stefan Peterson
-- License:     MIT License
--
-- Maintainer:  Stefan Peterson (stefan.j.peterson@gmail.com)
-- Stability:   Stable
-- Portability: Unknown
--
-- ----------------------------------------------------------
--
-- Umbrella module to handle varying languages
--
---------------------------------------------------------------

module Quark.Lexer.Language ( assumeLanguage
                            , tokenize
                            , colorize ) where

import System.FilePath ( takeExtension )
import Data.ByteString (ByteString)
-- import qualified Data.ByteString.Char8 as B

import Quark.Lexer.Core ( tokenizeNothing
                        , nothingColors )
import Quark.Lexer.Haskell ( tokenizeHaskell
                           , haskellColors )
import Quark.Lexer.Python ( tokenizePython
                          , pythonColors )
-- import Quark.Lexer.Shell ( tokenizeShellScript
--                          , shellScriptColors )

import Quark.Types

assumeLanguage :: FilePath -> Language
assumeLanguage path
    | extension == ".py" = "Python"
    | extension == ".hs" = "Haskell"
    | extension == ".sh" = "Shell script"
    | otherwise          = "UndefinedFish"
  where
    extension = takeExtension path

tokenize :: Language -> ByteString -> [Token]
tokenize language
    | language == "Haskell" = tokenizeHaskell
    | language == "Python"  = tokenizePython
    | otherwise             = tokenizeNothing

colorize :: Language -> Token -> Int
colorize language
    | language == "Haskell" = haskellColors
    | language == "Python"  = pythonColors
    | otherwise             = nothingColors