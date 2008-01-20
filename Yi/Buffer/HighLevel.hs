-- Copyright (C) 2008 JP Bernardy
module Yi.Buffer.HighLevel where

import Data.Char
import Yi.String
import Yi.Buffer
import Yi.Buffer.Normal
import Yi.Buffer.Region
import Yi.Window
import Control.Monad.State
-- ---------------------------------------------------------------------
-- Movement operations

-- | Move point to start of line
moveToSol :: BufferM ()
moveToSol = execB MaybeMove Line Backward

-- | Move point to end of line
moveToEol :: BufferM ()
moveToEol = execB MaybeMove Line Forward

-- | Move cursor to origin
topB :: BufferM ()
topB = moveTo 0

-- | Move cursor to end of buffer
botB :: BufferM ()
botB = moveTo =<< sizeB

-- | Move @x@ chars back, or to the sol, whichever is less
moveXorSol :: Int -> BufferM ()
moveXorSol x = replicateM_ x $ do c <- atSol; when (not c) leftB

-- | Move @x@ chars forward, or to the eol, whichever is less
moveXorEol :: Int -> BufferM ()
moveXorEol x = replicateM_ x $ do c <- atEol; when (not c) rightB

-- | Move to first char of next word forwards
nextWordB :: BufferM ()
nextWordB = execB Move Word Forward

-- | Move to first char of next word backwards
prevWordB :: BufferM ()
prevWordB = execB Move Word Backward

------------

-- | Move down next @n@ paragraphs
nextNParagraphs :: Int -> BufferM ()
nextNParagraphs n = replicateM_ n $ execB Move Paragraph Forward

-- | Move up prev @n@ paragraphs
prevNParagraphs :: Int -> BufferM ()
prevNParagraphs n = replicateM_ n $ execB Move Paragraph Backward 


-----------------------------------------------------------------------
-- Queries

-- | Return true if the current point is the start of a line
atSol :: BufferM Bool
atSol = atBoundaryB Line Backward

-- | Return true if the current point is the end of a line
atEol :: BufferM Bool
atEol = atBoundaryB Line Forward

-- | True if point at start of file
atSof :: BufferM Bool
atSof = atBoundaryB Document Backward

-- | True if point at end of file
atEof :: BufferM Bool
atEof = atBoundaryB Document Forward

-- | Get the current line and column number
getLineAndCol :: BufferM (Int, Int)
getLineAndCol = do
  lineNo <- curLn
  colNo  <- offsetFromSol
  return (lineNo, colNo)

-- | Read the line the point is on
readLnB :: BufferM String
readLnB = readUnitB Line

-- | Read from point to end of line
readRestOfLnB :: BufferM String
readRestOfLnB = readRegionB =<< regionOfPartB Line Forward

--------------------------
-- Deletes

-- | Delete one character backward
bdeleteB :: BufferM ()
bdeleteB = execB Delete Character Backward

-- | Delete forward whitespace or non-whitespace depending on
-- the character under point.
killWordB :: BufferM ()
killWordB = execB Delete Word Forward

-- | Delete backward whitespace or non-whitespace depending on
-- the character before point.
bkillWordB :: BufferM ()
bkillWordB = execB Delete Word Backward


----------------------------------------
-- Transform operations

-- | capitalise the word under the cursor
uppercaseWordB :: BufferM ()
uppercaseWordB = execB (Transform (map toUpper)) Word Forward

-- | lowerise word under the cursor
lowercaseWordB :: BufferM ()
lowercaseWordB = execB (Transform (map toLower)) Word Forward

-- | capitalise the first letter of this word
capitaliseWordB :: BufferM ()
capitaliseWordB = execB (Transform capitalizeFirst) Word Forward


-- | Delete to the end of line, excluding it.
deleteToEol :: BufferM ()
deleteToEol = do
    p <- pointB
    moveToEol
    q <- pointB
    deleteNAt (q-p) p

-- | Transpose two characters, (the Emacs C-t action)
swapB :: BufferM ()
swapB = do eol <- atEol
           when eol leftB
           execB Transpose Character Forward

-- ----------------------------------------------------
-- | Marks

-- | Set the current buffer mark
setSelectionMarkPointB :: Int -> BufferM ()
setSelectionMarkPointB pos = do m <- getSelectionMarkB; setMarkPointB m pos

-- | Get the current buffer mark
getSelectionMarkPointB :: BufferM Int
getSelectionMarkPointB = do m <- getSelectionMarkB; getMarkPointB m

-- | Exchange point & mark.
-- Maybe this is better put in Emacs\/Mg common file
exchangePointAndMarkB :: BufferM ()
exchangePointAndMarkB = do m <- getSelectionMarkPointB
                           p <- pointB
                           setSelectionMarkPointB p
                           moveTo m

getBookmarkB :: String -> BufferM Mark
getBookmarkB nm = getMarkB (Just nm)

-- ---------------------------------------------------------------------
-- Buffer operations

data BufferFileInfo =
    BufferFileInfo { bufInfoFileName :: FilePath
		   , bufInfoSize     :: Int
		   , bufInfoLineNo   :: Int
		   , bufInfoColNo    :: Int
		   , bufInfoCharNo   :: Int
		   , bufInfoPercent  :: String
		   , bufInfoModified :: Bool
		   }

-- | File info, size in chars, line no, col num, char num, percent
bufInfoB :: BufferM BufferFileInfo
bufInfoB = do
    s <- sizeB
    p <- pointB
    m <- isUnchangedB
    l <- curLn
    c <- offsetFromSol
    nm <- gets name
    let bufInfo = BufferFileInfo { bufInfoFileName = nm
				 , bufInfoSize     = s
				 , bufInfoLineNo   = l
				 , bufInfoColNo    = c
				 , bufInfoCharNo   = p
				 , bufInfoPercent  = getPercent p s 
				 , bufInfoModified = not m
				 }
    return bufInfo

-----------------------------
-- Window-related operations

-- | Scroll up 1 screen
upScreenE :: BufferM ()
upScreenE = upScreensE 1

-- TODO: add a direction parameter instead of duplicating code.
-- | Scroll up n screens
upScreensE :: Int -> BufferM ()
upScreensE n = do
  h <- askWindow height
  gotoLnFrom (- (n * (h - 1)))
  moveToSol

-- | Scroll down 1 screen
downScreenE :: BufferM ()
downScreenE = downScreensE 1

-- | Scroll down n screens
downScreensE :: Int -> BufferM ()
downScreensE n = do
  h <- askWindow height
  gotoLnFrom (n * (h - 1))
  moveToSol

-- | Move to @n@ lines down from top of screen
downFromTosE :: Int -> BufferM ()
downFromTosE n = do
  moveTo =<< askWindow tospnt
  replicateM_ n lineDown

-- | Move to @n@ lines up from the bottom of the screen
upFromBosE :: Int -> BufferM ()
upFromBosE n = do
  moveTo =<< askWindow bospnt
  moveToSol
  replicateM_ n lineUp

-- | Move to middle line in screen
middleE :: BufferM ()
middleE = do
  w <- askWindow id
  moveTo (tospnt w)
  replicateM_ (height w `div` 2) lineDown

