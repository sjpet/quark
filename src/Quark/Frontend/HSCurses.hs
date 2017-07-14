---------------------------------------------------------------
--
-- Module:      Quark.Frontend.HSCurses
-- Author:      Stefan Peterson
-- License:     MIT License
--
-- Maintainer:  Stefan Peterson (stefan.j.peterson@gmail.com)
-- Stability:   Stable
-- Portability: Unknown
--
-- ----------------------------------------------------------
--
-- Frontend module for HSCurses
--
---------------------------------------------------------------

module Quark.Frontend.HSCurses ( Window ( TitleBar
                                        , UtilityBar
                                        , TextView
                                        , ProjectView )
                               , windowSize
                               , setTextColor
                               , addString
                               , mvAddString
                               , move
                               , clear
                               , clear'
                               , refresh
                               , wOffset
                               , wSetOffset
                               , Layout ( MinimalLayout
                                        , BasicLayout
                                        , HSplitLayout
                                        , VSplitLayout )
                               , windowList
                               , titleBar
                               , utilityBar
                               , primaryPane
                               , secondaryPane
                               , projectPane
                               , start
                               , end
                               , onResize
                               , getKey
                               , updateCursor
                               , showCursor
                               , hideCursor
                               , defaultLayout
                               , basicLayout
                               , minimalLayout
                               , vSplitLayout
                               , hSplitLayout
                               , layoutWidth
                               , projectPaneWidth ) where

import qualified UI.HSCurses.Curses as Curses

import Data.Char ( isPrint
                 , ord )

import Quark.Colors
import Quark.Types ( Key ( CharKey
                         , WideCharKey
                         , CtrlKey
                         , FnKey
                         , SpecialKey
                         , ResizeKey
                         , InvalidKey )
                   , ColorPair
                   , Cursor
                   , Offset
                   , Size )
import Quark.Settings ( lineWidthHint )

import System.Posix.Signals ( Handler ( Catch )
                            , installHandler )

-----------------------------
-- Start and end functions --
-----------------------------

start :: IO ()
start = do
    Curses.initScr
    hasColors <- Curses.hasColors
    if hasColors then do Curses.startColor
                         Curses.useDefaultColors
                         defineColors
                 else return ()
    Curses.resetParams
    Curses.wclear Curses.stdScr
    Curses.refresh
    Curses.keypad Curses.stdScr True
    case (Curses.cursesSigWinch, Curses.keyResizeCode) of
        (Just sig, Just key) -> do
            installHandler sig (Catch $ sigwinch sig key) Nothing
            return ()
        _                    -> return ()
  where
    sigwinch sig key = do
        Curses.ungetCh key
        -- installHandler sig (Catch $ sigwinch sig key) Nothing
        return ()

end :: IO ()
end = Curses.endWin

onResize :: IO ()
onResize = do
    Curses.endWin
    Curses.werase Curses.stdScr
    Curses.refresh

------------
-- getKey --
------------

getKey :: IO Key
getKey = translateKey' =<< Curses.getCh

translateKey' :: Curses.Key -> IO Key
translateKey' (Curses.KeyChar c)
    | ord c >= 240 = WideCharKey <$> (c:) <$> getMoreChars 3
    | ord c >= 224 = WideCharKey <$> (c:) <$> getMoreChars 2
    | ord c >= 192 = WideCharKey <$> (c:) <$> getMoreChars 1
translateKey' k = return $ translateKey k

getMoreChars :: Int -> IO String
getMoreChars n
    | n <= 0    = return ""
    | otherwise = do
        k <- Curses.getCh
        case k of
            (Curses.KeyChar c) -> (c:) <$> (getMoreChars (n - 1))
            _                  -> Curses.ungetCh 1 >> return ""

translateKey :: Curses.Key -> Key
translateKey k@(Curses.KeyChar c)
    | c == '\r'   = SpecialKey "Return"
    | c == '\DEL' = SpecialKey "Backspace"
    | c == '\t'   = SpecialKey "Tab"
    | c == '\ESC' = SpecialKey "Esc"
    | c == '\SOH' = CtrlKey 'a'
    | c == '\STX' = CtrlKey 'b'
    | c == '\ETX' = CtrlKey 'c'
    | c == '\EOT' = CtrlKey 'd'
    | c == '\ENQ' = CtrlKey 'e'
    | c == '\ACK' = CtrlKey 'f'
    | c == '\a'   = CtrlKey 'g'
