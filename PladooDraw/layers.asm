.686
.model flat,stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\gdi32.inc
include \masm32\include\kernel32.inc

EXTERN AddLayer: PROC
EXTERN SetLayer: PROC
EXTERN LayersCount: PROC

.DATA                
    ClassName db "LayerWindowClass",0                 
    AppName db "Layers Window",0
    
    szButtonClass db "BUTTON", 0

    szButtonAdd db "+", 0
    szButtonDelete db "-", 0
    szButtonUp db "UP", 0
    szButtonDown db "DOWN", 0
    
    layerID DWORD 0
    totalLayerCount DWORD 0

    screenWidth DWORD 0
    screenHeight DWORD 0

    btnHeight DWORD 30

    hDefaultCursor HCURSOR ?
    
    hLayers DWORD ? 
    layerCount DWORD ? 
    hBitmaps DWORD ?

    hLayerButtons HWND ? 
    hControlButtons HWND ?

    BtnLayerLabel db "Layer %d", 0
        
    EXTERN msgText:BYTE
	EXTERN msgFmt:BYTE

    EXTERN windowTitleInformation:BYTE
	EXTERN windowTitleError:BYTE

.DATA?           
    hWndLayer HWND ?
    mainHwnd HWND ?    

    hLayerInstance HINSTANCE ?                       

    hdc HDC ?

.CODE          

    RepositionLayerToolbar proc xPos:DWORD, yPos:DWORD, nWidth:DWORD, nHeight:DWORD
        LOCAL rect:RECT

        mov ecx, xPos
        sub ecx, nWidth
        mov xPos, ecx

        invoke MoveWindow, hWndLayer, xPos, yPos, nWidth, nHeight, TRUE

        invoke GetClientRect, hWndLayer, addr rect

        mov eax, rect.bottom
        sub eax, 60
        mov screenHeight, eax

        invoke MoveWindow, [hLayerButtons + 0 * SIZEOF DWORD], 0, screenHeight, 120, 30, TRUE
       
        mov eax, screenHeight
        add eax, 30
        mov screenHeight, eax

        invoke MoveWindow, [hLayerButtons + 1 * SIZEOF DWORD], 0, screenHeight, 120, 30, TRUE
        ret
    RepositionLayerToolbar endp

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

        mov eax, rect.right
        sub eax, 120
        mov screenWidth, eax

        mov eax, rect.bottom
        mov screenHeight, eax

        invoke CreateWindowEx,
        NULL,\
        ADDR ClassName,\
        ADDR AppName,\
        WS_CHILD or WS_VISIBLE or CCS_VERT or TBSTYLE_TOOLTIPS or TBSTYLE_FLAT,\
        screenWidth,\
        0,\
        120,\
        screenHeight,\
        hWnd,\
        NULL,\
        hLayerInstance,\
        NULL
        
        mov hWndLayer, eax

        mov ecx, hWnd
        mov mainHwnd, ecx
        
        invoke ShowWindow,hWndLayer,SW_SHOWDEFAULT
        invoke UpdateWindow, hWndLayer
           
        ret
    WinLayer endp

    LayerWndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
        LOCAL dwStyle:DWORD
        LOCAL parentRect:RECT
        LOCAL rect:RECT
        LOCAL className:DWORD

        .IF uMsg==WM_DESTROY                               

            invoke PostQuitMessage,NULL

            ret
        .ELSEIF uMsg == WM_CREATE

            invoke GetWindowLong, hWnd, GWL_STYLE
            mov dwStyle, eax
        
            and dwStyle, NOT WS_SYSMENU
        
            invoke SetWindowLong, hWnd, GWL_STYLE, dwStyle

            invoke wsprintfA, offset msgText, offset BtnLayerLabel, layerID
            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET msgText, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, 0, 120, btnHeight, hWnd, layerID, hLayerInstance, NULL 
            mov [hLayerButtons + edx * SIZEOF DWORD], eax

            invoke GetClientRect, hWnd, addr rect

            mov eax, rect.bottom
            sub eax, 60
            mov screenHeight, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonAdd, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, screenHeight, 120, 30, hWnd, 1001, hLayerInstance, NULL 
            mov [hLayerButtons + 0 * SIZEOF DWORD], eax
        
            mov eax, screenHeight
            add eax, 30
            mov screenHeight, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonDelete, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, screenHeight, 120, 30, hWnd, 1002, hLayerInstance, NULL 
            mov [hLayerButtons + 1 * SIZEOF DWORD], eax

            ret
        .ELSEIF uMsg == WM_COMMAND
            .IF wParam == 1001
                call AddLayer
                
                inc layerID

                mov eax, btnHeight 
                mul layerID
                mov ebx, eax
            
                invoke wsprintfA, offset msgText, offset BtnLayerLabel, layerID
                invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET msgText, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, ebx, 120, btnHeight, hWnd, layerID, hLayerInstance, NULL 
                mov [hLayerButtons + edx * SIZEOF DWORD], eax

                invoke RedrawWindow, hWnd, NULL, NULL, RDW_INVALIDATE or RDW_UPDATENOW
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