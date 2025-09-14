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
EXTERN InitializeLayerRenderPreview:proc
WinMain proto
WinDocument proto :HWND
WinTool proto :HWND
WinLayer proto :HWND

LoadProjectDll PROTO STDCALL :PTR WORD, :HWND, :HINSTANCE, :PTR DWORD, :PTR DWORD, :PTR DWORD, :PTR SDWORD, :PTR WORD, :PTR BYTE

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
    pPixelSizeRatio dd 1
        
    msg MSG <>

    AppName db "Pladoo Draw",0

    EXTERN btnWidth:DWORD
    EXTERN btnHeight:DWORD
    EXTERN layerID:DWORD
    EXTERN szButtonClass:BYTE

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

    lpCmdLine   LPWSTR ?       
    argv        LPWSTR* ?      
    argc        SDWORD ?       
    pFilePath   LPWSTR ?       

    EXTERN hLayerButtons:HWND
    EXTERN hWndLayer:HWND
    EXTERN hLayerInstance:HINSTANCE

.CODE                
    start:
        
        invoke WinMain    
        mov mainHwnd, eax
        
        invoke WinTool, mainHwnd
        invoke WinDocument, mainHwnd
        invoke WinLayer, mainHwnd

        push 0
        call AddLayer
        call InitializeLayerRenderPreview

        invoke GetCommandLineW
        mov lpCmdLine, eax

        invoke CommandLineToArgvW, lpCmdLine, addr argc
        mov argv, eax

        mov eax, argc
        cmp eax, 1
        jle NoFileArg

        mov eax, argv
        mov eax, [eax+4]
        mov pFilePath, eax
        invoke LoadProjectDll, pFilePath, hWndLayer, hLayerInstance, addr btnWidth, addr btnHeight, addr hLayerButtons, addr layerID, addr szButtonClass, addr msgText

    NoFileArg:
                
        .WHILE TRUE                                               
            invoke GetMessage, ADDR msg,NULL,0,0
            .BREAK .IF (!eax)
            invoke TranslateMessage, ADDR msg
            invoke DispatchMessage, ADDR msg
        .ENDW

        invoke ExitProcess, msg.wParam                                         

    end start