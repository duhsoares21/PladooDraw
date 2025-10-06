.686

.MODEL flat, stdcall

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\gdi32.inc
include \masm32\include\shell32.inc
include \masm32\include\kernel32.inc
include \masm32\include\msimg32.inc

include resource_cursors.inc

includelib \masm32\lib\msimg32.lib

includelib PladooDraw_Direct2D_LayerSystem.lib

EXTERN handleMouseUp:proc
EXTERN PaintBucketTool:proc
EXTERN EllipseTool:proc
EXTERN LineTool:proc
EXTERN RectangleTool:proc
EXTERN BrushTool:proc
EXTERN EraserTool:proc
EXTERN RenderLayers:proc
EXTERN WriteTool:proc
EXTERN Cleanup:proc
EXTERN Initialize:proc
EXTERN GetLayer: PROC
EXTERN DrawLayerPreview:PROC

EXTERN ZoomIn_Default:proc
EXTERN ZoomOut_Default:proc

EXTERN InitializeLayerRenderPreview:proc
EXTERN GetActiveLayersCount:proc

Resize PROTO STDCALL :DWORD, :DWORD
SelectTool PROTO STDCALL :DWORD, :DWORD
MoveTool PROTO STDCALL :DWORD, :DWORD, :DWORD, :DWORD

Shortcuts proto :HWND,:WPARAM
Paint proto :HWND,:DWORD,:DWORD
TBrush proto :DWORD, :DWORD, :COLORREF, :DWORD
TBucket proto :HWND,:HDC,:COLORREF
TWrite proto :DWORD, :DWORD
TSelect proto
TMove proto :DWORD, :DWORD

WinDocument proto :HWND
WinTool proto :HWND
WinLayer proto :HWND

.DATA 
    EXTERN isMouseDown:BYTE
    EXTERN brushSize:DWORD
    EXTERN color:COLORREF
    EXTERN hLayerButtons:HWND
    EXTERN selectedTool:DWORD
    EXTERN xInitial:DWORD
    EXTERN yInitial:DWORD
    EXTERN mainHwnd:HWND
    EXTERN docHwnd:HWND
    EXTERN layersHwnd:HWND
    EXTERN toolsHwnd:HWND
    EXTERN panOffsetX:DWORD
    EXTERN panOffsetY:DWORD
    EXTERN hControlButtons:HWND
    EXTERN pPixelSizeRatio:DWORD     
    EXTERN windowTitleInformation:BYTE
	EXTERN windowTitleError:BYTE
    EXTERN inSession:DWORD
    EXTERN documentWidth:DWORD
    EXTERN documentHeight:DWORD

    ClassName db "MainWindowClass",0   
    DocClassName db "DocWindowClass",0   
    AppName db "Pladoo Draw",0 
    AppNameDoc db "Pladoo Draw Document",0 

    szButtonClass db "BUTTON", 0

    szButton512 db "SQUARE (1:1)", 0
    szButton720 db "RECTANGLE (16:9)", 0

    szErrorCreatingDoc db "Erro ao criar a janela do documento.",0
    szErrorTitle       db "Erro",0  

    msgText db 256 dup(0)
    msgFmt db "WM_SETUP_DIAL Thread ID: %d", 0  

    gX dd 0
    gY dd 0

    PUBLIC pixelModeFlag
    pixelModeFlag DWORD 0

    screenWidth DWORD 0
    screenHeight DWORD 0

    mainWindowWidth dd 0
    mainWindowHeight dd 0

    NewButtonPositionX DWORD 0
    NewButtonPositionY DWORD 0
    NewButtonHeight DWORD 0
    WidthSquare DWORD 0
    WidthRect DWORD 0
    Spacing DWORD 0
    TotalWidth DWORD 0  
    HalfTotal DWORD 0
    CenterX DWORD 0
    CenterY DWORD 0
    LeftX DWORD 0
    SetupProjectRect RECT {0,0,0,0}

.DATA?
    mainHdc HDC ?
    hInstance HINSTANCE ?                       
    hDefaultCursor HCURSOR ?
    hEraserCursor HCURSOR ?
    hBrushCursor HCURSOR ?
    hRectangleCursor HCURSOR ?
    hEllipseCursor HCURSOR ?
    hLineCursor HCURSOR ?
    hBucketCursor HCURSOR ?
    hMoveCursor HCURSOR ?
    hTextCursor HCURSOR ?

    hMainInstance HINSTANCE ?
    hDocInstance HINSTANCE ? 
    
    lpMsgBuf dd ?    ; ponteiro para mensagem de erro formatada

    button512 HWND ?
    button720 HWND ?

    lastMouseX DWORD ?
    lastMouseY DWORD ?
    
