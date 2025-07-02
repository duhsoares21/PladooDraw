.686
.model flat,stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\gdi32.inc
include \masm32\include\kernel32.inc
include \masm32\include\comdlg32.inc

.DATA                
    ClassName db "ToolbarWindowClass",0                 
    AppName db "Tool Window",0                 

    szButtonBrush db "(B)", 0
    szButtonRectangle db "(R)", 0
    szButtonEllipse db "(E)", 0
    szButtonLine db "(L)", 0
    szButtonBucket db "(P)", 0
    szButtonEraser db "(D)", 0

    ID_ICON_BRUSH db "./icons/brush.ico", 0
    ID_ICON_RECTANGLE db "./icons/rectangle.ico", 0
    ID_ICON_ELLIPSE db "./icons/ellipse.ico", 0
    ID_ICON_LINE db "./icons/line.ico", 0
    ID_ICON_PAINT_BUCKET db "./icons/paint_bucket.ico", 0
    ID_ICON_ERASER db "./icons/eraser.ico", 0
    
    hIconBrush      HICON ?
    hIconRectangle      HICON ?
    hIconEllipse      HICON ?
    hIconLine      HICON ?
    hIconPaintBucket      HICON ?
    hIconEraser      HICON ?

    szButtonClass db "BUTTON", 0
    szNotification db "Notification", 0
    szButtonClicked db "Clicked", 0

    hColorButtons HWND 9 DUP(?)
    customColors     dd 16 dup(0)
    
    screenWidth DWORD 0
    screenHeight DWORD 0

    EXTERN selectedTool:DWORD
    EXTERN brushSize:DWORD
    EXTERN color:COLORREF

    EXTERN msgText:BYTE
	EXTERN msgFmt:BYTE

    EXTERN windowTitleInformation:BYTE
	EXTERN windowTitleError:BYTE

    CHOOSECOLOR STRUCT
        lStructSize      DWORD ?
        hwndOwner        HWND  ?
        hInstance        HINSTANCE ?
        rgbResult        COLORREF ?
        lpCustColors     DWORD ?
        Flags            DWORD ?
        lCustData        DWORD ?
        lpfnHook         DWORD ?
        lpTemplateName   DWORD ?
    CHOOSECOLOR ENDS


.DATA?           

    mainWindowHwnd HWND ?

    hToolInstance HINSTANCE ?                       

    hDefaultCursor HCURSOR ?

    hToolButtons HWND ?

    hdc HDC ?

