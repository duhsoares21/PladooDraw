.686

.MODEL flat, stdcall

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\gdi32.inc
include \masm32\include\kernel32.inc
include \masm32\include\msimg32.inc
include \masm32\include\gdiplus.inc

includelib \masm32\lib\msimg32.lib
includelib \masm32\lib\gdiplus.lib

includelib PladooDraw_Direct2D_LayerSystem.lib

EXTERN ResetParameters:proc
EXTERN EllipseTool:proc
EXTERN RectangleTool:proc
EXTERN BrushTool:proc
EXTERN EraserTool:proc
EXTERN RenderLayers:proc
EXTERN Cleanup:proc

RepositionLayerToolbar proto :DWORD,:DWORD,:DWORD,:DWORD
Shortcuts proto :HWND,:WPARAM
Paint proto :HWND,:DWORD,:DWORD
TBucket proto :HWND,:HDC,:COLORREF

.DATA 

    ClassName db "MainWindowClass",0                 
    AppName db "Pladoo Draw",0 

    EXTERN isMouseDown:BYTE
    EXTERN brushSize:DWORD
    EXTERN color:COLORREF

    EXTERN selectedTool:DWORD

    EXTERN xInitial:DWORD
    EXTERN yInitial:DWORD

    EXTERN msgText:BYTE
	EXTERN msgFmt:BYTE

    EXTERN windowTitleInformation:BYTE
	EXTERN windowTitleError:BYTE
    
    EXTERN inSession:DWORD

    gdiplusStartupInput GdiplusStartupInput <>

    gX dd 0
    gY dd 0

    IDC_CURSOR_ERASER db "./cursors/eraser.cur", 0
    IDC_CURSOR_ERASER_ALT db "./cursors/eraser-alt.cur", 0
    IDC_CURSOR_BRUSH db "./cursors/brush.cur", 0
    IDC_CURSOR_BRUSH_ALT db "./cursors/pencil.cur", 0
    IDC_CURSOR_RECTANGLE db "./cursors/rectangle.cur", 0
    IDC_CURSOR_ELLIPSE db "./cursors/ellipse.cur", 0
    IDC_CURSOR_LINE db "./cursors/line.cur", 0
    IDC_CURSOR_BUCKET db "./cursors/bucket.cur", 0

    hInstance HINSTANCE ?                       

    hDefaultCursor HCURSOR ?
    hEraserCursor HCURSOR ?
    hBrushCursor HCURSOR ?
    hRectangleCursor HCURSOR ?
    hEllipseCursor HCURSOR ?
    hLineCursor HCURSOR ?
    hBucketCursor HCURSOR ?

    hMainInstance HINSTANCE ?

    screenWidth DWORD 0
    screenHeight DWORD 0

    mainHdc HDC ?
        
    hBrush dd 0 
    hPen dd 0 

    prevRect RECT <0, 0, 0, 0>

    BLENDFUNCTION STRUCT
        BlendOp                 DB ?
        BlendFlags              DB ?
        SourceConstantAlpha     DB ?
        AlphaFormat             DB ?
    BLENDFUNCTION ENDS

    mainWindowWidth dd 0
    mainWindowHeight dd 0

    ;AddLayer proto :DWORD, :COLORREF, :DWORD, :DWORD, :DWORD

.DATA?
    blendFunc BLENDFUNCTION <>
    pD2DFactory DWORD ?
.CODE

