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
EXTERN InitializeLayerRenderPreview:proc
EXTERN RemoveLayerButton: PROC
EXTERN OnScrollWheelLayers: PROC

Shortcuts PROTO :WPARAM
IsLayerActive PROTO :DWORD, :PTR DWORD
SetZoomFactor PROTO STDCALL :DWORD

.DATA                
    ClassName db "layerWindowClass",0                 
    AppName db "Layers Window",0
    
    LayerGroupClassName db "layerGroupClass",0                 
    ControlButtonsClassName db "layerGroupButtonsClass", 0

    EXTERN szButtonClass:BYTE

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

    hDefaultCursor HCURSOR ?
    
    hLayers DWORD ? 
    layerCount DWORD ? 
    hBitmaps DWORD ?

    PUBLIC hLayerButtons
    hLayerButtons HWND ?

    EXTERN hControlButtons:HWND

    BtnLayerLabel db "Layer %d", 0

    szErrorTitle db "ERROR", 0
        
    EXTERN msgText:BYTE
	EXTERN msgFmt:BYTE

    EXTERN windowTitleInformation:BYTE
	EXTERN windowTitleError:BYTE

    EXTERN btnWidth:DWORD
    EXTERN btnHeight:DWORD

.DATA?           
    EXTERN toolsHwnd:HWND
    EXTERN layerWindowHwnd:HWND
    EXTERN mainHwnd:HWND

    EXTERN documentWidth:DWORD
    EXTERN documentHeight:DWORD

    layersHwnd HWND ?
    layersControlButtonsGroupHwnd HWND ?

    PUBLIC hLayerInstance
    hLayerInstance HINSTANCE ?                       

    hdc HDC ?

.CODE          

    
ShowLastError PROC lpTitle:PTR BYTE
    LOCAL errCode:DWORD
    LOCAL lpMsgBuf:DWORD

    ; obtém o código do erro
    invoke GetLastError
    mov errCode, eax

    ; formata a mensagem do erro em texto legível
    invoke FormatMessage, \
        FORMAT_MESSAGE_ALLOCATE_BUFFER or FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS, \
        NULL, errCode, 0, addr lpMsgBuf, 0, NULL

    ; mostra na messagebox
    invoke MessageBox, NULL, lpMsgBuf, lpTitle, MB_OK or MB_ICONERROR

    ; libera o buffer alocado internamente por FormatMessage
    invoke LocalFree, lpMsgBuf

    ret
