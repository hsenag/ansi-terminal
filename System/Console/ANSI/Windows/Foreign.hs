-- | "System.Win32.Console" is really very impoverished, so I have had to do all the FFI myself.
module System.Console.ANSI.Windows.Foreign (
        -- Re-exports from Win32.Types
        BOOL, WORD,
        
        COORD(..), SMALL_RECT(..), rect_top, rect_bottom, rect_left, rect_right,
        CONSOLE_CURSOR_INFO(..), CONSOLE_SCREEN_BUFFER_INFO(..), CHAR_INFO(..),
        
        getStdInputHandle,
        getConsoleScreenBufferInfo,
        getConsoleCursorInfo,
        
        setConsoleTextAttribute,
        setConsoleCursorPosition,
        setConsoleCursorInfo,
        
        scrollConsoleScreenBuffer
    ) where

import Data.Dynamic

import Foreign.Marshal
import Foreign.C.Types

import System.Win32.Types


peekAndOffset :: Storable a => Ptr a -> (a, Ptr b)
peekAndOffset ptr = do
    item <- peek ptr
    return (item, ptr `plusPtr` sizeOf item)

pokeAndOffset :: Storable a => Ptr a -> a -> Ptr b
pokeAndOffset ptr item = do
    poke ptr item
    return (ptr `plusPtr` sizeOf item)


data COORD = COORD {
        coord_x :: SHORT,
        coord_y :: SHORT
    }

instance Storable COORD where
    sizeOf ~(COORD x y) = sizeOf x + sizeOf y
    alignment ~(COORD x _) = alignment x
    peek ptr = do
        x <- peekElemOff ptr 0
        y <- peekElemOff ptr 1
        return (COORD x y)
    poke ptr (COORD x y) = do
        pokeElemOff ptr 0 x
        pokeElemOff ptr 1 y


data SMALL_RECT = SMALL_RECT {
        rect_top_left :: COORD,
        rect_bottom_right :: COORD
    }

rect_top, rect_left, rect_bottom, rect_right :: SMALL_RECT -> SHORT
rect_top = coord_y . rect_top_left
rect_left = coord_x . rect_top_left
rect_bottom = coord_y . rect_bottom_right
rect_right = coord_x . rect_bottom_right


instance Storable SMALL_RECT where
    sizeOf ~(SMALL_RECT tl br) = sizeOf tl + sizeOf br
    alignment ~(SMALL_RECT tl _) = alignment tl
    peek ptr = do
        tl <- peekElemOff ptr 0
        br <- peekElemOff ptr 1
        return (SMALL_RECT tl br)
    poke ptr (SMALL_RECT tl br) = do
        pokeElemOff ptr 0 tl
        pokeElemOff ptr 1 br


data CONSOLE_CURSOR_INFO = CONSOLE_CURSOR_INFO {
        cci_cursor_size :: DWORD,
        cci_cursor_visible :: BOOL
    }

