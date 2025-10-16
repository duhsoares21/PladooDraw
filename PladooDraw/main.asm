.686

.MODEL flat,stdcall

include \masm32\include\windows.inc 
include \masm32\include\user32.inc
include \masm32\include\gdi32.inc
include \masm32\include\shell32.inc
include \masm32\include\kernel32.inc

include resource_cursors.inc

includelib msvcrt.lib
includelib PladooDraw_Direct2D_LayerSystem.lib

EXTERN Initialize:proc
EXTERN AddLayer:proc
EXTERN EditFromThisPoint:proc
EXTERN Cleanup:proc
EXTERN Initialize:proc
EXTERN InitializeSurfaceDial:proc
EXTERN RenderLayers:proc
EXTERN UpdateLayers:proc
EXTERN SetReplayMode:proc

StartDraw proto

SetZoomFactor PROTO STDCALL :DWORD

WinCreateProject proto :HWND

LoadProjectDllW PROTO STDCALL :PTR WORD

.DATA                
    ClassName db "MainWindowClass",0   
    AppName db "Pladoo Draw",0 
    
    PUBLIC szButtonClass
    szButtonClass db "BUTTON", 0

    PUBLIC windowTitleInformation
    windowTitleInformation db "INFORMATION", 0

    PUBLIC windowTitleError 
    windowTitleError db "ERROR", 0
    
    PUBLIC msgText
    msgText db 256 dup(0)
    
    PUBLIC msgFmt
    msgFmt db "Error code: 0x%08X", 0         

    formatRect db "L: %d, T: %d, R: %d, B: %d", 0

    mainWindowWidth dd 0
    mainWindowHeight dd 0
    
    PUBLIC replayModeFlag
    replayModeFlag DWORD 0

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

    public layerWindowHwnd
    layerWindowHwnd HWND ?

    public replayHwnd
    replayHwnd HWND ?

    public createProjectHwnd
    createProjectHwnd HWND ?

    public documentWidth
    documentWidth DWORD ?

    public documentHeight
    documentHeight DWORD ?

    PUBLIC btnWidth
    btnWidth DWORD ?

    PUBLIC btnHeight
    btnHeight DWORD ?

    PUBLIC hControlButtons
    hControlButtons HWND 4 DUP(?)

    PUBLIC hMainInstance
    hMainInstance HINSTANCE ?

    PUBLIC hDefaultCursor
    hDefaultCursor HCURSOR ?

    PUBLIC EditFromThisPointHWND
    EditFromThisPointHWND HWND ?

    lpCmdLine   LPWSTR ?       
    argv        LPWSTR* ?      
    argc        SDWORD ?       
    pFilePath   LPWSTR ? 