ShowLastError ENDP    

    WinLayer proc hWnd:HWND         
        LOCAL rect:RECT

        LOCAL wc:WNDCLASSEX                                         
        LOCAL msg:MSG

        invoke GetModuleHandle, NULL            

        invoke RtlZeroMemory, addr wc, SIZEOF WNDCLASSEX

        mov hLayerInstance,eax
        mov wc.hInstance, eax
                   
        mov wc.cbSize,SIZEOF WNDCLASSEX                           
        mov wc.style, CS_HREDRAW or CS_VREDRAW
        mov wc.lpfnWndProc, OFFSET LayerWndProc
                                    
        xor eax, eax

        mov wc.hbrBackground,COLOR_WINDOWFRAME+1
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
        sub eax, rect.left
        sub eax, btnWidth
        mov screenWidth, eax

        mov eax, rect.bottom
        mov screenHeight, eax

        invoke CreateWindowEx,
        NULL,\
        ADDR ClassName,\
        ADDR AppName,\
        WS_VISIBLE or WS_BORDER,\
        screenWidth,\
        35,\ 
        btnWidth,\
        screenHeight,\
        hWnd,\
        NULL,\
        hLayerInstance,\
        NULL
        
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
            mov ecx, hWnd
            mov layerWindowHwnd, ecx

            invoke GetWindowLong, hWnd, GWL_STYLE
            mov dwStyle, eax
        
            and dwStyle, NOT WS_SYSMENU
        
            invoke SetWindowLong, hWnd, GWL_STYLE, dwStyle   
                    
            invoke ShowWindow,hWnd,SW_SHOWDEFAULT  
            invoke UpdateWindow, hWnd
            
            push hWnd
            call WinLayersGroup 
            ret
        .ELSEIF uMsg == WM_COMMAND
            .IF 
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

    WinLayersGroup proc hWnd:HWND
        LOCAL rect:RECT

        LOCAL wc:WNDCLASSEX                                         
        LOCAL msg:MSG

        LOCAL layerParentWidth:DWORD
        LOCAL layerParentHeight:DWORD

        invoke RtlZeroMemory, addr wc, SIZEOF WNDCLASSEX

        invoke GetModuleHandle, NULL            

        mov hLayerInstance,eax
        mov wc.hInstance, eax
                   
        mov wc.cbSize,SIZEOF WNDCLASSEX                           
        mov wc.style, CS_HREDRAW or CS_VREDRAW
        mov wc.lpfnWndProc, OFFSET LayerGroupWndProc

        xor eax, eax
                                    
        mov wc.hbrBackground,COLOR_WINDOWFRAME+1
        mov wc.lpszMenuName,NULL
        mov wc.lpszClassName, OFFSET LayerGroupClassName
            
        invoke LoadIcon,NULL,IDI_APPLICATION

        mov wc.hIcon,eax
        mov wc.hIconSm,eax
            
        invoke LoadCursor,NULL,IDC_ARROW
        mov wc.hCursor, eax
        mov hDefaultCursor, eax
            
        invoke RegisterClassEx, addr wc

        invoke GetClientRect, hWnd, addr rect

        mov eax, rect.right
        mov ecx, rect.left
        sub eax, ecx

        mov layerParentWidth, eax

        mov eax, rect.bottom
        mov ecx, rect.top
        sub eax, ecx
        sub eax, 90

        mov layerParentHeight, eax

        invoke CreateWindowEx, 0, ADDR LayerGroupClassName, NULL, WS_CHILD or WS_VISIBLE or WS_BORDER, 0, 0, layerParentWidth, layerParentHeight, hWnd, NULL, hLayerInstance, NULL

        .IF eax == 0 
            invoke ShowLastError, OFFSET szErrorTitle
        .ENDIF

        ret
    WinLayersGroup endp

    LayerGroupWndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
        .IF uMsg == WM_COMMAND
            .IF wParam >= 0 && wParam <= 1000 
                push wParam
                call SetLayer
            .ENDIF
        .ELSEIF uMsg == WM_CREATE
            mov ecx, hWnd
            mov layersHwnd, ecx

            push layerWindowHwnd
            call WinControlButtonsGroup

            ret
        .ELSE
            invoke DefWindowProc,hWnd,uMsg,wParam,lParam
            ret
        .ENDIF
        ret
    LayerGroupWndProc endp

    WinControlButtonsGroup proc hWnd:HWND

        LOCAL rect:RECT

        LOCAL wc:WNDCLASSEX                                         
        LOCAL msg:MSG

        LOCAL layerParentWidth:DWORD
        LOCAL layerParentHeight:DWORD

        invoke GetModuleHandle, NULL     
        
        invoke RtlZeroMemory, addr wc, SIZEOF WNDCLASSEX

        mov hLayerInstance,eax
        mov wc.hInstance, eax
                   
        mov wc.cbSize,SIZEOF WNDCLASSEX                           
        mov wc.style, CS_HREDRAW or CS_VREDRAW
        mov wc.lpfnWndProc, OFFSET ControlGroupWndProc
                                    
        xor eax, eax

        mov wc.hbrBackground,COLOR_WINDOWFRAME+1
        mov wc.lpszMenuName,NULL
        mov wc.lpszClassName,OFFSET ControlButtonsClassName
            
        invoke LoadIcon,NULL,IDI_APPLICATION

        mov wc.hIcon,eax
        mov wc.hIconSm,eax
            
        invoke LoadCursor,NULL,IDC_ARROW
        mov wc.hCursor, eax
        mov hDefaultCursor, eax
            
        invoke RegisterClassEx, addr wc

        invoke GetClientRect, hWnd, addr rect

        mov eax, rect.right
        mov ecx, rect.left
        sub eax, ecx

        mov layerParentWidth, eax

        mov eax, rect.bottom
        mov ecx, rect.top
        sub eax, ecx
        sub eax, btnHeight
        add eax, 30

        mov layerParentHeight, eax

        invoke CreateWindowEx, 0, addr ControlButtonsClassName, NULL, WS_CHILD or WS_VISIBLE or WS_BORDER,0, layerParentHeight, layerParentWidth, btnHeight, layerWindowHwnd, NULL, hLayerInstance, NULL
        
        ret
    WinControlButtonsGroup endp
    
    ControlGroupWndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
        LOCAL rect:RECT

        .IF uMsg == WM_COMMAND
            .IF wParam == 1001

                call LayersCount

                mov layerID, eax

                push layerID ;Envia layerID para a Stack como segundo parâmetro de AddLayer
                push 0 ;Envia 0 (False) para a Stack como primeiro parâmetro de AddLayer
                call AddLayer ;Chama AddLayer (DLL)
                                
                push layerID ;Passa o layerID para a Stack como primeiro parâmetro de AddLayerButton
                call AddLayerButton ;Chama AddLayerButton (DLL)

                ;inc layerID ;Incrementa layerID
                
            .ELSEIF wParam == 1002
                call RemoveLayer
                call RemoveLayerButton

                invoke InvalidateRect, layerWindowHwnd, NULL, 1
                invoke UpdateWindow, layerWindowHwnd

                invoke RedrawWindow, hWnd, NULL, NULL, RDW_INVALIDATE or RDW_UPDATENOW or RDW_ALLCHILDREN
                
                call RenderLayers

                xor eax, eax
                ret
            .ELSEIF wParam == 1003
                 push VK_UP
                 call Shortcuts
                ret
            .ELSEIF wParam == 1004
                 push VK_DOWN
                 call Shortcuts
                ret
            .ENDIF
        .ELSEIF uMsg == WM_CREATE
            mov ecx, hWnd
            mov layersControlButtonsGroupHwnd, ecx

            invoke GetClientRect, hWnd, addr rect

            mov eax, rect.bottom
            sub eax, btnHeight
            mov screenHeight, eax

            xor eax, eax

            mov eax, btnWidth
            mov ecx, 2
            div ecx
            sub eax, 8

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonUp, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, 0, eax, 30, layersControlButtonsGroupHwnd, 1003, hLayerInstance, NULL 
            mov hControlButtons[0 * SIZEOF DWORD], eax

            xor eax, eax

            mov eax, btnWidth
            mov ecx, 2
            div ecx
            sub eax, 8

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonDown, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, 0, eax, 30, layersControlButtonsGroupHwnd, 1004, hLayerInstance, NULL 
            mov hControlButtons[1 * SIZEOF DWORD], eax

            mov eax, 0
            add eax, 30
            mov screenHeight, eax

            mov eax, btnWidth
            sub eax, 16

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonAdd, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, screenHeight, eax, 30, layersControlButtonsGroupHwnd, 1001, hLayerInstance, NULL 
            mov hControlButtons[2 * SIZEOF DWORD], eax
        
            mov eax, screenHeight
            add eax, 30
            mov screenHeight, eax

            mov eax, btnWidth
            sub eax, 16

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonDelete, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, screenHeight, eax, 30, layersControlButtonsGroupHwnd, 1002, hLayerInstance, NULL 
            mov hControlButtons[3 * SIZEOF DWORD], eax

            push layersControlButtonsGroupHwnd
            push layersHwnd
            push layerWindowHwnd
            call InitializeLayers

            push OFFSET hControlButtons
            call InitializeLayersButtons

            push 0
            push 0
            call AddLayer

            mov eax, [hLayerButtons + 0 * SIZEOF DWORD]

            push 0
            call AddLayerButton
       
            call InitializeLayerRenderPreview

            invoke SetZoomFactor, 1

            xor eax, eax
            ret
        .ELSE
            invoke DefWindowProc,hWnd,uMsg,wParam,lParam
            ret
        .ENDIF
        ret
    ControlGroupWndProc endp

    End