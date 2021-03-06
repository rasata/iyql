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

module Test.Yql.Core.Parser where

#define eq assertEqual (__FILE__ ++":"++ show __LINE__)

import Yql.Core.Lexer
import Yql.Core.Parser
import Test.Framework
import Test.Framework.Providers.HUnit
import Test.HUnit (assertBool,assertEqual)
import Data.List
import Text.ParserCombinators.Parsec

suite :: [Test]
suite = [ testGroup "Parser.hs" [ test0
                                , test1
                                , test2
                                , test3
                                , test4
                                , test5
                                , test6
                                , test7
                                , test8
                                , test9
                                , test10
                                , test11
                                , test12
                                , test13
                                , test14
                                , test15
                                , test16
                                , test17
                                , test18
                                , test19
                                , test20
                                , test21
                                , test22
                                , test23
                                , test24
                                , test25
                                , test26
                                , test27
                                , test28
                                , test29
                                , test30
                                , test31
                                , test32
                                , test33
                                , test34
                                , test35
                                , test36
                                , test37
                                ]
        ]

test0 = testCase "select * without where" $
        eq "SELECT * FROM iyql;" (runYqlParser_ "select * from iyql;")

test1 = testCase "select foo,bar without where" $
        eq "SELECT foo,bar FROM iyql;" (runYqlParser_ "select foo,bar from iyql;")

test2 = testCase "select * with single where clause [text]" $
        eq "SELECT * FROM iyql WHERE foo=\"bar\";" (runYqlParser_ "select * from iyql where foo='bar';")

test3 = testCase "select * with single where clause [num]" $
        eq "SELECT * FROM iyql WHERE pi=3.141592653589793;" (runYqlParser_ "select * from iyql where pi=3.141592653589793;")

test4 = testCase "select * with multiple and/or" $
        eq "SELECT * FROM iyql WHERE foo=\"bar\" AND bar=\"foo\" OR id=me;" (runYqlParser_ "select * from iyql where foo=\"bar\" and bar=\"foo\" or id=me;")

test5 = testCase "select * with `in' clause" $
        eq "SELECT * FROM iyql WHERE foo IN (\"b\",\"a\",\"r\",3,\".\",1);" (runYqlParser_ "select * from iyql where foo in (\"b\",\"a\",\"r\",3,\".\",1);")

test6 = testCase "select * with functions" $
        do eq "SELECT * FROM iyql | iyql(field=\"foobar\");" (runYqlParser_ "select * from iyql | iyql(field='foobar');")
           eq "SELECT * FROM iyql | iyql() | sort();" (runYqlParser_ "select * from iyql | iyql() | sort();")

test7 = testCase "select * using local filters [like]" $
        do eq "SELECT * FROM iyql WHERE foo LIKE \"baz\";" (runYqlParser_ "select * from iyql where foo like \"baz\";")
           eq "SELECT * FROM iyql WHERE foo NOT LIKE \"baz\";" (runYqlParser_ "select * from iyql where foo not like \"baz\";")

test8 = testCase "select * using local filters [matches]" $
        do eq "SELECT * FROM iyql WHERE foo MATCHES \".*bar.*\";" (runYqlParser_ "select * from iyql where foo matches \".*bar.*\";")
           eq "SELECT * FROM iyql WHERE foo NOT MATCHES \".*bar.*\";" (runYqlParser_ "select * from iyql where foo not matches \".*bar.*\";")

test9 = testCase "select * using local filters [>,>=,=,!=,<,<=]" $
        do eq "SELECT * FROM iyql WHERE foo>7;" (runYqlParser_ "select * from iyql where foo > 7;")
           eq "SELECT * FROM iyql WHERE foo>=7;" (runYqlParser_ "select * from iyql where foo >= 7;")
           eq "SELECT * FROM iyql WHERE foo<=7;" (runYqlParser_ "select * from iyql where foo <= 7;")
           eq "SELECT * FROM iyql WHERE foo<7;" (runYqlParser_ "select * from iyql where foo < 7;")
           eq "SELECT * FROM iyql WHERE foo=7;" (runYqlParser_ "select * from iyql where foo = 7;")
           eq "SELECT * FROM iyql WHERE foo!=7;" (runYqlParser_ "select * from iyql where foo != 7;")

