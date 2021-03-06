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

-- | Syntactic analysis of Yql statements
module Yql.Core.Parser
       ( -- * Types
         ParserEvents(..)
       , AssertOperator(..)
       , SingleOperator(..)
       , ListOperator(..)
       , Limit
       , ParseError
         -- * Parser
       , parseYql
       )
       where

import Text.ParserCombinators.Parsec
import Yql.Core.Lexer

type YqlParser a st = GenParser Token st a

-- | Limit in terms of (offset,amount)
type Limit = (Integer,Integer)

-- | Tests if column satisfies a given property
data AssertOperator i = IsNullOp i
                      | IsNotNullOp i

-- | Operators in where clause that takes a single value
data SingleOperator i v = EqOp i v
                        | NeOp i v
                        | GtOp i v
                        | GeOp i v
                        | LtOp i v
                        | LeOp i v
                        | LikeOp i v
                        | NotLikeOp i v
                        | MatchesOp i v
                        | NotMatchesOp i v

-- | Operator in where clause that takes a list of values
data ListOperator i v = InOp i [v]

-- | Events the parser generates. The main purpose of this is to allow
-- you constructing types that represents yql statements.
data ParserEvents i v w f s = ParserEvents { onIdentifier :: String -> i
                                           , onTxtValue   :: String -> v
                                           , onNumValue   :: String -> v
                                           , onSubSelect  :: s -> v
                                           , onMeValue    :: v
                                           , onSelect     :: [i] -> i -> Maybe w -> Maybe Limit -> Maybe Limit -> [f] -> s
                                           , onUpdate     :: [(i,v)] -> i -> Maybe w -> [f] -> s
                                           , onInsert     :: [(i,v)] -> i -> [f] -> s
                                           , onDelete     :: i -> Maybe w -> [f] -> s
                                           , onUse        :: String -> i -> s -> s
                                           , onShowTables :: [f] -> s
                                           , onDesc       :: i -> [f] -> s
                                           , onAssertOp   :: AssertOperator i -> w
                                           , onSingleOp   :: SingleOperator i v -> w
                                           , onListOp     :: ListOperator i v -> w
                                           , onAndExpr    :: w -> w -> w
                                           , onOrExpr     :: w -> w -> w
                                           , onLocalFunc  :: i -> [(i,v)] -> f
                                           , onRemoteFunc :: i -> [(i,v)] -> f
                                           }

-- | Parses an string, which must be a valid yql expression, using
-- ParserEvents to create generic types.
parseYql :: String -> ParserEvents i v w f s -> Either ParseError s
parseYql input e = case tokStream
                   of Left err     -> Left err
                      Right input_ -> runParser myParser () "stdin" input_
  where tokStream = runParser scan () "stdin" input
        
        myParser = do expr <- parseYql_ e
                      tkEof
                      return expr

parseYql_ :: ParserEvents i v w f s -> YqlParser s st
parseYql_ e = do (parseDesc e >>= semiColon)
                 <|> (parseSelect e >>= semiColon )
                 <|> (parseUpdate e >>= semiColon )
                 <|> (parseInsert e >>= semiColon )
                 <|> (parseDelete e >>= semiColon )
                 <|> (parseShowTables e >>= semiColon)
                 <|> parseUse e
  where semiColon v = do keyword (==";")
                         return v

quoted :: YqlParser String st
quoted = accept test
  where test (TkStr s) = Just s
        test _         = Nothing

numeric :: YqlParser String st
numeric = accept test
  where test (TkNum n) = Just n
        test _         = Nothing

keyword :: (String -> Bool) -> YqlParser String st
keyword p = accept test
  where test (TkKey k) | p k       = Just k
                       | otherwise = Nothing
        test _                     = Nothing

symbol :: (String -> Bool) -> YqlParser String st
symbol p = accept test
  where test (TkSym s) | p s       = Just s
                       | otherwise = Nothing
        test _                     = Nothing

symbol_ :: YqlParser String st
symbol_ = symbol (const True)

-- anyTokenT :: YqlParser TokenT
-- anyTokenT = accept Just

tkEof :: YqlParser () st
tkEof = accept $ \t -> case t
                       of TkEOF -> Just ()
                          _     -> Nothing

parseDesc :: ParserEvents i v w f s -> YqlParser s st
parseDesc e = do keyword (=="DESC")
                 t <- parseIdentifier e
                 f <- parseFunctions e
                 return (onDesc e t f)

parseShowTables :: ParserEvents i v w f s -> YqlParser s st
parseShowTables e = do keyword (=="SHOW")
                       keyword (=="TABLES")
                       f <- parseFunctions e
                       return (onShowTables e f)

parseUse :: ParserEvents i v w f s -> YqlParser s st
parseUse e = do keyword (=="USE")
                url  <- quoted
                keyword (=="AS")
                as   <- parseIdentifier e
                keyword (==";")
                stmt <- parseYql_ e
                return (onUse e url as stmt)

parseSelect :: ParserEvents i v w f s -> YqlParser s st
parseSelect e = do keyword (=="SELECT")
                   c <- (fmap (const [onIdentifier e "*"]) (keyword (=="*"))
                         <|> parseIdentifier e `sepBy` keyword (==","))
                   keyword (=="FROM")
                   t <- parseIdentifier e
                   rl <- remoteLimit
                         <|> return Nothing
                   w <- whereClause
                        <|> return Nothing
                   ll <- localLimit
                         <|> return Nothing
                   f <- parseFunctions e
                   return (onSelect e c t w rl ll f)
  where whereClause = do keyword (=="WHERE")
                         fmap Just (parseWhere e)
        
        remoteLimit = do keyword (=="(")
                         off <- fmap read numeric
                         lim <- (do keyword (==",")
                                    sz <- fmap read numeric
                                    return (off,sz)
                                ) <|> return (0,off)
                         keyword (==")")
                         return (Just lim)
        
        localLimit = do keyword (=="LIMIT")
                        lim <- fmap read numeric
                        off <- (do keyword (=="OFFSET")
                                   fmap read numeric
                               ) <|> return 0
                        return (Just (off,lim))