.CODE

SetupProject proc hWnd:HWND
    ; 1) pega área cliente
    invoke GetClientRect, hWnd, ADDR SetupProjectRect

    ; largura = right - left
    mov eax, SetupProjectRect.right
    mov ecx, SetupProjectRect.left
    sub eax, ecx
    mov mainWindowWidth, eax

    ; altura = bottom - top
    mov eax, SetupProjectRect.bottom
    mov ecx, SetupProjectRect.top
    sub eax, ecx
    mov mainWindowHeight, eax

    ; 2) calcula centro (X e Y)
    mov eax, mainWindowWidth
    xor edx, edx
    mov ecx, 2
    div ecx
    mov CenterX, eax

    mov eax, mainWindowHeight
    xor edx, edx
    mov ecx, 2
    div ecx
    mov CenterY, eax

    ; 3) calcula altura dos botões = 1/3 da altura da janela
    mov eax, mainWindowHeight
    xor edx, edx
    mov ecx, 3
    div ecx
    mov NewButtonHeight, eax         ; altura comum aos 2 botões

    ; 4) largura do botão quadrado = mesma altura
    mov eax, NewButtonHeight
    mov WidthSquare, eax

    ; 5) largura do botão retangular = height * 16 / 9
    mov eax, NewButtonHeight
    mov ecx, 16
    mul ecx                          ; EDX:EAX = height * 16
    mov ecx, 9
    div ecx                          ; EAX = (height*16)/9
    mov WidthRect, eax

    ; 6) spacing entre botões (ajuste se quiser)
    mov eax, 20
    mov Spacing, eax

    ; 7) totalWidth = widthSquare + spacing + widthRect
    mov eax, WidthSquare
    add eax, Spacing
    add eax, WidthRect
    mov TotalWidth, eax

    ; 8) halfTotal = totalWidth / 2
    mov eax, TotalWidth
    shr eax, 1
    mov HalfTotal, eax

    ; 9) leftX = centerX - halfTotal  (início do bloco centralizado)
    mov eax, CenterX
    sub eax, HalfTotal
    mov LeftX, eax

    ; 10) calcula Y dos botões (centerY - height/2)
    mov eax, CenterY
    mov ecx, NewButtonHeight
    shr ecx, 1
    sub eax, ecx
    mov NewButtonPositionY, eax

    ; 11) cria botão SQUARE (1:1) na posição LeftX
    mov eax, LeftX
    mov NewButtonPositionX, eax
    invoke CreateWindowEx, 0, ADDR szButtonClass, ADDR szButton512, \
        WS_CHILD or WS_VISIBLE or BS_FLAT, \
        NewButtonPositionX, NewButtonPositionY, \
        WidthSquare, NewButtonHeight, \
        hWnd, 512, hMainInstance, NULL
    mov button512, eax

    ; 12) button RECTANGLE X = LeftX + widthSquare + spacing
    mov eax, LeftX
    add eax, WidthSquare
    add eax, Spacing
    mov NewButtonPositionX, eax

    invoke CreateWindowEx, 0, ADDR szButtonClass, ADDR szButton720, \
        WS_CHILD or WS_VISIBLE or BS_FLAT, \
        NewButtonPositionX, NewButtonPositionY, \
        WidthRect, NewButtonHeight, \
        hWnd, 720, hMainInstance, NULL
    mov button720, eax
    ret
SetupProject endp

StartDraw proc
    invoke DestroyWindow, button512
    invoke DestroyWindow, button720
    
    invoke WinDocument, mainHwnd
    invoke WinLayer, mainHwnd
    invoke WinTool, mainHwnd

    call GetActiveLayersCount
    mov ecx, eax
        
    invoke SetWindowPos, layersHwnd, HWND_TOP, 0,0,0,0, SWP_NOMOVE or SWP_NOSIZE
    invoke SetWindowPos, toolsHwnd, HWND_TOP, 0,0,0,0, SWP_NOMOVE or SWP_NOSIZE
    invoke SetWindowPos, [hControlButtons + 0 * SIZEOF DWORD], HWND_TOP, 0,0,0,0, SWP_NOMOVE or SWP_NOSIZE
    invoke SetWindowPos, [hControlButtons + 1 * SIZEOF DWORD], HWND_TOP, 0,0,0,0, SWP_NOMOVE or SWP_NOSIZE
    invoke SetWindowPos, [hControlButtons + 2 * SIZEOF DWORD], HWND_TOP, 0,0,0,0, SWP_NOMOVE or SWP_NOSIZE
    invoke SetWindowPos, [hControlButtons + 3 * SIZEOF DWORD], HWND_TOP, 0,0,0,0, SWP_NOMOVE or SWP_NOSIZE
    
    call InitializeLayerRenderPreview

    ret