test10 = testCase "select with where clause with different precedence" $
         do eq "SELECT * FROM iyql WHERE (foo=2 and bar=3) or (foo=5 and bar=7);" (runYqlParser_ "select * from iyql where (foo=2 and bar=3) or (foo=5 and bar=7);")
            eq "SELECT * FROM iyql WHERE (foo=2 or bar=3) and (foo=4 or bar=7);" (runYqlParser_ "select * from iyql where (foo=2 or bar=3) and (foo=5 or bar=7);")

test11 = testCase "local functions should not precede any remote functions" $
         do eq "parse error" (runYqlParser "select * from iyql | .bar() | foo();")

test12 = testCase "local and remote functions in the same query" $
         do eq "SELECT * FROM iyql | foo() | .bar();" (runYqlParser_ "select * from iyql | foo() | .bar();")

test13 = testCase "select using remote limit/offset" $
         do eq "SELECT * FROM iyql (7,13);" (runYqlParser_ "select * from iyql (7,13);")
            eq "SELECT * FROM iyql (0,7);" (runYqlParser_ "select * from iyql (7);")

test14 = testCase "desc statements" $
         do eq "DESC iyql;" (runYqlParser_ "desc iyql;")

test15 = testCase "desc statements allow remote filters" $
         do eq "DESC iyql | foobar();" (runYqlParser_ "desc iyql | foobar();")

test16 = testCase "update statements without where and single field" $ 
         do eq "UPDATE foobar SET foo=\"bar\";" (runYqlParser_ "update foobar set foo=\"bar\";")

test17 = testCase "update statements without where and multiple fields" $ 
         do eq "UPDATE foobar SET foo=\"bar\",bar=\"foo\",foobar=0;" (runYqlParser_ "update foobar set foo='bar' , bar='foo', foobar=0;")

test18 = testCase "update statements with where clause and single field" $ 
         do eq "UPDATE foobar SET foo=\"bar\" WHERE id=0 AND guid=me;" (runYqlParser_ "update foobar set foo='bar' where id=0 and guid=me;")

test19 = testCase "update statements with where clause and multiple fields" $ 
         do eq "UPDATE foobar SET foo=\"bar\",bar=\"foo\",foobar=0 WHERE guid=me AND id=0;" (runYqlParser_ "update foobar set foo='bar' , bar='foo', foobar=0 where guid=me and id=0;")

test20 = testCase "update statements with functions" $ 
         do eq "UPDATE foobar SET foo=\"bar\" WHERE guid=me | .json();" (runYqlParser_ "update foobar set foo='bar' where guid=me | .json();")
            
test21 = testCase "insert statements without functions and single field" $
         do eq "INSERT INTO foobar (foo) VALUES (\"0\");" (runYqlParser_ "insert into foobar (foo) values ('0');")

test22 = testCase "insert statements without functions and multiple fields" $
         do eq "INSERT INTO foobar (f,o,o) VALUES (0,1,\"2\");" (runYqlParser_ "insert into foobar (f,o,o) values (0,1,'2');")

test23 = testCase "insert statements with functions" $
         do eq "INSERT INTO foobar (foo) VALUES (\"0\") | .iyql();" (runYqlParser_ "insert into foobar (foo) values ('0') | .iyql();")

test24 = testCase "delete statements with functions" $
         do eq "DELETE FROM foobar | .diagnostics();" (runYqlParser_ "delete from foobar | .diagnostics();")

test25 = testCase "delete statements without functions and single field" $
         do eq "DELETE FROM foobar WHERE guid=me;" (runYqlParser_ "delete from foobar where guid=me;")

