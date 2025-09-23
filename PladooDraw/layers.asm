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
EXTERN RemoveLayerButton: PROC

Shortcuts proto :HWND,:WPARAM
LoadProjectDllW PROTO STDCALL :PTR WORD, :HWND, :HINSTANCE, :PTR DWORD, :PTR DWORD, :PTR DWORD, :DWORD, :PTR WORD, :PTR BYTE

.DATA                
    ClassName db "LayerWindowClass",0                 
    AppName db "Layers Window",0
    
    public szButtonClass
    szButtonClass db "BUTTON", 0

    szButtonAdd db "+", 0
    szButtonDelete db "-", 0
    szButtonUp    db "Up", 0
    szButtonDown db "Down", 0
    
    public layerID
    layerID DWORD 0
    totalLayerCount DWORD 0

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

    hControlButtons HWND ?

    BtnLayerLabel db "Layer %d", 0
        
    EXTERN msgText:BYTE
	EXTERN msgFmt:BYTE

    EXTERN windowTitleInformation:BYTE
	EXTERN windowTitleError:BYTE

.DATA?           
    PUBLIC hWndLayer
    hWndLayer HWND ?
    mainHwnd HWND ?    

    PUBLIC hLayerInstance
    hLayerInstance HINSTANCE ?                       

    hdc HDC ?

    lpCmdLine   LPWSTR ?       
    argv        LPWSTR* ?      
    argc        SDWORD ?       
    pFilePath   LPWSTR ? 

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
        sub eax, 109
        mov screenWidth, eax

        mov eax, rect.bottom
        mov screenHeight, eax

        invoke CreateWindowEx,
        NULL,\
        ADDR ClassName,\
        ADDR AppName,\
        WS_CHILD or WS_VISIBLE or WS_BORDER or WS_VSCROLL,\
        screenWidth,\
        0,\ 
        109,\
        screenHeight,\
        hWnd,\
        NULL,\
        hLayerInstance,\
        NULL
        
        mov hWndLayer, eax

        push hWndLayer
        call InitializeLayers

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

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET msgText, WS_CHILD or WS_VISIBLE or WS_BORDER or BS_AUTOCHECKBOX or BS_PUSHLIKE, 0, 0, btnWidth, btnHeight, hWnd, layerID, hLayerInstance, NULL 
            mov [hLayerButtons + 0 * SIZEOF DWORD], eax
            
            invoke GetClientRect, hWnd, addr rect   

            mov eax, rect.bottom
            sub eax, 90
            mov screenHeight, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonUp, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, screenHeight, 45, 30, hWnd, 1003, hLayerInstance, NULL 
            mov [hControlButtons + 0 * SIZEOF DWORD], eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonDown, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 45, screenHeight, 45, 30, hWnd, 1004, hLayerInstance, NULL 
            mov [hControlButtons + 1 * SIZEOF DWORD], eax

            mov eax, screenHeight
            add eax, 30
            mov screenHeight, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonAdd, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, screenHeight, btnWidth, 30, hWnd, 1001, hLayerInstance, NULL 
            mov [hControlButtons + 2 * SIZEOF DWORD], eax
        
            mov eax, screenHeight
            add eax, 30
            mov screenHeight, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonDelete, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, screenHeight, btnWidth, 30, hWnd, 1002, hLayerInstance, NULL 
            mov [hControlButtons + 3 * SIZEOF DWORD], eax

            push 0
            push 0
            call AddLayer

            mov eax, [hLayerButtons + 0 * SIZEOF DWORD]

            push eax
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

            invoke LoadProjectDllW, pFilePath, hWnd, hLayerInstance, btnWidth, btnHeight, addr hLayerButtons, layerID, addr szButtonClass, addr msgText

            NoFileArg:
                ret

            ret
        .ELSEIF uMsg == WM_COMMAND
            .IF wParam == 1001

                call GetActiveLayersCount
                mov edx, eax
                
                xor eax, eax
                
                mov eax, btnHeight  
                mul ecx
                mov ebx, eax
            
                mov edx, layerID
                
                push edx
                push 0
                call AddLayer

                invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET msgText, WS_CHILD or WS_VISIBLE or WS_BORDER or BS_BITMAP, 0, ebx, btnWidth, btnHeight, hWnd, layerID, hLayerInstance, NULL 
                mov [hLayerButtons + edx * SIZEOF DWORD], eax

                push eax
                call AddLayerButton

                invoke RedrawWindow, hWnd, NULL, NULL, RDW_INVALIDATE or RDW_UPDATENOW

                push edx
                call SetLayer

                inc layerID
                
            .ELSEIF wParam == 1002
                call RemoveLayer
                call RemoveLayerButton

                invoke InvalidateRect, hWndLayer, NULL, 1
                invoke UpdateWindow, hWndLayer

                invoke RedrawWindow, hWnd, NULL, NULL, RDW_INVALIDATE or RDW_UPDATENOW or RDW_ALLCHILDREN
                invoke SendMessageA, hWnd, WM_COMMAND, 1002, 0
                
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