parseUpdate :: ParserEvents i v w f s -> YqlParser s st
parseUpdate e = do keyword (=="UPDATE")
                   t <- parseIdentifier e
                   keyword (=="SET")
                   c <- parseSet `sepBy` keyword (==",")
                   w <- whereClause
                        <|> return Nothing
                   f <- parseFunctions e
                   return (onUpdate e c t w f)
  where whereClause = do keyword (=="WHERE")
                         fmap Just (parseWhere e)
        
        parseSet = do k <- parseIdentifier e
                      keyword (=="=")
                      v <- parseValue False e
                      return (k,v)

parseDelete :: ParserEvents i v w f s -> YqlParser s st
parseDelete e = do keyword (=="DELETE")
                   keyword (=="FROM")
                   t <- parseIdentifier e
                   w <- whereClause
                        <|> return Nothing
                   f <- parseFunctions e
                   return (onDelete e t w f)
  where whereClause = do keyword (=="WHERE")
                         fmap Just (parseWhere e)

parseInsert :: ParserEvents i v w f s -> YqlParser s st
parseInsert e = do keyword (=="INSERT")
                   keyword (=="INTO")
                   t <- parseIdentifier e
                   keyword (=="(")
                   c <- parseIdentifier e `sepBy` keyword (==",")
                   keyword (==")")
                   keyword (=="VALUES")
                   keyword (=="(")
                   v <- parseValue False e `sepBy` keyword (==",")
                   keyword (==")")
                   f <- parseFunctions e
                   return (onInsert e (zip c v) t f)

parseIdentifier :: ParserEvents i v w f s -> YqlParser i st
parseIdentifier e = fmap (onIdentifier e) symbol_

parseValue :: Bool -> ParserEvents i v w f s -> YqlParser v st
parseValue allowss e = fmap (onTxtValue e) quoted
                       <|> fmap (onNumValue e) numeric
                       <|> fmap (const $ onMeValue e) (keyword (=="ME"))
                       <|> if (allowss)
                           then fmap (onSubSelect e) (parseSelect e)
                           else fail "expecting Numeric|String|me"

parseWhere :: ParserEvents i v w f s -> YqlParser w st
parseWhere e = do c       <- parseIdentifier e
                  wclause <- parseScalar c
                             <|> parseList c
                             <|> parseAssert c
                  (keyword (=="AND") >> fmap (onAndExpr e wclause) (parseWhere e))
                   <|> (keyword (=="OR") >> fmap (onOrExpr e wclause) (parseWhere e))
                   <|> return wclause
  where parseScalar c = (keyword (=="=") >> fmap (onSingleOp e . EqOp c) (parseValue False e))
                        <|> (keyword (=="!=") >> fmap (onSingleOp e . NeOp c) (parseValue False e))
                        <|> (keyword (==">=") >> fmap (onSingleOp e . GeOp c) (parseValue False e))
                        <|> (keyword (=="<=") >> fmap (onSingleOp e . LeOp c) (parseValue False e))
                        <|> (keyword (==">") >> fmap (onSingleOp e . GtOp c) (parseValue False e))
                        <|> (keyword (=="<") >> fmap (onSingleOp e . LtOp c) (parseValue False e))
                        <|> (keyword (=="LIKE") >> fmap (onSingleOp e . LikeOp c) (parseValue False e))
                        <|> (keyword (=="MATCHES") >> fmap (onSingleOp e . MatchesOp c) (parseValue False e))
                        <|> (keyword (=="NOT") >> ((keyword (=="LIKE") >> fmap (onSingleOp e . NotLikeOp c) (parseValue False e))
                                                   <|> (keyword (=="MATCHES") >> fmap (onSingleOp e . NotMatchesOp c) (parseValue False e))))

        parseAssert c = keyword (=="IS") >> ((keyword (=="NOT") >> keyword (=="NULL") >> return (onAssertOp e (IsNotNullOp c)))
                                             <|> (keyword (=="NULL") >> return (onAssertOp e (IsNullOp c))))

        parseList c = do keyword (=="IN")
                         keyword (=="(")
                         list <- fmap (onListOp e . InOp c) (parseValue True e `sepBy` keyword (==","))
                         keyword (==")")
                         return list

parseFunctions :: ParserEvents i v w f s -> YqlParser [f] st
parseFunctions e = (keyword (=="|") >> parseFunction e `sepBy` keyword (=="|"))
                   <|> return []

parseFunction :: ParserEvents i v w f s -> YqlParser f st
parseFunction e = do n <- symbol_
                     keyword (=="(")
                     argv <- arguments `sepBy` keyword (==",")
                     keyword (==")")
                     mkFunc n argv
  where arguments = do k <- parseIdentifier e
                       keyword (=="=")
                       v <- parseValue False e
                       return (k,v)

        mkFunc ('.':n) argv = return (onLocalFunc e (onIdentifier e n) argv)
        mkFunc n argv       = return (onRemoteFunc e (onIdentifier e n) argv)

