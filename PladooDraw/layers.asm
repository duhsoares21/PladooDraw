.686
.model flat,stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\gdi32.inc
include \masm32\include\shell32.inc
include \masm32\include\kernel32.inc

EXTERN AddLayer: PROC
EXTERN RemoveLayer: PROC
EXTERN RenderLayers: PROC
EXTERN DrawLayerPreview: PROC
EXTERN GetLayer: PROC
EXTERN SetLayer: PROC
EXTERN GetActiveLayersCount: PROC
EXTERN LayersCount: PROC
EXTERN AddLayerButton: PROC
EXTERN InitializeLayers: PROC
EXTERN InitializeLayersButtons: PROC
EXTERN RemoveLayerButton: PROC
EXTERN OnScrollWheelLayers: PROC

Shortcuts PROTO :HWND,:WPARAM
IsLayerActive PROTO :DWORD, :PTR DWORD
LoadProjectDllW PROTO STDCALL :PTR WORD

.DATA                
    ClassName db "LayerWindowClass",0                 
    AppName db "Layers Window",0
    
    public szButtonClass
    szButtonClass db "BUTTON", 0

    isActive dd 0

    szButtonAdd db "+", 0
    szButtonDelete db "-", 0
    szButtonUp    db "Up", 0
    szButtonDown db "Down", 0

    counter DWORD 0
    counterActive DWORD 0
    totalValidLayers DWORD 0
    hasValue DWORD 0
    pt POINT <0,0>

    szTitle db "Debug",0
    
    public layerID
    layerID DWORD 0
    totalLayerCount DWORD 1

    screenWidth DWORD 0
    screenHeight DWORD 0

    PUBLIC btnWidth
    btnWidth DWORD 90

    PUBLIC btnHeight
    btnHeight DWORD 90

    hDefaultCursor HCURSOR ?
    
    hLayers DWORD ? 
    layerCount DWORD ? 
    hBitmaps DWORD ?

    PUBLIC hLayerButtons
    hLayerButtons HWND ?

    PUBLIC hControlButtons
    hControlButtons HWND 4 DUP(?)

    BtnLayerLabel db "Layer %d", 0
        
    EXTERN msgText:BYTE
	EXTERN msgFmt:BYTE

    EXTERN windowTitleInformation:BYTE
	EXTERN windowTitleError:BYTE

.DATA?           
    EXTERN layersHwnd:HWND
    EXTERN mainHwnd:HWND

    EXTERN documentWidth:DWORD
    EXTERN documentHeight:DWORD

    PUBLIC hLayerInstance
    hLayerInstance HINSTANCE ?                       

    hdc HDC ?

    lpCmdLine   LPWSTR ?       
    argv        LPWSTR* ?      
    argc        SDWORD ?       
    pFilePath   LPWSTR ? 

