{-# LANGUAGE DeriveDataTypeable #-}

import Control.Monad          ( replicateM_, when )
import Data.Functor           ( (<$>) )
import Data.Monoid            ( (<>) )

import Development.Shake
import Development.Shake.FilePath

import System.Cmd             ( system )
import System.Console.CmdArgs

makeDir = ".make"

data CIS194Mode =
    Build
  | Preview
  | Clean
  | Deploy
  deriving (Show, Data, Typeable)

cis194Modes = modes
  [ Build   &= auto
  , Preview
  , Clean
  , Deploy
  ]

main :: IO ()
main = (shake shakeOptions . chooseMode) =<< cmdArgs cis194Modes

chooseMode :: CIS194Mode -> Rules ()
chooseMode mode = cis194Rules <> choose mode
  where
    choose (Build {})   = doBuild
    choose (Preview {}) = doPreview
    choose (Clean {})   = doClean
    choose (Deploy {})  = doDeploy

cis194Rules :: Rules ()
cis194Rules = genericRules <> webRules

doBuild = action $ requireBuild

doClean = action $ do
  alwaysRerun
  system' "rm" ["-rf", "web/_site", "web/_cache"]

doPreview = action $ do
  alwaysRerun
  requireBuild
  need ["web/hakyll.hs.exe"]
  systemCwd "web" ("./hakyll.hs.exe") ["preview", "8000"]

doDeploy = action $ do
  alwaysRerun
  liftIO $ system "rsync -tvr web/_site/* cis194@minus.seas.upenn.edu:html/ && ssh cis194@minus.seas.upenn.edu chmod -R o+rX html/"

--------------------------------------------------

webRules :: Rules ()
webRules = do
  "web/lectures/*.markdown" *> \out -> do
    let base = takeBaseName out
        f    = weekFile base "" "markdown"
    copyFile' f out

  "web/lectures/*.lhs" *> \out -> do
    let base = takeBaseName out
        f    = weekFile base "lec" "lhs"
    copyFile' f out

  "web/lectures/*.html" *> \out -> do
    let base = takeBaseName out
        f    = weekFile base "lec" "lhs"
    need [f, "tools/processLec.hs.exe"]
    system' "tools/processLec.hs.exe"
      [ "html",  f, "-o", out ]

  "web/hw/*.pdf" *> \out -> do
    let base = takeBaseName out
        f    = weekFile base "hw" "pdf"
    copyFile' f out

  "web/docs/*" *> \out -> do
    copyFile' (dropDirectory1 out) out

requireBuild :: Action ()
requireBuild = do
  weekDirs <- getDirectoryDirs "weeks"
  mapM_ copyImages weekDirs
  need =<< (concat <$> mapM mkWeek weekDirs)
  need ["web/docs/inthelarge.pdf", "web/docs/style.pdf"]
 where
  copyImages week = do
    let imgDir = "weeks" </> week </> "images"
    imgFiles <- getDirectoryFiles imgDir "*"
    mapM_ (\f -> copyFile' (imgDir </> f) ("web/images" </> f)) imgFiles
  mkWeek week = do
    solsExist <- doesFileExist (weekFile week "sols" "lhs")
    return $
      [ weekFile week "hw" "pdf" ]
      ++
      [ weekFile week "sols" "pdf" | solsExist ]
      ++
      [ "web/lectures" </> week <.> "markdown"
      , "web/lectures" </> week <.> "lhs"
      , "web/lectures" </> week <.> "html"
      , "web/hw" </> week <.> "pdf"
      ]

weekFile :: FilePath -> String -> String -> FilePath
weekFile week tag ext = "weeks" </> week </> (week <.> tag) <.> ext

--------------------------------------------------

genericRules :: Rules ()
genericRules = do

  "//*.hs.exe" *> \out -> do
    let hs = dropExtension out
    need [hs]
    system' "ghc" ["--make", "-o", out, hs]

  ["docs//*.pdf", "weeks//*.pdf"] **> \out -> do
    let tex = replaceExtension out "tex"
        dir = takeDirectory out
    need [tex]
    hs <- getDirectoryFiles dir "*.hs"
    need (map (dir </>) hs)

    let tex' = takeFileName tex
    replicateM_ 2 $
      systemCwd dir "pdflatex"
        ["--enable-write18", tex']

  "//*.tex" *> \out -> do
    let lhs = replaceExtension out "lhs"
        dir = takeDirectory out
    useLhs <- doesFileExist lhs
    when useLhs $ do
      need [lhs]
      system' "lhs2TeX" ["--verb", lhs, "-o", out]


--------------------------------------------------

