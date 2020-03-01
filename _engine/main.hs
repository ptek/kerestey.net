{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

module Main where

import Control.Monad (filterM)
import Data.Maybe (isNothing)
import Hakyll
import System.FilePath

hakyllConf :: Configuration
hakyllConf = defaultConfiguration {
      providerDirectory = "./content/"
    }

-- Contexts

loadContext :: Context a -> Compiler (Context a)
loadContext baseContext = do
    textsContext <- loadTexts
    return $ textsContext <> baseContext

defaultCtx :: Context String
defaultCtx = dateField "date-iso" "%F" <> dateField "date" "%B %e, %Y" <> defaultContext

basicCtx :: String -> Context String
basicCtx title = constField "title" title <> defaultCtx

homeCtx :: Context String
homeCtx = basicCtx "Home"

allPostsCtx :: Context String
allPostsCtx = basicCtx "Writing"

feedCtx :: Context String
feedCtx = bodyField "description" <> defaultCtx

tagsCtx :: Tags -> Context String
tagsCtx tags = tagsField "prettytags" tags <> defaultCtx

postsCtx :: String -> String -> Context String
postsCtx title list = constField "body" list <> basicCtx title

-- Compiler

main :: IO ()
main = hakyllWith hakyllConf $ do

    -- Copy all static files
    match "static/**" $ do
        route $ gsubRoute "static/" (const "")
        compile copyFileCompiler

    -- Render styles
    match "css/*" $ do
        route idRoute
        compile compressCssCompiler

    -- Render texts
    match "texts/*" $ compile pandocCompilerWithAsciidoctor

    -- Read templates
    match "templates/*" $ compile templateCompiler

    -- Render home
    match "index.html" $ do
        route idRoute
        compile $ textInsertionCompiler >>= relativizeUrls

    -- Render pages
    match "pages/**" $ do
        route $ gsubRoute "pages/" (const "") `composeRoutes` createSubpageDir
        compile $ textInsertionCompiler >>= relativizeUrls

    -- Render posts
    match "writing/**" $ do
        route   $ setExtension "html"
        compile $ do
            ctx <- loadContext defaultCtx
            pandocCompilerWithAsciidoctor
                >>= loadAndApplyTemplate "templates/writing.html" ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

    create ["writing.html"] $ do
        route idRoute
        compile $ do
            ctx <- loadContext allPostsCtx
            postList "writing/*.md" recentFirst
                >>= makeItem
                >>= loadAndApplyTemplate "templates/writing-list.html" ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

    create ["sitemap.xml"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "writing/*"
            singlePages <- loadAll "pages/*"
            createdPages <- loadAll (fromList ["writing.html"])
            let pages = createdPages <> singlePages <> posts
                sitemapCtx = listField "pages" defaultCtx (return pages)
            makeItem ("" :: String)
                >>= loadAndApplyTemplate "templates/sitemap.xml" sitemapCtx

createSubpageDir :: Routes
createSubpageDir = customRoute $ createSubdir . toFilePath
    where
    createSubdir p = dropExtension p <> "/index.html"

insertTexts :: Item String -> Compiler (Item String)
insertTexts resourceBody = do
    textContext <- loadContext defaultCtx
    applyAsTemplate textContext resourceBody

textInsertionCompiler :: Compiler (Item String)
textInsertionCompiler = getResourceBody >>= insertTexts

loadTexts :: Compiler (Context a)
loadTexts =
    mconcat <$> (loadAll "texts/*.md" >>= mapM (fmap toConstField . renderPandoc))
    where
    toConstField Item{..} = constField (toFieldName itemIdentifier) itemBody
    toFieldName = ("text-" ++) . takeBaseName . toFilePath

postList :: Pattern -> ([Item String] -> Compiler [Item String]) -> Compiler String
postList pattern preprocess' = do
    postItemTpl <- loadBody "templates/writing-list-item.html"
    posts <- preprocess' =<< filterM notDraft =<< loadAll pattern
    ctx <- loadContext defaultCtx
    applyTemplateList postItemTpl ctx posts
    where
    notDraft :: Item a -> Compiler Bool
    notDraft (Item identifier _) = getMetadataField identifier "draft" >>= return . isNothing

-- Allow to compile ascii docs.
pandocCompilerWithAsciidoctor :: Compiler (Item String)
pandocCompilerWithAsciidoctor = do
  extension <- getUnderlyingExtension
  if extension == ".asciidoc" then
    getResourceString >>= withItemBody (unixFilter "asciidoctor" ["-"])
  else
    pandocCompiler