--     | c == '\t'   = CtrlKey 'i' -- identical to Tab
    | c == '\n'   = CtrlKey 'j'
    | c == '\v'   = CtrlKey 'k'
    | c == '\f'   = CtrlKey 'l'
--     | c == '\r'   = CtrlKey 'm' -- identical to Return
    | c == '\SO'  = CtrlKey 'n'
    | c == '\SI'  = CtrlKey 'o'
    | c == '\DLE' = CtrlKey 'p'
    | c == '\DC1' = CtrlKey 'q'
    | c == '\DC2' = CtrlKey 'r'
    | c == '\DC3' = CtrlKey 's'
    | c == '\DC4' = CtrlKey 't'
    | c == '\NAK' = CtrlKey 'u'
    | c == '\SYN' = CtrlKey 'v'
    | c == '\ETB' = CtrlKey 'w'
    | c == '\CAN' = CtrlKey 'x'
    | c == '\EM'  = CtrlKey 'y'
    | c == '\SUB' = CtrlKey 'z'
    | otherwise   = if isPrint c then CharKey c
                                 else InvalidKey $ show k
translateKey k = case k of
    Curses.KeyDC          -> SpecialKey "Delete"
    Curses.KeySDC         -> SpecialKey "Shift-Delete"
    Curses.KeyBTab        -> SpecialKey "Shift-Tab"
    Curses.KeyHome        -> SpecialKey "Home"
    Curses.KeySHome       -> SpecialKey "Shift-Home"
    Curses.KeyUnknown 538 -> SpecialKey "Ctrl-Home"
    Curses.KeyUnknown 539 -> SpecialKey "Ctrl-Shift-Home"
    Curses.KeyEnd         -> SpecialKey "End"
    Curses.KeySEnd        -> SpecialKey "Shift-End"
    Curses.KeyUnknown 533 -> SpecialKey "Ctrl-End"
    Curses.KeyUnknown 534 -> SpecialKey "Ctrl-Shift-End"
    Curses.KeyPPage       -> SpecialKey "PgUp"
    Curses.KeySPrevious   -> SpecialKey "Shift-PgUp"
    Curses.KeyNPage       -> SpecialKey "PgDn"
    Curses.KeySNext       -> SpecialKey "Shift-PgDn"
    Curses.KeyIC          -> SpecialKey "Insert"
    Curses.KeyUp          -> SpecialKey "Up"
    Curses.KeyUnknown 569 -> SpecialKey "Ctrl-Up"
    Curses.KeyUnknown 570 -> SpecialKey "Ctrl-Shift-Up"
    Curses.KeyDown        -> SpecialKey "Down"
    Curses.KeyUnknown 528 -> SpecialKey "Ctrl-Down"
    Curses.KeyUnknown 529 -> SpecialKey "Ctrl-Shift-Down"
    Curses.KeyLeft        -> SpecialKey "Left"
    Curses.KeySLeft       -> SpecialKey "Shift-Left"
    Curses.KeyUnknown 548 -> SpecialKey "Ctrl-Left"
    Curses.KeyUnknown 549 -> SpecialKey "Ctrl-Shift-Left"
    Curses.KeyRight       -> SpecialKey "Right"
    Curses.KeySRight      -> SpecialKey "Shift-Right"
    Curses.KeyUnknown 563 -> SpecialKey "Ctrl-Right"
    Curses.KeyUnknown 564 -> SpecialKey "Ctrl-Shift-Right"
    Curses.KeyBackspace   -> CtrlKey 'h'
    Curses.KeyResize      -> ResizeKey
    Curses.KeyF k         -> FnKey k
    _                     -> InvalidKey $ show k

---------------------
-- Color functions --
---------------------

cursesPair :: ColorPair -> Int
cursesPair (x, y)
    | (x, y) == ((-1), (-1))    = 0
    | (x, y) == lineNumberPair  = lineNumberInt
    | (x, y) == titleBarPair    = titleBarInt
    | (x, y) == treeDefaultPair = treeDefaultInt
    | (x, y) == treeActivePair  = treeActiveInt
    | y == (-1)                 = x
    | y == selectionColor       = x + if x == (-1) then 18 else 17
    | y == highlightColor       = x + if x == (-1) then 35 else 34
    | x == y                    = errorColorInt
    | otherwise                 = x

defineColors :: IO ()
defineColors = do
    nColors <- Curses.colors
    mapM_ (\(n, f, b) -> defineColor n f b) $ colorTriples nColors
  where
    defineColor n f b =
      Curses.initPair (Curses.Pair n) (Curses.Color f) (Curses.Color b)