.CODE          

    WinLayer proc hWnd:HWND         
        LOCAL rect:RECT

        LOCAL wc:WNDCLASSEX                                         
        LOCAL msg:MSG

        invoke GetModuleHandle, NULL            

        mov hLayerInstance,eax
        mov wc.hInstance, eax
                   
        mov wc.cbSize,SIZEOF WNDCLASSEX                           
        mov wc.style, CS_HREDRAW or CS_VREDRAW
        mov wc.lpfnWndProc, OFFSET LayerWndProc
                                    
        xor eax, eax

        mov wc.hbrBackground,COLOR_BTNFACE+1
        mov wc.lpszMenuName,NULL
        mov wc.lpszClassName,OFFSET ClassName
            
        invoke LoadIcon,NULL,IDI_APPLICATION

        mov wc.hIcon,eax
        mov wc.hIconSm,eax
            
        invoke LoadCursor,NULL,IDC_ARROW
        mov wc.hCursor, eax
        mov hDefaultCursor, eax
            
        invoke RegisterClassEx, addr wc

        invoke GetClientRect, hWnd, addr rect

        .IF documentWidth > 512
            mov btnWidth, 160
            mov btnHeight, 90
        .ELSE
            mov btnWidth, 90
            mov btnHeight, 90
        .ENDIF

        mov eax, rect.right
        sub eax, btnWidth
        mov screenWidth, eax

        mov eax, rect.bottom
        mov screenHeight, eax

        invoke CreateWindowEx,
        NULL,\
        ADDR ClassName,\
        ADDR AppName,\
        WS_CHILD or WS_VISIBLE or WS_BORDER,\
        screenWidth,\
        0,\ 
        btnWidth,\
        screenHeight,\
        hWnd,\
        NULL,\
        hLayerInstance,\
        NULL
        
        mov layersHwnd, eax
        
        invoke ShowWindow,layersHwnd,SW_SHOWDEFAULT  
        invoke UpdateWindow, layersHwnd
           
        ret
    WinLayer endp

    LayerWndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
        LOCAL dwStyle:DWORD
        LOCAL parentRect:RECT
        LOCAL rect:RECT
        LOCAL className:DWORD
       
        LOCAL layerParentWidth:DWORD
        LOCAL layerParentHeight:DWORD

        .IF uMsg==WM_DESTROY                               

            invoke PostQuitMessage,NULL

            ret
        .ELSEIF uMsg == WM_MOUSEWHEEL

            push wParam
            call OnScrollWheelLayers
            ret
            
        .ELSEIF uMsg == WM_CREATE
            
            invoke GetWindowLong, hWnd, GWL_STYLE
            mov dwStyle, eax
        
            and dwStyle, NOT WS_SYSMENU
        
            invoke SetWindowLong, hWnd, GWL_STYLE, dwStyle
            
            invoke GetClientRect, hWnd, addr rect   

            mov eax, rect.bottom
            sub eax, btnHeight
            mov screenHeight, eax

            xor eax, eax

            mov eax, btnWidth
            mov ecx, 2
            div ecx

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonUp, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, screenHeight, eax, 30, hWnd, 1003, hLayerInstance, NULL 
            mov hControlButtons[10 * SIZEOF DWORD], eax

            xor eax, eax

            mov eax, btnWidth
            mov ecx, 2
            div ecx

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonDown, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, screenHeight, eax, 30, hWnd, 1004, hLayerInstance, NULL 
            mov hControlButtons[11 * SIZEOF DWORD], eax

            mov eax, screenHeight
            add eax, 30
            mov screenHeight, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonAdd, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, screenHeight, btnWidth, 30, hWnd, 1001, hLayerInstance, NULL 
            mov hControlButtons[12 * SIZEOF DWORD], eax
        
            mov eax, screenHeight
            add eax, 30
            mov screenHeight, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonDelete, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, screenHeight, btnWidth, 30, hWnd, 1002, hLayerInstance, NULL 
            mov hControlButtons[13 * SIZEOF DWORD], eax

            push hWnd
            call InitializeLayers

            push OFFSET hControlButtons
            call InitializeLayersButtons

            push 0
            push 0
            call AddLayer

            mov eax, [hLayerButtons + 0 * SIZEOF DWORD]

            push 0
            call AddLayerButton

            inc layerID

            xor eax, eax

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

            invoke LoadProjectDllW, pFilePath

            NoFileArg:
                ret

            ret
        .ELSEIF uMsg == WM_COMMAND
            .IF wParam == 1001

                push layerID ;Envia layerID para a Stack como segundo parâmetro de AddLayer
                push 0 ;Envia 0 (False) para a Stack como primeiro parâmetro de AddLayer
                call AddLayer ;Chama AddLayer (DLL)
                                
                push layerID ;Passa o layerID para a Stack como primeiro parâmetro de AddLayerButton
                call AddLayerButton ;Chama AddLayerButton (DLL)

                inc layerID ;Incrementa layerID
                
            .ELSEIF wParam == 1002
                call RemoveLayer
                call RemoveLayerButton

                invoke InvalidateRect, layersHwnd, NULL, 1
                invoke UpdateWindow, layersHwnd

                invoke RedrawWindow, hWnd, NULL, NULL, RDW_INVALIDATE or RDW_UPDATENOW or RDW_ALLCHILDREN
                
                call RenderLayers

                xor eax, eax
                ret
            .ELSEIF wParam == 1003
                 push VK_UP
                 push hWnd
                 call Shortcuts
                ret
            .ELSEIF wParam == 1004
                 push VK_DOWN
                 push hWnd
                 call Shortcuts
                ret
            .ELSE 
                push wParam
                call SetLayer
            .ENDIF
            
            ret            
        .ELSE
            invoke DefWindowProc,hWnd,uMsg,wParam,lParam
            ret
        .ENDIF

        ret
    LayerWndProc endp

    End