WinMain proc
        LOCAL wc:WNDCLASSEX                                         
        LOCAL msg:MSG
        LOCAL hwnd:HWND

        mov color, 00000000h
            
        mov wc.cbSize,SIZEOF WNDCLASSEX                           
        mov wc.style, CS_HREDRAW or CS_VREDRAW
        mov wc.lpfnWndProc, OFFSET WndProc

        invoke GetModuleHandle, NULL            
        mov wc.hInstance, eax
        mov hMainInstance, eax

        xor eax, eax

        mov wc.hbrBackground,0
        mov wc.lpszMenuName,NULL
        mov wc.lpszClassName,OFFSET ClassName
            
        invoke LoadIcon,NULL,IDI_APPLICATION

        mov wc.hIcon,eax
        mov wc.hIconSm,eax
            
        invoke LoadCursor,NULL,IDC_ARROW
        mov wc.hCursor, eax
        mov hDefaultCursor, eax
            
        invoke LoadCursorFromFile,addr IDC_CURSOR_ERASER_ALT
        mov hEraserCursor, eax

        invoke LoadCursorFromFile,addr IDC_CURSOR_BRUSH
        mov hBrushCursor, eax

        invoke LoadCursorFromFile,addr IDC_CURSOR_RECTANGLE
        mov hRectangleCursor, eax

        invoke LoadCursorFromFile,addr IDC_CURSOR_ELLIPSE
        mov hEllipseCursor, eax

        invoke LoadCursorFromFile,addr IDC_CURSOR_LINE
        mov hLineCursor, eax

        invoke LoadCursorFromFile,addr IDC_CURSOR_BUCKET
        mov hBucketCursor, eax 
        
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

        invoke ShowWindow,hwnd,SW_SHOWMAXIMIZED
        invoke UpdateWindow, hwnd
        
        mov eax, hwnd
        
        ret 
    WinMain endp

    WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM       
        LOCAL dwStyle:DWORD
        LOCAL rect:RECT
        LOCAL mousePosition:POINT
                        
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

            push mainWindowHeight
            push 120
            push 0
            push mainWindowWidth
            call RepositionLayerToolbar
            
            invoke RedrawWindow, hWnd, NULL, NULL, RDW_INVALIDATE or RDW_UPDATENOW
            ret
        .ELSEIF uMsg == WM_CREATE

            invoke GetWindowLong, hWnd, GWL_STYLE
            mov dwStyle, eax
        
            and dwStyle, NOT WS_MAXIMIZEBOX
            and dwStyle, NOT WS_THICKFRAME
        
            invoke SetWindowLong, hWnd, GWL_STYLE, dwStyle

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
            .ELSE
                invoke SetCursor, hDefaultCursor
            .ENDIF

            ret

        .ELSEIF uMsg==WM_KEYDOWN
                
            push wParam
            push hWnd
            call Shortcuts

            ret

        .ELSEIF uMsg==WM_LBUTTONDOWN               

            .IF DWORD PTR [selectedTool] == 5
                invoke GetDC, hWnd
                mov mainHdc, eax

                invoke TBucket, hWnd, mainHdc, DWORD PTR [color]
            .ENDIF

            mov eax, lParam
            and eax, 0FFFFh          
            mov xInitial, eax        

            mov eax, lParam
            shr eax, 16              
            mov yInitial, eax
                
            mov byte ptr [isMouseDown], 1

            ret

        .ELSEIF uMsg==WM_LBUTTONUP

            invoke SetFocus, hWnd

            mov byte ptr [isMouseDown], 0

            call ResetParameters

        .ELSEIF uMsg==WM_MOUSEMOVE
                
            mov eax, lParam
            and eax, 0FFFFh          
            mov gX, eax        

            mov eax, lParam
            shr eax, 16              
            mov gY, eax 

            invoke Paint, hWnd, gX, gY
            call RenderLayers
            ret

        .ELSE
            invoke DefWindowProc,hWnd,uMsg,wParam,lParam
            ret
        .ENDIF

        xor eax,eax

        END_PROC:
        ret
    WndProc endp

TEraser Proc hWnd:HWND, hdc:HDC, x:DWORD, y:DWORD, localBrushSize:DWORD
        
    push localBrushSize
    push y
    push x
    push hdc
    call EraserTool
    
    push hdc
    push hWnd
    call ReleaseDC
    
    ret
TEraser endp

TBrush Proc hWnd:HWND, hdc:HDC, x:DWORD, y:DWORD, localColor: COLORREF, localBrushSize:DWORD

    push localBrushSize
    push localColor
    push y
    push x
    push hdc
    call BrushTool
    
    push hdc
    push hWnd
    call ReleaseDC

    ret
TBrush endp

