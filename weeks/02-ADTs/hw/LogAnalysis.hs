{-# OPTIONS_GHC -Wall #-}

module LogAnalysis where

import Log

parseMessage :: String -> LogMessage
parseMessage m = case words m of
  (ty:n:time:msg) | ty == "E" ->
    LogMessage (Error (read n)) (read time) (unwords msg)
  (ty:time:msg)
    | ty == "I" -> LogMessage Info (read time) (unwords msg)
    | ty == "W" -> LogMessage Warning (read time) (unwords msg)
  x -> Unknown (unwords x)

parseLines :: [String] -> [LogMessage]
parseLines = map parseMessage

parse :: String -> [LogMessage]
parse m = parseLines (lines m)

messageBefore :: LogMessage -> LogMessage -> Bool
messageBefore (LogMessage _ t1 _) (LogMessage _ t2 _) = t1 < t2
messageBefore _ _ = error "Cannot compare Unknown"

insert :: LogMessage -> MessageTree -> MessageTree
insert (Unknown _) t = t
insert m Leaf = Node Leaf m Leaf
insert m (Node l m' r)
  | m `messageBefore` m' = Node (insert m l) m' r
  | otherwise = Node l m' (insert m r)

build :: [LogMessage] -> MessageTree
build = build' Leaf where
  build' :: MessageTree -> [LogMessage] -> MessageTree
  build' t [] = t
  build' t (m:ms) = build' (insert m t) ms

inOrder :: MessageTree -> [LogMessage]
inOrder Leaf = []
inOrder (Node l m r) = inOrder l ++ [m] ++ inOrder r

whatWentWrong :: [LogMessage] -> [String]
whatWentWrong m = getMessageStrings (inOrder (build (filterMessages m)))

filterMessages :: [LogMessage] -> [LogMessage]
filterMessages = filter filterMessage where
  filterMessage :: LogMessage -> Bool
  filterMessage (LogMessage (Error val) _ _) = val >= 50
  filterMessage _ = False

getMessageStrings :: [LogMessage] -> [String]
getMessageStrings = map messageString where
  messageString :: LogMessage -> String
  messageString (LogMessage _ _ m) = m
  messageString _ = "Unknown"