StartDraw endp

WinMain proc
        LOCAL wc:WNDCLASSEX                                         
        LOCAL hwnd:HWND
        LOCAL workArea: RECT

        mov color, 00000000h
            
        mov wc.cbSize,SIZEOF WNDCLASSEX                           
        mov wc.style, CS_HREDRAW or CS_VREDRAW
        mov wc.lpfnWndProc, OFFSET WndMainProc

        invoke GetModuleHandle, NULL            
        mov wc.hInstance, eax
        mov hMainInstance, eax

        xor eax, eax

        mov wc.hbrBackground,1
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

        mov hwnd, eax

        invoke SystemParametersInfo, SPI_GETWORKAREA, 0, addr workArea, 0
        invoke SetWindowPos, hwnd, NULL, workArea.left, workArea.top, workArea.right, workArea.bottom, SWP_NOZORDER

        invoke ShowWindow,hwnd,SW_SHOW
        invoke UpdateWindow, hwnd
        
        mov eax, hwnd
        mov mainHwnd, eax
        
        ret 
    WinMain endp

    WinDocument proc hWnd:HWND
        LOCAL rect:RECT
        LOCAL wc:WNDCLASSEX                                         

        LOCAL canvasWidth:DWORD
        LOCAL canvasHeight:DWORD

        LOCAL halfScreenWidth:DWORD
        LOCAL halfScreenHeight:DWORD

        LOCAL halfDocumentWidth:DWORD
        LOCAL halfDocumentHeight:DWORD

        LOCAL centerX: DWORD
        LOCAL centerY: DWORD

        mov eax, documentWidth
        mov ecx, 32
        xor edx, edx
        div ecx

        mov edx, eax
        
        mov eax, documentWidth
        mov ecx, edx
        xor edx, edx
        div ecx

        mov canvasWidth, eax

        xor eax, eax
        xor ecx, ecx
        xor edx, edx

        mov eax, documentHeight
        mov ecx, 32
        xor edx, edx
        div ecx

        mov edx, eax

        mov eax, documentHeight
        mov ecx, edx
        xor edx, edx
        div ecx
                
        mov canvasHeight, eax
        mov pPixelSizeRatio, eax

        xor eax, eax
        xor ecx, ecx
        xor edx, edx

        invoke GetClientRect, hWnd, addr rect

        mov eax, rect.right
        mov screenWidth, eax

        mov eax, rect.bottom
        mov screenHeight, eax

        mov eax, 0

        mov color, 00000000h
            
        mov wc.cbSize, SIZEOF WNDCLASSEX
        mov wc.style, CS_HREDRAW or CS_VREDRAW
        mov wc.lpfnWndProc, OFFSET WndDocProc
        mov wc.cbClsExtra, 0
        mov wc.cbWndExtra, 0

        invoke GetModuleHandle, NULL
        mov wc.hInstance, eax
        mov hDocInstance, eax

        invoke LoadCursor, NULL, IDC_ARROW
        mov wc.hCursor, eax

        invoke LoadCursor,hDocInstance,IDC_ARROW
        mov wc.hCursor, eax
        mov hDefaultCursor, eax
            
        invoke LoadCursor, hDocInstance, IDC_CURSOR_ERASER
        mov hEraserCursor, eax

        invoke LoadCursor, hDocInstance, IDC_CURSOR_BRUSH
        mov hBrushCursor, eax

        invoke LoadCursor, hDocInstance, IDC_CURSOR_RECTANGLE
        mov hRectangleCursor, eax

        invoke LoadCursor, hDocInstance, IDC_CURSOR_ELLIPSE
        mov hEllipseCursor, eax

        invoke LoadCursor, hDocInstance, IDC_CURSOR_LINE
        mov hLineCursor, eax

        invoke LoadCursor, hDocInstance, IDC_CURSOR_BUCKET
        mov hBucketCursor, eax 

        invoke LoadCursor, hDocInstance, IDC_CURSOR_MOVE
        mov hMoveCursor, eax 

        invoke LoadCursor, hDocInstance, IDC_CURSOR_TEXT
        mov hTextCursor, eax

        mov wc.hbrBackground, 0           ; ou (COLOR_WINDOW+1)
        mov wc.lpszMenuName, NULL
        mov wc.lpszClassName, OFFSET DocClassName

        invoke LoadIcon, NULL, IDI_APPLICATION
        mov wc.hIcon, eax
        mov wc.hIconSm, eax
        
        mov edx, 0
        mov eax, screenWidth
        mov ecx, 2
        div ecx

        mov halfScreenWidth, eax

        mov eax, 0

        mov edx, 0
        mov eax, screenHeight
        mov ecx, 2
        div ecx

        mov halfScreenHeight, eax

        mov eax, 0

        mov edx, 0
        mov eax, documentWidth
        mov ecx, 2
        div ecx

        mov halfDocumentWidth, eax

        mov eax, 0

        mov edx, 0
        mov eax, documentHeight
        mov ecx, 2
        div ecx

        mov halfDocumentHeight, eax

        mov eax, 0

        mov eax, halfScreenWidth
        mov ebx, halfDocumentWidth
        sub eax, ebx

        mov centerX, eax

        mov eax, 0

        mov eax, halfScreenHeight
        mov ebx, halfDocumentHeight
        sub eax, ebx

        mov centerY, eax

        mov eax, 0

        mov eax, centerX
        mov panOffsetX, eax
        mov eax, centerY
        mov panOffsetY, eax

        invoke RegisterClassEx, addr wc

        invoke CreateWindowEx, 
        NULL,\ 
        ADDR DocClassName,\ 
        ADDR AppNameDoc,\ 
        WS_CHILD or WS_VISIBLE or WS_CLIPCHILDREN or WS_CLIPSIBLINGS,\ 
        centerX,\ 
        centerY,\ 
        documentWidth,\ 
        documentHeight,\ 
        hWnd,\ 
        NULL,\ 
        hDocInstance,\ 
        NULL

        mov docHwnd, eax

        invoke ShowWindow, eax, SW_SHOW
        invoke UpdateWindow, eax
    
        mov eax, docHwnd

        ret
    WinDocument endp

    WndMainProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
        LOCAL dwStyle:DWORD
        LOCAL rect:RECT

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
        
            and dwStyle, NOT WS_MAXIMIZEBOX
            and dwStyle, NOT WS_THICKFRAME
        
            invoke SetWindowLong, hWnd, GWL_STYLE, dwStyle
            invoke SetCursor, hDefaultCursor

            ret
        .ELSEIF uMsg == WM_SHOWWINDOW
            push hWnd
            call SetupProject
            ret
        .ELSEIF uMsg == WM_COMMAND
            .IF wParam == 512
                mov ecx, wParam
                mov documentWidth, ecx
                mov documentHeight, ecx

                xor ecx, ecx

                invoke StartDraw
                ret
            .ELSEIF wParam == 720
              
                mov documentWidth, 1280
                mov documentHeight, 720
                
                xor ecx, ecx

                invoke StartDraw
                ret
            .ENDIF

        .ELSE
            invoke DefWindowProc,hWnd,uMsg,wParam,lParam
            ret
        .ENDIF

        xor eax,eax
    WndMainProc endp

    WndDocProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM       
        LOCAL rect:RECT
        LOCAL mousePosition:POINT
        LOCAL lowLPARAM:DWORD
        LOCAL highLPARAM:DWORD
        LOCAL pt:POINT
        
        .IF uMsg==WM_KEYDOWN
                
            push wParam
            push hWnd
            call Shortcuts

            ret
        .ELSEIF uMsg == WM_MBUTTONDOWN

            ; Captura posição inicial global do mouse
            invoke GetCursorPos, addr pt
            mov eax, pt.x
            mov lastMouseX, eax
            mov eax, pt.y
            mov lastMouseY, eax

            ; Captura mouse para eventos globais (mesmo fora da janela)
            invoke SetCapture, hWnd

            ; Extrai posição client para xInitial/yInitial (mantém compatibilidade)
            mov eax, lParam
            and eax, 0FFFFh
            mov xInitial, eax

            mov eax, lParam
            shr eax, 16
            mov yInitial, eax

            mov byte ptr [isMouseDown], 2   ; 2 = modo Pan
            ret
        .ELSEIF uMsg == WM_MBUTTONUP
            mov byte ptr [isMouseDown], 0
    
            ; Libera captura do mouse
            invoke ReleaseCapture
    
            ; Opcional: Força repintura para consistência final (sem desabilitar antes)
            invoke InvalidateRect, hWnd, NULL, TRUE
            invoke UpdateWindow, hWnd
            ret
        .ELSEIF uMsg == WM_SETCURSOR
                
            .IF DWORD PTR [selectedTool] == 0
                invoke SetCursor, hEraserCursor
            .ELSEIF DWORD PTR [selectedTool] == 1
                invoke SetCursor, hBrushCursor
            .ELSEIF DWORD PTR [selectedTool] == 2
                invoke SetCursor, hRectangleCursor
            .ELSEIF DWORD PTR [selectedTool] == 3
                invoke SetCursor, hEllipseCursor
            .ELSEIF DWORD PTR [selectedTool] == 4
                invoke SetCursor, hLineCursor
            .ELSEIF DWORD PTR [selectedTool] == 5
                invoke SetCursor, hBucketCursor
            .ELSEIF DWORD PTR [selectedTool] == 6
                invoke SetCursor, hMoveCursor
            .ELSEIF DWORD PTR [selectedTool] == 7
                invoke SetCursor, hTextCursor
            .ELSE
                invoke SetCursor, hDefaultCursor
            .ENDIF

            ret
        .ELSEIF uMsg==WM_CREATE

            push hLayerButtons
            push -1
            push -1
            push -1
            push hWnd
            push mainHwnd
            call Initialize

        .ELSEIF uMsg==WM_SIZE
        
            mov eax, lParam
            and eax, 0FFFFh
            mov lowLPARAM, eax

            mov eax, lParam
            shr eax, 16            
            mov highLPARAM, eax

            ;invoke Resize, lowLPARAM, highLPARAM

            invoke InvalidateRect, hWnd, NULL, 1
            invoke RedrawWindow, hWnd, NULL, NULL, RDW_INVALIDATE or RDW_UPDATENOW or RDW_ALLCHILDREN

            ret

        .ELSEIF uMsg==WM_LBUTTONDOWN               
            
            ;Extraindo mouse X
            mov eax, lParam
            and eax, 0FFFFh        ; X f�sico
            mov xInitial, eax

            ; Extraindo mouse Y
            mov eax, lParam
            shr eax, 16            ; Y f�sico
            mov yInitial, eax

            .IF DWORD PTR [selectedTool] == 1
                .IF pixelModeFlag == 1
                    invoke TBrush, xInitial, yInitial, color, pixelModeFlag
                    call RenderLayers
                    xor eax, eax
                .ENDIF
            .ELSEIF DWORD PTR [selectedTool] == 5
                invoke GetDC, hWnd
                mov mainHdc, eax

                invoke TBucket, hWnd, mainHdc, DWORD PTR [color]
            .ELSEIF DWORD PTR [selectedTool] == 6
                invoke TSelect
            .ELSEIF DWORD PTR [selectedTool] == 7

                invoke TWrite, xInitial, yInitial
                
            .ENDIF
                
            mov byte ptr [isMouseDown], 1

            ret

        .ELSEIF uMsg==WM_LBUTTONUP

            invoke SetFocus, hWnd

            mov byte ptr [isMouseDown], 0

            call handleMouseUp

        .ELSEIF uMsg==WM_MOUSEMOVE
               
            cmp byte ptr [isMouseDown], 2
            jne SkipPan

            ; Captura posição atual global do mouse
            invoke GetCursorPos, addr pt
    
            ; Calcula delta global (X)
            mov eax, pt.x
            sub eax, lastMouseX
            add panOffsetX, eax
    
            ; Calcula delta global (Y)
            mov ecx, pt.y
            sub ecx, lastMouseY
            add panOffsetY, ecx
    
            ; Atualiza última posição para próximo delta

            mov eax, pt.x
            mov lastMouseX, eax

            mov eax, pt.y
            mov lastMouseY, eax
    
            ; Move a janela com o novo offset (TRUE para repintar)
            invoke SetWindowPos, hWnd, 0, panOffsetX, panOffsetY, 0, 0, SWP_NOSIZE or SWP_NOZORDER

            jmp LEndProc

            SkipPan:
                ;Extraindo mouse X
                mov eax, lParam
                and eax, 0FFFFh        ; X f�sico
                mov gX, eax

                ; Extraindo mouse Y
                mov eax, lParam
                shr eax, 16            ; Y f�sico
                mov gY, eax

                invoke Paint, hWnd, gX, gY
            
                cmp byte ptr [isMouseDown], 1
                jne LEndProc

                cmp DWORD PTR [selectedTool], 5 
                je LEndProc

                cmp DWORD PTR [selectedTool], 7 
                je LEndProc
            
                call RenderLayers

                xor eax, eax

            LEndProc:
            ret
        .ELSEIF uMsg==WM_MOUSEWHEEL
            mov eax, wParam
            shr eax, 16              
            cmp eax, 120
            je  ScrollUp
            jne ScrollDown

            jmp END_PROC

        ScrollUp:
            call ZoomIn_Default
            jmp END_PROC

        ScrollDown:
            call ZoomOut_Default
            jmp END_PROC

        .ELSE
            invoke DefWindowProc,hWnd,uMsg,wParam,lParam
            ret
        .ENDIF

        xor eax,eax

        END_PROC:
        ret
    WndDocProc endp

