{-# LANGUAGE CPP #-}
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

module Test.Yql.Core.Backend where

#define eq assertEqual (__FILE__ ++":"++ show __LINE__)
#define ok assertBool (__FILE__ ++":"++ show __LINE__)

import Yql.Core.Session
import Yql.Core.Types
import Yql.Core.Backend
import qualified Data.Map as M
import Network.OAuth.Consumer
import Network.OAuth.Http.Response
import Test.Framework
import Test.Framework.Providers.HUnit
import Test.HUnit (assertBool, assertEqual)

test0 = testCase "test endpoint returns the string defined" $
        eq ("foobar",80) (myEndpoint $ YqlBackend (Application "iyql" "" OOB) DevNullStorage [] ("foobar",80))

test2 = testCase "test execute with `select title,abstract from search.web where query=\"iyql\"'" $
        do resp <- unOutputT $ execute (YqlBackend (Application "iyql" "" OOB) DevNullStorage [] ("query.yahooapis.com",80)) M.empty (read "select title,abstract from search.web where query=\"iyql\";")
           ok (isRight resp)
  where isRight (Right _) = True
        isRight _         = False

suite :: [Test]
suite = [ testGroup "Engine.hs" [ test0
                                , test2
                                ]
        ]

instance Show Application where
  showsPrec _ (Application ckey csec OOB)     = showString $ "Application "++ ckey ++" "++ csec ++" OOB"
  showsPrec _ (Application ckey csec (URL u)) = showString $ "Application "++ ckey ++" "++ csec ++" "++ u
