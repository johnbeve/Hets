{-# LANGUAGE CPP                        #-}
{-# LANGUAGE FlexibleContexts           #-}
{-# LANGUAGE GADTs                      #-}
{-# LANGUAGE ScopedTypeVariables        #-}

module Persistence.Database (DBMonad, onDatabase) where

import Persistence.DBConfig
import Persistence.DatabaseConnection
import Persistence.Schema

import Control.Exception.Lifted
import Control.Monad (when)
import Control.Monad.IO.Class
import Control.Monad.Trans.Control
import Control.Monad.Trans.Reader
import Control.Monad.Logger
import Control.Monad.IO.Unlift
import qualified Control.Monad.Fail as Fail

import Data.List (intercalate, isInfixOf)
import Data.Text (Text, pack)

import Database.Persist.Sql

type DBMonad m a = ReaderT SqlBackend m a

onDatabase :: ( MonadIO m
              , MonadBaseControl IO m
              , MonadUnliftIO m
              , Fail.MonadFail m
              )
           => DBConfig
           -> DBMonad (NoLoggingT m) a
           -> m a
onDatabase dbConfig f = do
  connection <- liftIO $ getConnection dbConfig
  runNoLoggingT $ connection $ runSqlPool $ do
    runFullMigrationSet dbConfig
    f

runFullMigrationSet :: forall m . ( MonadBaseControl IO m
                                  , MonadIO m
                                  , MonadUnliftIO m
                                  , Fail.MonadFail m
                                  )
                    => DBConfig -> DBMonad m ()
runFullMigrationSet dbConfig =
  when (doMigrate dbConfig) $ do
    disableNotices -- PostgreSQL prints notices if an index already exists
    runMigrationSilent migrateAll
    mapM_ (handle ignoreIndexExistsError . runRawSql) $ indexesSQL dbConfig
  where
    disableNotices :: MonadIO m => DBMonad m ()
    disableNotices =
      when (adapter dbConfig == Just "postgresql")
        (runRawSql "SET client_min_messages = error;" >> return ())

    runRawSql :: MonadIO m => String -> DBMonad m [Single (Maybe Text)]
    runRawSql sql =
      let query = pack $
#ifdef MYSQL
                         if isMySql dbConfig
                         then
                             sql
                         else
#endif
                             sql ++ " SELECT ('dummy');"
      in  rawSql query []

    -- MySQL does not have "CREATE INDEX IF NOT EXISTS", so we work around this
    -- by trying to create it in any case. It throws an error if it already
    -- exists. This error is then ignored.
    ignoreIndexExistsError :: MonadIO m
                           => SomeException -> DBMonad m [Single (Maybe Text)]
    ignoreIndexExistsError = ignoreError "'ix_"

    ignoreError :: MonadIO m
                => String -> SomeException -> DBMonad m [Single (Maybe Text)]
    ignoreError searchInfix exception =
      let message = show exception in
#ifdef MYSQL
      if isMySql dbConfig && (searchInfix `isInfixOf` message)
      then
          return []
      else
#endif
          Fail.fail message

indexesSQL :: DBConfig -> [String]
indexesSQL dbConfig =
  map sqlString Persistence.Schema.indexes
  where
    sqlString :: (String, [String]) -> String
    sqlString (table, columns) =
      let indexName = "ix_" ++ table ++ "__" ++ intercalate "__" columns
          indexedColumns = intercalate ", " columns
#ifdef MYSQL
          indexNameMySql = take 64 indexName
          mysqlString =
            "CREATE INDEX " ++ indexNameMySql ++ " ON " ++ table ++ ""
            ++ "(" ++ indexedColumns ++ ");"
#endif
          genericString =
            "CREATE INDEX IF NOT EXISTS " ++ indexName ++ " ON " ++ table ++ ""
            ++ "(" ++ indexedColumns ++ ");"
      in  case adapter dbConfig of
#ifdef MYSQL
            Just "mysql" -> mysqlString
            Just "mysql2" -> mysqlString
#endif
            Just "postgresql" -> genericString
            Just "sqlite" -> genericString
            Just "sqlite3" -> genericString
            _ -> genericString
