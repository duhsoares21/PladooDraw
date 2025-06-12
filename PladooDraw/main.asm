.686
.model flat,stdcall
option casemap:none

include \masm32\include\windows.inc 
include \masm32\include\user32.inc
include \masm32\include\gdi32.inc
include \masm32\include\kernel32.inc

includelib PladooDraw_Direct2D_LayerSystem.lib

EXTERN Initialize:proc
WinMain proto
WinDocument proto :HWND
WinTool proto :HWND
WinLayer proto :HWND

.DATA                
    PUBLIC windowTitleInformation
    windowTitleInformation db "INFORMATION", 0

    PUBLIC windowTitleError 
    windowTitleError db "ERROR", 0
    
    PUBLIC msgText
    msgText db 256 dup(0)
    
    PUBLIC msgFmt
    msgFmt db "X: %d, Y: %d", 0         

    formatRect db "L: %d, T: %d, R: %d, B: %d", 0
    
    PUBLIC isMouseDown
    isMouseDown db 0
    
    PUBLIC brushSize
    brushSize dd 2

    PUBLIC selectedTool
    selectedTool dd 1

    PUBLIC inSession
    inSession dd 0
    
    msg MSG <>

.DATA?           
    PUBLIC color
    color COLORREF ?

    PUBLIC xInitial
    xInitial DWORD ?

    PUBLIC yInitial
    yInitial DWORD ?

    mainHwnd HWND ?
    docHwnd HWND ?

.CODE                
    start:
        
        invoke WinMain    
        mov mainHwnd, eax

        invoke WinTool, mainHwnd
        invoke WinLayer, mainHwnd
        
        invoke WinDocument, mainHwnd
        mov docHwnd, eax
        
        push docHwnd
        call Initialize
                
        .WHILE TRUE                                               
            invoke GetMessage, ADDR msg,NULL,0,0
            .BREAK .IF (!eax)
            invoke DispatchMessage, ADDR msg
        .ENDW

        invoke ExitProcess, msg.wParam                                         

    end start