test26 = testCase "delete statements without functions and multiple fields" $
         do eq "DELETE FROM foobar WHERE guid=me | .diagnostics();" (runYqlParser_ "delete from foobar where guid=me | .diagnostics();")

test27 = testCase "delete statements with functions and single field" $
         do eq "DELETE FROM foobar WHERE guid=me | .diagnostics();" (runYqlParser_ "delete from foobar where guid=me | .diagnostics();")

test28 = testCase "delete statements with functions and multiple fields" $
         do eq "DELETE FROM foobar WHERE guid=me OR name=\"foo\" | .diagnostics();" (runYqlParser_ "delete from foobar where guid=me or name=\"foo\" | .diagnostics();")

test29 = testCase "show tables statements without functions" $ 
         do eq "SHOW TABLES;" (runYqlParser_ "show tables;")

test30 = testCase "show tables statements with functions" $
         do eq "SHOW TABLES | .iyql();" (runYqlParser_ "show tables | .iyql();")

test31 = testCase "select statements with local limit" $
         do eq "SELECT * FROM iyql LIMIT 10 OFFSET 0;" (runYqlParser_ "select * from iyql limit 10;")

test32 = testCase "select statements with local limit/offset" $
         do eq "SELECT * FROM iyql LIMIT 10 OFFSET 0;" (runYqlParser_ "select * from iyql limit 10 offset 0;")

test33 = testCase "select * using local filters [matches]" $
         do eq "SELECT * FROM iyql WHERE foo MATCHES \".*bar.*\";" (runYqlParser_ "select * from iyql where foo matches \".*bar.*\";")
            eq "SELECT * FROM iyql WHERE foo NOT MATCHES \".*bar.*\";" (runYqlParser_ "select * from iyql where foo not matches \".*bar.*\";")

test34 = testCase "select * using local filters [is null]" $
         do eq "SELECT * FROM iyql WHERE foo IS NULL;" (runYqlParser_ "select * from iyql where foo is null;")
            eq "SELECT * FROM iyql WHERE foo IS NOT NULL;" (runYqlParser_ "select * from iyql where foo is not null;")

test35 = testCase "single use statements" $
         do eq "USE \"foobar\" AS fb; SELECT * FROM foobar;" (runYqlParser_ "use 'foobar' as fb; select * from foobar;")
            eq "USE \"foobar\" AS fb; UPDATE foobar SET foo=10;" (runYqlParser_ "use 'foobar' as fb; update foobar set foo=10;")
            eq "USE \"foobar\" AS fb; INSERT INTO foobar (foo) VALUES (10);" (runYqlParser_ "use 'foobar' as fb; insert into foobar (foo) values (10);")
            eq "USE \"foobar\" AS fb; DELETE FROM foobar;" (runYqlParser_ "use 'foobar' as fb; delete from foobar;")

test36 = testCase "multiple use statements" $
         do eq "USE \"foo\" AS f; USE \"bar\" AS b; USE \"foobar\" AS fb; SELECT * FROM foobar;" (runYqlParser_ "use 'foo' as f; use 'bar' as b; use 'foobar' as fb; select * from foobar;")

test37 = testCase "select with subqueries" $
         do eq "SELECT * FROM foo WHERE id IN (SELECT id FROM bar WHERE age>2;);" (runYqlParser_ "select * from foo where id in (select id from bar where age>2);")

newtype LexerToken = LexerToken (String,TokenT)
                   deriving (Show)

showFunction [] = "";
showFunction f  = " | " ++ intercalate " | " f;

showRemoteLimit Nothing      = ""
showRemoteLimit (Just (o,l)) = " ("++ show o ++","++ show l ++")"

showLocalLimit Nothing      = ""
showLocalLimit (Just (o,l)) = " LIMIT "++ show l ++" OFFSET "++ show o

