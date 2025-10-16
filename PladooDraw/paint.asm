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

EXTERN InitializeDocument:proc
EXTERN InitializeWrite:proc
EXTERN GetLayer: PROC
EXTERN DrawLayerPreview:PROC

EXTERN ZoomIn_Default:proc
EXTERN ZoomOut_Default:proc



Resize PROTO STDCALL :DWORD, :DWORD
SelectTool PROTO STDCALL :DWORD, :DWORD
MoveTool PROTO STDCALL :DWORD, :DWORD, :DWORD, :DWORD

Shortcuts proto :WPARAM
Paint proto :HWND,:DWORD,:DWORD
TBrush proto :DWORD, :DWORD, :COLORREF, :DWORD
TBucket proto :HWND,:HDC,:COLORREF
TWrite proto :DWORD, :DWORD
TSelect proto
TMove proto :DWORD, :DWORD

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
    EXTERN layerWindowHwnd:HWND
    EXTERN toolsHwnd:HWND
    EXTERN replayHwnd:HWND
    EXTERN panOffsetX:DWORD
    EXTERN panOffsetY:DWORD
    EXTERN hControlButtons:HWND
    EXTERN pPixelSizeRatio:DWORD     
    EXTERN windowTitleInformation:BYTE
	EXTERN windowTitleError:BYTE
    EXTERN inSession:DWORD
    EXTERN documentWidth:DWORD
    EXTERN documentHeight:DWORD
    EXTERN btnWidth:DWORD
    EXTERN btnHeight:DWORD
    EXTERN szButtonClass:BYTE

    DocClassName db "DocWindowClass",0   
    AppNameDoc db "Pladoo Draw Document",0 

    szErrorCreatingDoc db "Erro ao criar a janela do documento.",0
    szErrorTitle       db "Erro",0  

    msgText db 256 dup(0)
    msgFmt db "WM_SETUP_DIAL Thread ID: %d", 0  

    gX dd 0
    gY dd 0

    PUBLIC pixelModeFlag
    pixelModeFlag DWORD 0

    EXTERN replayModeFlag:DWORD

    screenWidth DWORD 0
    screenHeight DWORD 0

.DATA?

    EXTERN hDefaultCursor:HCURSOR

    mainHdc HDC ?
    hInstance HINSTANCE ?                       
    hEraserCursor HCURSOR ?
    hBrushCursor HCURSOR ?
    hRectangleCursor HCURSOR ?
    hEllipseCursor HCURSOR ?
    hLineCursor HCURSOR ?
    hBucketCursor HCURSOR ?
    hMoveCursor HCURSOR ?
    hTextCursor HCURSOR ?

    hDocInstance HINSTANCE ? 
    
    lpMsgBuf dd ?    ; ponteiro para mensagem de erro formatada

    lastMouseX DWORD ?
    lastMouseY DWORD ?
    
.CODE
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

   

    WndDocProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM       
        LOCAL rect:RECT
        LOCAL mousePosition:POINT
        LOCAL lowLPARAM:DWORD
        LOCAL highLPARAM:DWORD
        LOCAL pt:POINT
        
        .IF uMsg==WM_KEYDOWN
                
            push wParam
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

            push btnHeight
            push btnWidth
            push -1
            push -1
            push -1
            push hWnd
            call InitializeDocument

            call InitializeWrite

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

            .IF replayModeFlag == 1
                jmp LEndProc
                ret
            .ELSEIF DWORD PTR [selectedTool] == 1
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

            .IF replayModeFlag == 1
                jmp LEndMessage
                ret
            .ENDIF

            invoke SetFocus, hWnd

            mov byte ptr [isMouseDown], 0

            call handleMouseUp

            LEndMessage:
            ret
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

             .IF replayModeFlag == 1
                jmp END_PROC
                ret
            .ENDIF

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