.CODE            

    WinMain proc
            LOCAL wc:WNDCLASSEX                                         
            LOCAL workArea: RECT

             invoke RtlZeroMemory, addr wc, SIZEOF WNDCLASSEX

            mov color, 00000000h
            
            mov wc.cbClsExtra, 0
            mov wc.cbWndExtra, 0
            
            mov wc.cbSize,SIZEOF WNDCLASSEX                           
            mov wc.style, CS_HREDRAW or CS_VREDRAW
            mov wc.lpfnWndProc, OFFSET WndMainProc

            invoke GetModuleHandle, NULL            
            mov wc.hInstance, eax
            mov hMainInstance, eax

            xor eax, eax

            mov wc.hbrBackground,COLOR_WINDOWFRAME+1
            mov wc.lpszMenuName,NULL
            mov wc.lpszClassName,OFFSET ClassName
            
            invoke LoadIcon,hMainInstance,ID_ICON_APPLICATION

            mov wc.hIcon,eax
            mov wc.hIconSm,eax
            
            invoke LoadCursor,NULL,IDC_ARROW
            mov wc.hCursor, eax
            mov hDefaultCursor, eax
        
            invoke RegisterClassEx, addr wc    
                   
            invoke CreateWindowEx, 
            NULL, 
            ADDR ClassName, 
            ADDR AppName, 
            WS_OVERLAPPEDWINDOW or WS_CLIPCHILDREN, 
            CW_USEDEFAULT, 
            CW_USEDEFAULT, 
            CW_USEDEFAULT, 
            CW_USEDEFAULT, 
            NULL, 
            NULL, 
            hMainInstance, 
            NULL

            mov mainHwnd, eax

            invoke SystemParametersInfo, SPI_GETWORKAREA, 0, addr workArea, 0
            invoke SetWindowPos, mainHwnd, NULL, workArea.left, workArea.top, workArea.right, workArea.bottom, SWP_NOZORDER

            invoke ShowWindow,mainHwnd,SW_SHOW
            invoke UpdateWindow, mainHwnd
            
            ret
        WinMain endp

        WndMainProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
            LOCAL dwStyle:DWORD
            LOCAL rect:RECT

            LOCAL parentWidth:DWORD
            LOCAL halfParentWidth:DWORD
            LOCAL xCenter:DWORD

            .IF uMsg==WM_DESTROY
                
                call Cleanup
                invoke PostQuitMessage,NULL

                ret
            .ELSEIF uMsg == WM_SIZE

                mov eax, lParam
                and eax, 0000FFFFh
                mov mainWindowWidth, eax  
    
                mov eax, lParam
                shr eax, 16              
                mov mainWindowHeight, eax
            
                invoke RedrawWindow, hWnd, NULL, NULL, RDW_INVALIDATE or RDW_UPDATENOW
                ret
            .ELSEIF uMsg == WM_CREATE

                invoke GetWindowLong, hWnd, GWL_STYLE
                mov dwStyle, eax
        
                invoke SetWindowLong, hWnd, GWL_STYLE, dwStyle
                invoke SetCursor, hDefaultCursor

                ret
            .ELSEIF uMsg == WM_SHOWWINDOW
                
                mov documentWidth, 512
                mov documentHeight, 512

                invoke GetCommandLineW
                mov lpCmdLine, eax

                invoke CommandLineToArgvW, lpCmdLine, addr argc
                mov argv, eax

                mov eax, argc
                cmp eax, 1
                jle NoFileArg

                call StartDraw

                mov eax, argv
                mov eax, [eax+4]
                mov pFilePath, eax

                invoke LoadProjectDllW, pFilePath
                jmp LabelEndProc

                NoFileArg:
                    push hWnd
                    call WinCreateProject

                LabelEndProc:
                    ret

            .ELSEIF uMsg == WM_COMMAND
                .IF wParam == 109
            
                    invoke SendDlgItemMessage, hWnd, 108, BM_CLICK, 0, 0

                    call EditFromThisPoint
                
                    push -1
                    call UpdateLayers
                
                    call RenderLayers
                    ret
                .ELSEIF wParam == 108
                    ; Get checkbox state
                    invoke SendDlgItemMessage, hWnd, 108, BM_GETCHECK, 0, 0
                    
                    .IF eax == BST_CHECKED
                        mov replayModeFlag, 1
                        invoke SetZoomFactor, 1
                        invoke ShowWindow,toolsHwnd,SW_HIDE
                        invoke ShowWindow,layerWindowHwnd,SW_HIDE
                        invoke ShowWindow,replayHwnd,SW_SHOWDEFAULT
                        invoke ShowWindow,EditFromThisPointHWND,SW_SHOWDEFAULT
                        
                    .ELSE
                        mov replayModeFlag, 0
                        call RenderLayers
                        invoke ShowWindow,toolsHwnd,SW_SHOWDEFAULT
                        invoke ShowWindow,layerWindowHwnd,SW_SHOWDEFAULT
                        invoke ShowWindow,replayHwnd,SW_HIDE
                        invoke ShowWindow,EditFromThisPointHWND,SW_HIDE
                    .ENDIF

                    push replayModeFlag
                    call SetReplayMode
                    ret
                .ENDIF
                ret
            .ELSE
                invoke DefWindowProc,hWnd,uMsg,wParam,lParam
                ret
            .ENDIF

            xor eax,eax
            ret
    WndMainProc endp     

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