TEraser Proc x:DWORD, y:DWORD
        
    push y
    push x
    call EraserTool
    
    ret
TEraser endp

TBrush Proc x:DWORD, y:DWORD, localColor: COLORREF, pixelMode:DWORD
    
    push pPixelSizeRatio
    push pixelMode
    push localColor
    push y
    push x
    call BrushTool
    
    ret
TBrush endp

TRectangle Proc x:DWORD, y:DWORD, localColor: COLORREF
    
    push localColor 
    push y
    push x
    push yInitial
    push xInitial
    call RectangleTool

    ret

TRectangle endp

TEllipse Proc x:DWORD, y:DWORD, localColor: COLORREF

    push localColor
    push y
    push x
    push yInitial
    push xInitial
    call EllipseTool

    ret
        
TEllipse endp

TLine Proc x:DWORD, y:DWORD, localColor: COLORREF
    
    push localColor
    push y
    push x
    push yInitial
    push xInitial
    call LineTool

    ret

TLine endp

TBucket proc hWnd:HWND, hdc:HDC, localColor:COLORREF
    
    push hWnd
    push localColor
    push yInitial
    push xInitial
    call PaintBucketTool

    ret
TBucket endp

TSelect Proc
    invoke SelectTool, xInitial, yInitial

    ret