TRectangle Proc hWnd:HWND, hdc:HDC, x:DWORD, y:DWORD, localColor: COLORREF
    
    push localColor
    push y
    push x
    push yInitial
    push xInitial
    push hdc
    call RectangleTool

    push hdc
    push hWnd
    call ReleaseDC

    ret

TRectangle endp

TEllipse Proc hWnd:HWND, hdc:HDC, x:DWORD, y:DWORD, localColor: COLORREF

    push localColor
    push y
    push x
    push yInitial
    push xInitial
    push hdc
    call EllipseTool

    push hdc
    push hWnd
    call ReleaseDC

    ret

TEllipse endp

TLine Proc hWnd:HWND, hdc:HDC, x:DWORD, y:DWORD, localColor: COLORREF
    LOCAL rect:RECT

    mov edx, xInitial
    mov rect.left, edx

    mov edx, yInitial
    mov rect.top, edx

    mov edx, x
    mov rect.right, edx

    mov edx, y
    mov rect.bottom, edx

    cmp DWORD PTR[inSession], 1
    je UNDRAW

    jmp DRAW

    UNDRAW: 
        invoke SetROP2, hdc, R2_WHITE
        
        invoke CreatePen, PS_SOLID, 1, 00FFFFFFh
        mov hPen, eax
        invoke SelectObject, hdc, hPen
        
        .IF (prevRect.left != 0 || prevRect.right != 0)
            invoke MoveToEx, hdc, prevRect.left, prevRect.top, NULL 
            invoke LineTo, hdc, prevRect.right, prevRect.bottom
        .ENDIF
        
        invoke DeleteObject, hPen

        mov prevRect.left, 0
        mov prevRect.right, 0
        mov prevRect.top, 0
        mov prevRect.bottom, 0

    DRAW:
        invoke SetROP2, hdc, R2_COPYPEN
        mov DWORD PTR[inSession], 1
        
        invoke CreatePen, PS_SOLID, 1, localColor
        mov hPen, eax
        invoke SelectObject, hdc, hPen

        invoke MoveToEx, hdc, rect.left, rect.top, NULL 
        invoke LineTo, hdc, rect.right, rect.bottom
                
        invoke DeleteObject, hPen

        mov edx, rect.left
        mov prevRect.left, edx

        mov edx, rect.top
        mov prevRect.top, edx

        mov edx, rect.right
        mov prevRect.right, edx

        mov edx, rect.bottom
        mov prevRect.bottom, edx

        xor eax, eax
        xor edx, edx

        invoke ReleaseDC, hWnd, hdc

    ret

TLine endp

TBucket proc hWnd:HWND, hdc:HDC, localColor:COLORREF
    LOCAL surfaceColor:COLORREF

    invoke CreateSolidBrush, localColor
    mov hBrush, eax

    invoke SelectObject, hdc, hBrush

    invoke GetPixel, hdc, xInitial, yInitial
    mov surfaceColor, eax

    invoke ExtFloodFill, hdc, xInitial, yInitial, surfaceColor, FLOODFILLSURFACE

    invoke DeleteObject, hBrush
    invoke ReleaseDC, hWnd, hdc

    mov surfaceColor, 0
    xor eax, eax

    ret
TBucket endp

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

        LEraseTool: 
            mov edx, brushSize
            add edx, 18
        
            invoke TEraser, hWnd, hdc, x, y, edx
            jmp END_PROC

        LBrushTool:
            invoke TBrush, hWnd, hdc, x, y, color, brushSize
            jmp END_PROC

        LRectangleTool: 
            invoke TRectangle, hWnd, hdc, x, y, color
            jmp END_PROC

        LEllipseTool:
            invoke TEllipse, hWnd, hdc, x, y, color
            jmp END_PROC

        LLineTool: 
            invoke TLine, hWnd, hdc, x, y, color
            jmp END_PROC

        LBucketTool: 
            invoke TBucket, hWnd, hdc, color
            jmp END_PROC

    DCFailed:
        invoke wsprintfA, offset msgText, offset msgFmt, x, y
        invoke MessageBoxA, hWnd, offset msgText, offset windowTitleError, MB_OK
        jmp END_PROC

    END_PROC: 
        ret
Paint endp

end