stringBuilder = ParserEvents { onIdentifier = id
                             , onTxtValue   = mkValue
                             , onNumValue   = id
                             , onSubSelect  = id
                             , onMeValue    = "me"
                             , onSelect     = mkSelect
                             , onUse        = mkUse
                             , onUpdate     = mkUpdate
                             , onInsert     = mkInsert
                             , onDelete     = mkDelete
                             , onDesc       = mkDesc
                             , onShowTables = mkShowTables
                             , onAssertOp   = mkAssertOp
                             , onSingleOp   = mkSingleOp
                             , onListOp     = mkListOp
                             , onAndExpr    = mkAndExpr
                             , onOrExpr     = mkOrExpr
                             , onLocalFunc  = mkFunc "."
                             , onRemoteFunc = mkFunc ""
                             }
  where mkValue v = "\"" ++ v ++ "\""

        mkSelect c t Nothing  rl ll f = "SELECT " ++ (intercalate "," c) ++ " FROM " ++ t ++ showRemoteLimit rl ++ showLocalLimit ll ++ showFunction f ++ ";"
        mkSelect c t (Just w) rl ll f = "SELECT " ++ (intercalate "," c) ++ " FROM " ++ t ++ showRemoteLimit rl ++ " WHERE " ++ w ++ showLocalLimit ll ++ showFunction f ++ ";"
        
        mkUse u a stmt = "USE \""++ u ++"\""++ " AS "++ a ++"; "++ stmt
        
        mkUpdate c t Nothing f  = "UPDATE " ++ t ++ " SET " ++ (intercalate "," (map (\(k,v) -> k++"="++v) c)) ++ showFunction f ++ ";"
        mkUpdate c t (Just w) f = "UPDATE " ++ t ++ " SET " ++ (intercalate "," (map (\(k,v) -> k++"="++v) c)) ++ " WHERE " ++ w ++ showFunction f ++ ";"
        
        mkDelete t Nothing f  = "DELETE FROM " ++ t ++ showFunction f ++ ";"
        mkDelete t (Just w) f = "DELETE FROM " ++ t ++ " WHERE " ++ w ++ showFunction f ++ ";"
        
        mkShowTables f = "SHOW TABLES" ++ showFunction f ++ ";"
        
        mkInsert c t f = "INSERT INTO " ++ t ++ " (" ++ intercalate "," (map fst c) ++ ") VALUES (" ++ intercalate "," (map snd c) ++ ")" ++ showFunction f ++ ";"

        mkDesc t f = "DESC " ++ t ++ showFunction f ++ ";"

        mkFunc p n as = p ++ n ++ "("++ intercalate "," (map showArg as) ++")"
          where showArg (k,v) = k ++"="++ v

        mkSingleOp (c `EqOp` v) = c ++"="++ v
        mkSingleOp (c `GtOp` v) = c ++">"++ v
        mkSingleOp (c `LtOp` v) = c ++"<"++ v
        mkSingleOp (c `NeOp` v) = c ++"!=" ++ v
        mkSingleOp (c `GeOp` v) = c ++">="++ v
        mkSingleOp (c `LeOp` v) = c ++"<="++ v
        mkSingleOp (c `LikeOp` v) = c ++" LIKE "++ v
        mkSingleOp (c `MatchesOp` v) = c ++" MATCHES "++ v
        mkSingleOp (c `NotLikeOp` v) = c ++" NOT LIKE "++ v
        mkSingleOp (c `NotMatchesOp` v) = c ++" NOT MATCHES "++ v
        
        mkAssertOp (IsNullOp c)    = c ++ " IS NULL"
        mkAssertOp (IsNotNullOp c) = c ++ " IS NOT NULL"

        mkListOp (c `InOp` vs) = c ++ " IN ("++ intercalate "," vs ++")"

        mkAndExpr l r = l ++" AND "++ r

        mkOrExpr l r = l ++" OR "++ r

runYqlParser :: String -> String
runYqlParser input = case (parseYql input stringBuilder)
                     of Right output -> output
                        Left err     -> "parse error: " ++ (show err)

runYqlParser_ :: String -> String
runYqlParser_ input = case (parseYql input stringBuilder)
                          of Right output -> output
                             Left err     -> error ("parse error: " ++ (show err))
