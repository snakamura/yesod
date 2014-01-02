{-# LANGUAGE OverloadedStrings #-}
-- | Manipulate CSS urls.
--
-- * Make relative urls absolute (useful when combining assets)
module Yesod.EmbeddedStatic.Css.AbsoluteUrl (
  -- * Absolute urls
    absoluteUrls
  , absoluteUrlsAt
  , absoluteUrlsWith
) where

import Prelude hiding (FilePath)
import Yesod.EmbeddedStatic.Generators
import Yesod.EmbeddedStatic.Types

import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as T
import qualified Data.Text.Lazy.Encoding as TL
import Control.Monad ((>=>))
import Data.Maybe (fromMaybe)
import Filesystem.Path.CurrentOS ((</>), collapse, FilePath, fromText, toText, encodeString, decodeString)

import Yesod.EmbeddedStatic.Css.Util

-------------------------------------------------------------------------------
-- Generator
-------------------------------------------------------------------------------

-- | Anchors relative CSS image urls
createAbsCssUrlsProd :: FilePath -- ^ Anchor relative urls to here
                     -> FilePath
                     -> IO BL.ByteString
createAbsCssUrlsProd dir file = do
    css <- parseCssUrls file
    let r = renderCssWith toAbsoluteUrl css
    return $ TL.encodeUtf8 r
  where
    toAbsoluteUrl (UrlReference rel) = T.concat
        [ "url('/"
        , (either id id $ toText $ collapse $ dir </> fromText rel)
        , "')"
        ]


-- | Equivalent to passing the same string twice to 'absoluteUrlsAt'.
absoluteUrls :: FilePath -> Generator
absoluteUrls f = absoluteUrlsAt (encodeString f) f

-- | Equivalent to passing @return@ to 'absoluteUrlsWith'.
absoluteUrlsAt :: Location -> FilePath -> Generator
absoluteUrlsAt loc f = absoluteUrlsWith loc f Nothing

-- | Automatically make relative urls absolute
--
-- During development, leave CSS as is.
--
-- When CSS is organized into a directory structure, it will work properly for individual requests for each file.
-- During production, we want to combine and minify CSS as much as possible.
-- The combination process combines files from different directories, messing up relative urls.
-- This pre-processor makes relative urls absolute
absoluteUrlsWith ::
    Location -- ^ The location the CSS file should appear in the static subsite
  -> FilePath -- ^ Path to the CSS file.
  -> Maybe (CssGeneration -> IO BL.ByteString) -- ^ Another filter function run after this one (for example @return . yuiCSS . cssContent@) or other CSS filter that runs after this filter.
                     -> Generator
absoluteUrlsWith loc file mpostFilter =
    return [ cssProductionFilter (createAbsCssUrlsProd (decodeString loc) >=> postFilter . mkCssGeneration loc file) loc file
    ]
  where
    postFilter = fromMaybe (return . cssContent) mpostFilter