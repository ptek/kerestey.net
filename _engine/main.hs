    {-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

module Main where

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
    match "texts/*" $ compile pandocCompiler

    -- Read templates
    match "templates/*" $ compile templateCompiler

    -- Render pages
    match "pages/**" $ do
        route $ gsubRoute "pages/" (const "") `composeRoutes` createSubpageDir
        compile $ do
            ctx <- loadContext defaultCtx
            pandocCompiler
                >>= loadAndApplyTemplate "templates/page.html" ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= insertTexts
                >>= relativizeUrls

    -- Render posts
    match "writing/**" $ do
        route   $ setExtension "html"
        compile $ do
            ctx <- loadContext defaultCtx
            pandocCompiler
                >>= saveSnapshot "writing-content"
                >>= loadAndApplyTemplate "templates/writing.html" ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

    -- Render Atom Feed
    create ["atom.xml"] $ do
        route idRoute
        compile $ do
            ctx <- loadContext defaultCtx
            posts <- recentFirst =<< loadAllSnapshots publishedWriting "writing-content"
            renderAtom feedConfiguration (ctx `mappend` bodyField "description") posts

    -- Render home
    create ["index.html"] $ do
        route idRoute
        compile $ do
            ctx <- loadContext defaultCtx
            makeItem ("" :: String)
                >>= loadAndApplyTemplate "templates/index.html" ctx
                >>= insertTexts
                >>= relativizeUrls

    create ["writing.html"] $ do
        route idRoute
        compile $ do
            ctx <- loadContext allPostsCtx
            loadAll publishedWriting
                >>= recentFirst 
                >>= loadAndApplyTemplateList "templates/writing-list-item.html" defaultCtx
                >>= loadAndApplyTemplate "templates/writing-list.html" ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

    create ["sitemap.xml"] $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll publishedWriting
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

loadTexts :: Compiler (Context a)
loadTexts =
    mconcat <$> (loadAll "texts/*.md" >>= mapM (fmap toConstField . renderPandoc))
    where
    toConstField Item{..} = constField (toFieldName itemIdentifier) itemBody
    toFieldName = ("text-" ++) . takeBaseName . toFilePath

publishedWriting :: Pattern
publishedWriting = "writing/*.md"

loadAndApplyTemplateList :: Identifier -> Context a -> [Item a] -> Compiler (Item String)
loadAndApplyTemplateList template context item = do 
    postItemTpl <- loadBody template
    ctx <- loadContext context
    applyTemplateList postItemTpl ctx item >>= makeItem


feedConfiguration :: FeedConfiguration
feedConfiguration = FeedConfiguration
    { feedTitle       = "Pavlo Kerestey: Writing"
    , feedDescription = "Writing of Pavlo Kerestey, mostly technical articles with an occasional personal post"
    , feedAuthorName  = "Pavlo Kerestey"
    , feedAuthorEmail = "pavlo .at. kerestey .dot. net"
    , feedRoot        = "https://kerestey.net"
    }
