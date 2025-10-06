.686
.model flat,stdcall
option casemap:none

include \masm32\include\windows.inc 
include \masm32\include\user32.inc
include \masm32\include\gdi32.inc
include \masm32\include\shell32.inc
include \masm32\include\kernel32.inc

includelib msvcrt.lib
includelib PladooDraw_Direct2D_LayerSystem.lib

EXTERN Initialize:proc
EXTERN AddLayer:proc

WinMain PROTO

.DATA                
    PUBLIC windowTitleInformation
    windowTitleInformation db "INFORMATION", 0

    PUBLIC windowTitleError 
    windowTitleError db "ERROR", 0
    
    PUBLIC msgText
    msgText db 256 dup(0)
    
    PUBLIC msgFmt
    msgFmt db "Error code: 0x%08X", 0         

    formatRect db "L: %d, T: %d, R: %d, B: %d", 0
    
    PUBLIC isMouseDown
    isMouseDown db 0
    
    PUBLIC brushSize
    brushSize dd 1

    PUBLIC selectedTool
    selectedTool dd 1

    PUBLIC inSession
    inSession dd 0

    PUBLIC pPixelSizeRatio

    PUBLIC panOffsetX
    panOffsetX DWORD 0

    PUBLIC panOffsetY
    panOffsetY DWORD 0

    pPixelSizeRatio dd 1
        
    msg MSG <>

    AppName db "Pladoo Draw",0

.DATA?           
    PUBLIC color
    color COLORREF ?

    PUBLIC xInitial
    xInitial DWORD ?

    PUBLIC yInitial
    yInitial DWORD ?

    PUBLIC mainHwnd
    mainHwnd HWND ?

    PUBLIC docHwnd
    docHwnd HWND ?

    PUBLIC toolsHwnd
    toolsHwnd HWND ?

    public layersHwnd
    layersHwnd HWND ?

    public layersListHwnd
    layersListHwnd HWND ?

    public documentWidth
    documentWidth DWORD ?

    public documentHeight
    documentHeight DWORD ?
.CODE                
    start:
        
        invoke WinMain
                
        .WHILE TRUE                                               
            invoke GetMessage, ADDR msg,NULL,0,0
            .BREAK .IF (!eax)
            invoke TranslateMessage, ADDR msg
            invoke DispatchMessage, ADDR msg
        .ENDW

        invoke ExitProcess, msg.wParam                                         

    end start