----------------------
-- Cursor functions --
----------------------

updateCursor :: Window -> Offset -> Cursor -> IO ()
updateCursor (TextView w _ _) (x0, y0) (x, y) =
    Curses.wMove w (x - x0) (y - y0)
updateCursor (UtilityBar w (rr, cc)) (r, c) (_, y) =
    Curses.wMove w (min r rr) (min (y + c) cc)

showCursor :: IO Curses.CursorVisibility
showCursor = Curses.cursSet Curses.CursorVisible

hideCursor :: IO Curses.CursorVisibility
hideCursor = Curses.cursSet Curses.CursorInvisible

-------------------------------
-- Window type and functions --
-------------------------------

data Window = TitleBar Curses.Window Size
            | UtilityBar Curses.Window Size
            | TextView Curses.Window Size Offset
            | ProjectView Curses.Window Size Int deriving Show

cursesWindow :: Window -> Curses.Window
cursesWindow (TitleBar w _)        = w
cursesWindow (UtilityBar w _)      = w
cursesWindow (TextView w _ _)      = w
cursesWindow (ProjectView w _ _) = w

windowSize :: Window -> Size
windowSize (TitleBar _ s)      = s
windowSize (UtilityBar _ s)    = s
windowSize (TextView _ s _)    = s
windowSize (ProjectView _ s _) = s

setTextColor :: Window -> ColorPair -> IO ()
setTextColor w pair =
    Curses.wAttrSet (cursesWindow w) ( Curses.attr0
                                     , Curses.Pair $ cursesPair pair )

addString :: Window -> String -> IO ()
addString = Curses.wAddStr . cursesWindow

mvAddString :: Window -> Int -> Int -> String -> IO ()
mvAddString = Curses.mvWAddStr . cursesWindow

move :: Window -> Int -> Int -> IO ()
move = Curses.wMove . cursesWindow

refresh :: Window -> IO ()
refresh = Curses.wRefresh . cursesWindow

clear :: Window -> IO ()
clear = Curses.werase . cursesWindow

clear' :: Window -> Int -> IO ()
clear' t@(TextView w (r, c) (_, cc)) k
    | rulerCol >= c + cc || rulerCol < cc = Curses.werase w
    | otherwise                = do
          Curses.werase w
          setTextColor t rulerPair
          mapM_ (\x -> Curses.mvWAddStr w x 0 rulerLine) $
              take r [0..]
          Curses.wMove w 0 0
  where
    rulerCol = length rulerLine
    rulerLine = drop cc (replicate (lineWidthHint + k) ' ') ++ "\9474"