TSelect endp

TMove Proc x:DWORD, y:DWORD

    invoke MoveTool, xInitial, yInitial, x, y

    ret

TMove endp

TWrite Proc x:DWORD, y:DWORD
    
    push y
    push x
    call WriteTool

    ret

TWrite endp


Paint Proc hWnd:HWND, x:DWORD, y:DWORD 
    LOCAL hdc:HDC

    invoke GetDC, hWnd
    mov hdc, eax

    cmp hdc, 0
    jz DCFailed

    cmp byte ptr [isMouseDown], 1
    je PAINT
    jmp END_PROC

    PAINT:

        cmp DWORD PTR [selectedTool], 0
        je LEraseTool

        cmp DWORD PTR [selectedTool], 1
        je LBrushTool

        cmp DWORD PTR [selectedTool], 2
        je LRectangleTool

        cmp DWORD PTR [selectedTool], 3
        je LEllipseTool

        cmp DWORD PTR [selectedTool], 4
        je LLineTool

        cmp DWORD PTR [selectedTool], 5
        je LBucketTool

        cmp DWORD PTR [selectedTool], 6
        je LMoveTool

        cmp DWORD PTR [selectedTool], 7
        je LWriteTool

        LEraseTool:         
            invoke TEraser, x, y
            jmp END_PROC

        LBrushTool:
            invoke TBrush, x, y, color, pixelModeFlag
            jmp END_PROC

        LRectangleTool: 
            invoke TRectangle, x, y, color
            jmp END_PROC

        LEllipseTool:
            invoke TEllipse, x, y, color
            jmp END_PROC

        LLineTool:  
            invoke TLine, x, y, color
            jmp END_PROC

        LBucketTool: 
            jmp END_PROC

        LMoveTool:
            .IF byte ptr [isMouseDown] == 1
                invoke TMove, x, y
            .ENDIF
            jmp END_PROC

        LWriteTool: 
            jmp END_PROC

    DCFailed:
        invoke wsprintfA, offset msgText, offset msgFmt, x, y
        invoke MessageBoxA, hWnd, offset msgText, offset windowTitleError, MB_OK
        jmp END_PROC

    END_PROC:
        cmp hdc, 0
        jz NoRelease
        invoke ReleaseDC, hWnd, hdc
    NoRelease:
        ret
Paint endp 

end
