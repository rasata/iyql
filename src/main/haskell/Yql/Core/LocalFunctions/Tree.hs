-- Copyright (c) 2010, Diego Souza
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
--   * Redistributions of source code must retain the above copyright notice,
--     this list of conditions and the following disclaimer.
--   * Redistributions in binary form must reproduce the above copyright notice,
--     this list of conditions and the following disclaimer in the documentation
--     and/or other materials provided with the distribution.
--   * Neither the name of the <ORGANIZATION> nor the names of its contributors
--     may be used to endorse or promote products derived from this software
--     without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
-- SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
-- CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
-- OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
-- OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

module Yql.Core.LocalFunctions.Tree
       ( function
       ) where

import Yql.Data.PPrint
import Yql.Data.Xml
import Yql.Core.Types
import Yql.Core.LocalFunction
import Data.Char
import Data.Maybe
import Control.Monad

data Tree a = Branch a [Tree a]
            | Leaf a

function :: (Doc -> String) -> Exec
function defRender = Transform doc (mkRender xml2doc)
  where doc link = unlines [ "Reads the xml output and transforms it into a tree-like format"
                           , "Example:"
                           , "  SELECT * FROM social.profile WHERE guid=me | " ++ link ++ "(colors=\"true\");"
                           , "  SELECT * FROM social.profile WHERE guid=me | " ++ link ++ "();"
                           , ""
                           , "Configuration:"
                           , "  -- enable/disable colors when `colors' parameter is not explicitly given"
                           , "  tree.colors: [true|false]"
                           ]
        mkRender f argv = case (lookup "colors" argv)
                         of Nothing -> defRender . f
                            Just v  -> if (v == TxtValue "true")
                                       then renderTo Terminal . f
                                       else renderTo Memory . f

showTree :: Tree (Doc,Doc) -> Doc
showTree (Branch (k,v) xs) = mkRegular "├─ " +++ k +++ mkRegular ": " +++ v +++ nestWith (mkRegular "│  ") (cat $ map showTree xs)
showTree (Leaf (k,v))      = mkRegular "├─ " +++ k +++ mkRegular ": " +++ v

xml2doc :: String -> Doc
xml2doc raw = fromJust (liftM f nodes `mplus` Just (mkRegular raw))
  where xml     = xmlParse raw
        docRoot = join $ fmap (findElement "results") xml
        nodes   = fmap (filter element . childNodes) docRoot
        f       = (mkRegular "Results" +++) . cat . map (showTree . xml2tree)

xml2tree :: XML -> Tree (Doc,Doc)
xml2tree xml = Branch label subtree
  where label      
          | hasContent = (mkKeyword (tagName xml), mkRegular content)
          | otherwise  = (mkKeyword (tagName xml), empty)
        
        content = concatMap verbatim (filter pcdata (childNodes xml))
        
        hasContent = not (null (filter (not . isSpace) content))
        
        subtree = map xml2tree (filter element (childNodes xml)) ++ map mkLeaf (attributes xml)
          where mkLeaf (k,v) = Leaf (mkKeyword2 ('@':k), mkRegular v)

mkRegular :: String -> Doc
mkRegular = text

mkKeyword :: String -> Doc
mkKeyword = style (Style Yellow None True) . text

mkKeyword2 :: String -> Doc
mkKeyword2 = style (Style Yellow None False) . text