.CODE          
    
    WinTool proc hWnd:HWND    
        LOCAL hWndToolbar:HWND
        LOCAL rect:RECT

        LOCAL wc:WNDCLASSEX                                         
        LOCAL msg:MSG

        invoke GetModuleHandle, NULL            

        mov hToolInstance,eax
        mov wc.hInstance, eax
               
        mov wc.cbSize,SIZEOF WNDCLASSEX                           
        mov wc.style, CS_HREDRAW or CS_VREDRAW
        mov wc.lpfnWndProc, OFFSET ToolWndProc
                                
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
        mov eax, rect.bottom
        mov screenHeight, eax

        invoke CreateWindowEx,
        NULL,\
        ADDR ClassName,\
        ADDR AppName,\
        WS_CHILD or WS_VISIBLE or WS_BORDER,\
        0,\
        0,\
        120,\
        screenHeight,\
        hWnd,\
        NULL,\
        hToolInstance,\
        NULL

        mov hWndToolbar, eax

        mov ecx, hWnd
        mov mainWindowHwnd, ecx

        invoke ShowWindow,hWndToolbar,SW_SHOWDEFAULT
        invoke UpdateWindow, hWndToolbar
           
        ret
    WinTool endp

    ToolWndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM       
        LOCAL dwStyle:DWORD
        LOCAL rect:RECT
        LOCAL hwndButton: HWND
        LOCAL hBrush:HBRUSH
        LOCAL cc:CHOOSECOLOR
                                
        .IF uMsg==WM_DESTROY                               

            invoke PostQuitMessage,NULL

            ret

        .ELSEIF uMsg == WM_CREATE

            invoke GetWindowLong, hWnd, GWL_STYLE
            mov dwStyle, eax
        
            and dwStyle, NOT WS_SYSMENU
        
            invoke SetWindowLong, hWnd, GWL_STYLE, dwStyle

            ;Tools Buttons

            ;Brush Tool
            invoke LoadImage, NULL, OFFSET ID_ICON_BRUSH, IMAGE_ICON, 24, 24, LR_LOADFROMFILE or LR_DEFAULTSIZE
            mov hIconBrush, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonBrush, WS_CHILD or WS_VISIBLE or BS_ICON, 0, 0, 60, 30, hWnd, 1, hToolInstance, NULL 
            mov [hToolButtons + 0 * SIZEOF DWORD], eax

            invoke SendMessage, eax, BM_SETIMAGE, IMAGE_ICON, hIconBrush

            ;Rectangle Tool
            invoke LoadImage, NULL, OFFSET ID_ICON_RECTANGLE, IMAGE_ICON, 24, 24, LR_LOADFROMFILE or LR_DEFAULTSIZE
            mov hIconRectangle, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonRectangle, WS_CHILD or WS_VISIBLE or BS_ICON, 60, 0, 60, 30, hWnd, 2, hToolInstance, NULL
            mov [hToolButtons + 1 * SIZEOF DWORD], eax

            invoke SendMessage, eax, BM_SETIMAGE, IMAGE_ICON, hIconRectangle

            ;Ellipse Tool
            invoke LoadImage, NULL, OFFSET ID_ICON_ELLIPSE, IMAGE_ICON, 24, 24, LR_LOADFROMFILE or LR_DEFAULTSIZE
            mov hIconEllipse, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonEllipse, WS_CHILD or WS_VISIBLE or BS_ICON, 0, 30, 60, 30, hWnd, 3, hToolInstance, NULL
            mov [hToolButtons + 2 * SIZEOF DWORD], eax

            invoke SendMessage, eax, BM_SETIMAGE, IMAGE_ICON, hIconEllipse

            ;Line Tool
            invoke LoadImage, NULL, OFFSET ID_ICON_LINE, IMAGE_ICON, 24, 24, LR_LOADFROMFILE or LR_DEFAULTSIZE
            mov hIconLine, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonLine, WS_CHILD or WS_VISIBLE or BS_ICON, 60, 30, 60, 30, hWnd, 4, hToolInstance, NULL
            mov [hToolButtons + 3 * SIZEOF DWORD], eax

            invoke SendMessage, eax, BM_SETIMAGE, IMAGE_ICON, hIconLine

            ;Paint Bucket Tool
            
            invoke LoadImage, NULL, OFFSET ID_ICON_PAINT_BUCKET, IMAGE_ICON, 24, 24, LR_LOADFROMFILE or LR_DEFAULTSIZE
            mov hIconPaintBucket, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonBucket, WS_CHILD or WS_VISIBLE or BS_ICON, 0, 60, 60, 30, hWnd, 5, hToolInstance, NULL
            mov [hToolButtons + 4 * SIZEOF DWORD], eax

            invoke SendMessage, eax, BM_SETIMAGE, IMAGE_ICON, hIconPaintBucket

            ;Eraser Tool

            invoke LoadImage, NULL, OFFSET ID_ICON_ERASER, IMAGE_ICON, 24, 24, LR_LOADFROMFILE or LR_DEFAULTSIZE
            mov hIconEraser, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonEraser, WS_CHILD or WS_VISIBLE or BS_ICON, 60, 60, 60, 30, hWnd, 0, hToolInstance, NULL
            mov [hToolButtons + 5 * SIZEOF DWORD], eax

            invoke SendMessage, eax, BM_SETIMAGE, IMAGE_ICON, hIconEraser

            ;Colors Buttons

            invoke CreateWindowEx, 0, OFFSET szButtonClass, NULL, WS_CHILD or WS_VISIBLE or BS_OWNERDRAW, 0, 90, 120, 30, hWnd, 108, hToolInstance, NULL 
            mov [hColorButtons + 8 * SIZEOF DWORD], eax
            mov hwndButton, eax

            ret
        .ELSEIF uMsg == WM_DRAWITEM
            mov eax, lParam

            mov esi, [eax + DRAWITEMSTRUCT.hdc]
            lea edi, [eax + DRAWITEMSTRUCT.rcItem]

            push BF_RECT or BF_MONO
            push EDGE_RAISED                    
            push edi                            
            push esi                            
            call DrawEdge                       

            ret
        .ELSEIF uMsg == WM_CTLCOLORBTN 
            mov eax, lParam
            invoke GetDlgCtrlID, eax
            mov ecx, eax

            .if ecx == 100 
                mov edx, 000000FFh 
            .elseif ecx == 101 
                mov edx, 00FF0000h
            .elseif ecx == 102 
                mov edx, 0001BFFFh
            .elseif ecx == 103 
                mov edx, 0000FF00h 
            .elseif ecx == 104 
                mov edx, 00A53F87h 
            .elseif ecx == 105 
                mov edx, 00037DFFh 
            .elseif ecx == 106 
                mov edx, 00000000h 
            .elseif ecx == 107 
                 mov edx, 00FFFFFFh 
            .elseif ecx == 108
                mov ecx, color
                mov edx, ecx
            .endif 

            invoke CreateSolidBrush, edx
            ret
        .ELSEIF uMsg == WM_COMMAND
                
                .IF wParam >= 0 && wParam <= 5 
                    mov edx, wParam 
                    mov DWORD PTR [selectedTool], edx
                    invoke SetFocus, mainWindowHwnd
                .ENDIF
                
                .IF wParam >= 100 && wParam <= 107
                    
                    ;Colors
                    .IF wParam == 100
                        mov edx, 000000FFh          ;Red
                    .ELSEIF wParam == 101       
                        mov edx, 00FF0000h          ;Blue
                    .ELSEIF wParam == 102
                        mov edx, 0001BFFFh          ;Yellow
                    .ELSEIF wParam == 103
                       mov edx, 0000FF00h           ;Green
                    .ELSEIF wParam == 104
                       mov edx, 00A53F87h           ;Purple
                    .ELSEIF wParam == 105
                       mov edx, 00037DFFh           ;Orange
                    .ELSEIF wParam == 106
                       mov edx, 00000000h           ;Black 
                    .ELSEIF wParam == 107
                       mov edx, 00FFFFFFh           ;White 
                    .ENDIF

                    mov DWORD PTR [color], edx

                    invoke RedrawWindow, hWnd, NULL, NULL, RDW_INVALIDATE or RDW_UPDATENOW

                    invoke SetFocus, mainWindowHwnd

                .ENDIF
                
                .IF wParam == 108
                    invoke RtlZeroMemory, addr cc, sizeof CHOOSECOLOR
                    mov cc.lStructSize, sizeof CHOOSECOLOR
                    mov eax, hWnd
                    mov cc.hwndOwner, eax
                    mov eax, color
                    mov cc.rgbResult, eax
                    mov cc.lpCustColors, OFFSET customColors
                    mov cc.Flags, CC_RGBINIT or CC_FULLOPEN

                    invoke ChooseColor, addr cc
                    .IF eax != 0
                        mov eax, cc.rgbResult
                        mov color, eax
                        invoke RedrawWindow, hWnd, NULL, NULL, RDW_INVALIDATE or RDW_UPDATENOW
                        invoke SetFocus, mainWindowHwnd
                    .ENDIF
                .ENDIF

                invoke SetFocus, hWnd

                ret
        .ELSE
            invoke DefWindowProc,hWnd,uMsg,wParam,lParam
            ret
        .ENDIF

        xor eax,eax
        ret

    ToolWndProc endp
    End