instance Storable CONSOLE_CURSOR_INFO where
    sizeOf ~(CONSOLE_CURSOR_INFO size visible) = sizeOf size + sizeOf visible
    alignment ~(CONSOLE_CURSOR_INFO size _) = alignment size
    peek ptr = do
        (size, ptr') <- peekAndOffset ptr
        visible <- peek ptr'
        return (CONSOLE_CURSOR_INFO size visible)
    poke ptr (CONSOLE_CURSOR_INFO size visible) = do
        ptr' <- pokeAndOffset ptr size
        poke ptr' visible


data CONSOLE_SCREEN_BUFFER_INFO = CONSOLE_SCREEN_BUFFER_INFO {
        csbi_size :: COORD,
        csbi_cursor_position :: COORD,
        csbi_attributes :: WORD,
        csbi_window :: SMALL_RECT,
        csbi_maximum_window_size :: COORD
    }

instance Storable CONSOLE_SCREEN_BUFFER_INFO where
    sizeOf ~(CONSOLE_SCREEN_BUFFER_INFO size cursor_position attributes window maximum_window_size)
      = sizeOf size + sizeOf cursor_position + sizeOff attributes + sizeOf window + sizeOf maximum_window_size
    alignment ~(CONSOLE_SCREEN_BUFFER_INFO size _ _ _ _) = alignment size
    peek ptr = do
        (size, ptr1) <- peekAndOffset ptr
        (cursor_position, ptr2) <- peekAndOffset ptr1
        (attributes, ptr3) <- peekAndOffset ptr2
        (window, ptr4) <- peekAndOffset ptr3
        maximum_window_size <- peek ptr4
        return (CONSOLE_SCREEN_BUFFER_INFO size cursor_position attributes window maximum_window_size)
    poke ptr (CONSOLE_CURSOR_INFO size visible) = do
        ptr1 <- pokeAndOffset ptr size
        ptr2 <- pokeAndOffset ptr1 cursor_position
        ptr3 <- pokeAndOffset ptr2 attribute
        ptr4 <- pokeAndOffset ptr3 window
        poke ptr4 maximum_window_size


data CHAR_INFO = CHAR_INFO {
        ci_char :: WCHAR
        ci_attributes :: WORD
    }

instance Storable CHAR_INFO where
    sizeOf ~(CHAR_INFO char attributes) = sizeOf char + sizeOf attributes
    alignment ~(CHAR_INFO char _) = alignment char
    peek ptr = do
        (char, ptr') <- peekAndOffset ptr
        attributes <- peek ptr'
        return (CONSOLE_CURSOR_INFO char attributes)
    poke ptr (CONSOLE_CURSOR_INFO char attributes) = do
        ptr' <- pokeAndOffset ptr char
        poke ptr' attributes


sTD_OUTPUT_HANDLE :: DWORD
--sTD_INPUT_HANDLE = -10
sTD_OUTPUT_HANDLE = -11
--sTD_ERROR_HANDLE = -12


foreign import stdcall unsafe "windows.h GetStdHandle" cGetStdHandle :: DWORD -> IO HANDLE
foreign import stdcall unsafe "windows.h GetConsoleScreenBufferInfo" cGetConsoleScreenBufferInfo :: HANDLE -> Ptr CONSOLE_SCREEN_BUFFER_INFO -> IO BOOL
foreign import stdcall unsafe "windows.h GetConsoleCursorInfo" cGetConsoleCursorInfo :: HANDLE -> Ptr CONSOLE_CURSOR_INFO -> IO BOOL

foreign import stdcall unsafe "windows.h SetConsoleTextAttribute" cSetConsoleTextAttribute :: HANDLE -> CWord -> IO BOOL
foreign import stdcall unsafe "windows.h SetConsoleCursorPosition" cSetConsoleCursorPosition :: HANDLE -> COORD -> IO BOOL
foreign import stdcall unsafe "windows.h SetConsoleCursorInfo" cSetConsoleCursorInfo :: HANDLE -> Ptr CONSOLE_CURSOR_INFO -> IO BOOL

foreign import stdcall unsafe "windows.h ScrollConsoleScreenBuffer" cScrollConsoleScreenBuffer :: HANDLE -> Ptr SMALL_RECT -> Ptr SMALL_RECT -> COORD -> Ptr CHAR_INFO -> IO BOOL


getStdInputHandle :: IO HANDLE
getStdInputHandle = cGetStdHandle sTD_INPUT_HANDLE

getConsoleScreenBufferInfo :: HANDLE -> IO CONSOLE_SCREEN_BUFFER_INFO
getConsoleScreenBufferInfo handle = alloca $ \ptr_console_screen_buffer_info -> do
    failIfFalse_ "getConsoleScreenBufferInfo" $ cGetConsoleScreenBufferInfo handle ptr_console_screen_buffer_info
    peek ptr_console_screen_buffer_info

getConsoleCursorInfo :: HANDLE -> IO CONSOLE_CURSOR_INFO
getConsoleCursorInfo handle = alloca $ \ptr_console_cursor_info -> do
    failIfFalse_ "getConsoleCursorInfo" $ cGetConsoleCursorInfo handle ptr_console_cursor_info
    peek ptr_console_cursor_info


setConsoleTextAttribute :: HANDLE -> CWord -> IO ()
setConsoleTextAttribute handle attributes = failIfFalse_ "setConsoleTextAttribute" $ cSetConsoleTextAttribute handle attributes

setConsoleCursorPosition :: HANDLE -> COORD -> IO ()
setConsoleCursorPosition handle coordinates = failIfFalse_ "setConsoleCursorPosition" $ cSetConsoleCursorPosition handle coordinates

setConsoleCursorInfo :: HANDLE -> CONSOLE_CURSOR_INFO -> IO ()
setConsoleCursorInfo handle console_cursor_info = with console_cursor_info $ \ptr_console_cursor_info -> do
    failIfFalse_ "setConsoleCursorInfo" $ cSetConsoleCursorInfo handle ptr_console_cursor_info

scrollConsoleScreenBuffer :: HANDLE -> SMALL_RECT -> Maybe SMALL_RECT -> COORD -> CHAR_INFO -> IO ()
scrollConsoleScreenBuffer handle scroll_rectangle mb_clip_rectangle destination_origin fill 
  = with scroll_rectangle $ \ptr_scroll_rectangle ->
    maybeWith with mb_clip_rectangle $ \ptr_clip_rectangle ->
    with fill $ \ptr_fill ->
    failIfFalse_ "scrollConsoleScreenBuffer" $ cScrollConsoleScreenBuffer handle ptr_scroll_rectangle ptr_clip_rectangle destination_origin ptr_fill