wOffset :: Window -> Offset
wOffset (TextView _ _ offset') = offset'
wOffset _                      = (0, 0)

wSetOffset :: Offset -> Window -> Window
wSetOffset offset' (TextView w s _) = TextView w s offset'
wSetOffset offset' w                = w

-------------------------------
-- Layout type and functions --
-------------------------------

data Layout = MinimalLayout { titleBar :: Window
                            , utilityBar :: Window
                            , primaryPane :: Window
                            , projectPaneWidth' :: Int }
            | BasicLayout { titleBar :: Window
                          , utilityBar :: Window
                          , projectPane :: Window
                          , primaryPane :: Window }
            | VSplitLayout { titleBar :: Window
                           , utilityBar :: Window
                           , projectPane :: Window
                           , primaryPane :: Window
                           , secondaryPane :: Window }
            | HSplitLayout { titleBar :: Window
                           , utilityBar :: Window
                           , projectPane :: Window
                           , primaryPane :: Window
                           , secondaryPane :: Window } deriving Show

windowList :: Layout -> [Window]
windowList (MinimalLayout a b c _)    = [a, b, c]
windowList (BasicLayout a b c d)    = [a, b, c, d]
windowList (VSplitLayout a b c d e) = [a, b, c, d, e]
windowList (HSplitLayout a b c d e) = [a, b, c, d, e]

layoutWidth :: Layout -> Int
layoutWidth = snd . windowSize . titleBar

projectPaneWidth :: Layout -> Int
projectPaneWidth (MinimalLayout _ _ _ c) = c
projectPaneWidth layout = ((1 +) . snd . windowSize . projectPane) layout

defaultLayout :: Int -> IO Layout
defaultLayout k = do
    (r, c) <- Curses.scrSize
    let dpWidth = if k < 0 then min 24 (c -32)
                               else k
    layout <- if c > 85 + 16 then basicLayout dpWidth
                             else minimalLayout dpWidth
    return layout

basicLayout :: Int -> IO Layout
basicLayout dpWidth = do
    (r, c) <- Curses.scrSize
    let dpWidth' = min dpWidth (div c 2) - 1
    let mainHeight = r - 4
    let mainWidth = c - dpWidth
    cTitleBar <- Curses.newWin 2 c 0 0
    cUtilityBar <- Curses.newWin 2 c (r - 2) 0
    cDirectoryPane <- Curses.newWin mainHeight dpWidth' 2 0
    cMainView <- Curses.newWin mainHeight mainWidth 2 dpWidth
    let qTitleBar = TitleBar cTitleBar (1, c)
    let qUtilityBar = UtilityBar cUtilityBar (1, c)
    let qDirectoryPane = ProjectView cDirectoryPane (mainHeight, dpWidth') 0
    let qPrimaryPane = TextView cMainView (mainHeight, mainWidth) (0, 0)
    return $ BasicLayout qTitleBar qUtilityBar qDirectoryPane qPrimaryPane

minimalLayout :: Int -> IO Layout
minimalLayout dpWidth = do
    (r, c) <- Curses.scrSize
    let mainHeight = r - 4
    cTitleBar <- Curses.newWin 2 c 0 0
    cUtilityBar <- Curses.newWin 2 c (r - 2) 0
    cMainView <- Curses.newWin mainHeight c 2 0
    let qTitleBar = TitleBar cTitleBar (1, c)
    let qUtilityBar = UtilityBar cUtilityBar (1, c)
    let qPrimaryPane = TextView cMainView (mainHeight, c) (0, 0)
    return $ MinimalLayout qTitleBar qUtilityBar qPrimaryPane $
                 min dpWidth (div c 2) - 1

vSplitLayout :: IO Layout
vSplitLayout = do
    (r, c) <- Curses.scrSize
    let dpWidth = min 24 (c - 32)
    let dpWidth' = dpWidth - 1
    let mainHeight = r - 4
    let secondaryWidth = div (c - dpWidth) 2
    let primaryWidth = c - dpWidth - secondaryWidth
    cTitleBar <- Curses.newWin 2 c 0 0
    cUtilityBar <- Curses.newWin 2 c (r - 2) 0
    cDirectoryPane <- Curses.newWin mainHeight dpWidth' 2 0
    cPrimaryPane <- Curses.newWin mainHeight primaryWidth 2 dpWidth
    cSecondaryPane <- Curses.newWin mainHeight secondaryWidth 2 (dpWidth + primaryWidth)
    let qTitleBar = TitleBar cTitleBar (1, c)
    let qUtilityBar = UtilityBar cUtilityBar (1, c)
    let qDirectoryPane = ProjectView cDirectoryPane (mainHeight, dpWidth') 0
    let qPrimaryPane = TextView cPrimaryPane (mainHeight, primaryWidth) (0, 0)
    let qSecondaryPane = TextView cSecondaryPane (mainHeight, secondaryWidth) (0, 0)
    return $ VSplitLayout qTitleBar qUtilityBar qDirectoryPane qPrimaryPane qSecondaryPane

hSplitLayout :: IO Layout
hSplitLayout = do
    (r, c) <- Curses.scrSize
    let dpWidth = min 24 (c - 32)
    let dpWidth' = dpWidth - 1
    let mainHeight = r - 4
    let secondaryHeight = div mainHeight 2
    let primaryHeight = mainHeight - secondaryHeight
    let mainWidth = c - dpWidth
    cTitleBar <- Curses.newWin 2 c 0 0
    cUtilityBar <- Curses.newWin 2 c (r - 2) 0
    cDirectoryPane <- Curses.newWin mainHeight dpWidth' 2 0
    cPrimaryPane <- Curses.newWin primaryHeight mainWidth 2 dpWidth
    cSecondaryPane <- Curses.newWin secondaryHeight mainWidth (2 + primaryHeight) dpWidth
    let qTitleBar = TitleBar cTitleBar (1, c)
    let qUtilityBar = UtilityBar cUtilityBar (1, c)
    let qDirectoryPane = ProjectView cDirectoryPane (mainHeight, dpWidth') 0
    let qPrimaryPane = TextView cPrimaryPane (primaryHeight, mainWidth) (0, 0)
    let qSecondaryPane = TextView cSecondaryPane (secondaryHeight, mainWidth) (0, 0)
    return $ HSplitLayout qTitleBar qUtilityBar qDirectoryPane qPrimaryPane qSecondaryPane