.686
.model flat,stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\gdi32.inc
include \masm32\include\kernel32.inc

.DATA                
    ClassName db "ToolbarWindowClass",0                 
    AppName db "Tool Window",0                 

    szButtonBrush db "Brush (B)", 0
    szButtonRectangle db "Rectangle (R)", 0
    szButtonEllipse db "Ellipse (C)", 0
    szButtonLine db "Line (L)", 0
    szButtonBucket db "Bucket (F)", 0
    szButtonEraser db "Eraser (E)", 0

    szButtonRed db "Red", 0
    szButtonBlue db "Blue", 0
    szButtonYellow db "Yellow", 0
    szButtonGreen db "Green", 0
    szButtonBlack db "Black", 0
    szButtonWhite db "White", 0
    szButtonPurple db "Purple", 0
    szButtonOrange db "Orange", 0
    
    szButtonClass db "BUTTON", 0
    szNotification db "Notification", 0
    szButtonClicked db "Clicked", 0

    hColorButtons HWND 9 DUP(?)

    screenWidth DWORD 0
    screenHeight DWORD 0

    EXTERN selectedTool:DWORD
    EXTERN brushSize:DWORD
    EXTERN color:COLORREF

    EXTERN msgText:BYTE
	EXTERN msgFmt:BYTE

    EXTERN windowTitleInformation:BYTE
	EXTERN windowTitleError:BYTE

.DATA?           

    mainWindowHwnd HWND ?

    hToolInstance HINSTANCE ?                       

    hDefaultCursor HCURSOR ?

    hToolButtons HWND ?

    hRedBrush HBRUSH ? 
    hBlueBrush HBRUSH ? 
    hYellowBrush HBRUSH ? 
    hGreenBrush HBRUSH ? 
    hPurpleBrush HBRUSH ? 
    hOrangeBrush HBRUSH ? 
    hBlackBrush HBRUSH ? 
    hWhiteBrush HBRUSH ?

    hdc HDC ?

.CODE          
    
    WinTool proc hWnd:HWND    
        LOCAL hWndToolbar:HWND

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

        invoke GetSystemMetrics, SM_CYSCREEN
        sub eax, 40
        mov screenHeight, eax

        invoke CreateWindowEx,
        NULL,\
        ADDR ClassName,\
        ADDR AppName,\
        WS_CHILD or WS_VISIBLE or CCS_VERT or TBSTYLE_TOOLTIPS or TBSTYLE_FLAT,\
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
                                
        .IF uMsg==WM_DESTROY                               

            invoke PostQuitMessage,NULL

            ret

        .ELSEIF uMsg == WM_CREATE

            invoke GetWindowLong, hWnd, GWL_STYLE
            mov dwStyle, eax
        
            and dwStyle, NOT WS_SYSMENU
        
            invoke SetWindowLong, hWnd, GWL_STYLE, dwStyle

            ;Tools Buttons

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonBrush, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, 0, 120, 30, hWnd, 1, hToolInstance, NULL 
            mov [hToolButtons + 0 * SIZEOF DWORD], eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonRectangle, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, 30, 120, 30, hWnd, 2, hToolInstance, NULL
            mov [hToolButtons + 1 * SIZEOF DWORD], eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonEllipse, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, 60, 120, 30, hWnd, 3, hToolInstance, NULL
            mov [hToolButtons + 2 * SIZEOF DWORD], eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonLine, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, 90, 120, 30, hWnd, 4, hToolInstance, NULL
            mov [hToolButtons + 3 * SIZEOF DWORD], eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonBucket, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, 120, 120, 30, hWnd, 5, hToolInstance, NULL
            mov [hToolButtons + 4 * SIZEOF DWORD], eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonEraser, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, 150, 120, 30, hWnd, 0, hToolInstance, NULL
            mov [hToolButtons + 5 * SIZEOF DWORD], eax

            ;Colors Buttons

            invoke CreateWindowEx, 0, OFFSET szButtonClass, NULL, WS_CHILD or WS_VISIBLE or BS_OWNERDRAW, 0, 210, 60, 30, hWnd, 100, hToolInstance, NULL 
            mov [hColorButtons + 0 * SIZEOF DWORD], eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonBlue, WS_CHILD or WS_VISIBLE or BS_OWNERDRAW, 60, 210, 60, 30, hWnd, 101, hToolInstance, NULL 
            mov [hColorButtons + 1 * SIZEOF DWORD], eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonYellow, WS_CHILD or WS_VISIBLE or BS_OWNERDRAW, 0, 240, 60, 30, hWnd, 102, hToolInstance, NULL 
            mov [hColorButtons + 2 * SIZEOF DWORD], eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonGreen, WS_CHILD or WS_VISIBLE or BS_OWNERDRAW, 60, 240, 60, 30, hWnd, 103, hToolInstance, NULL 
            mov [hColorButtons + 3 * SIZEOF DWORD], eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonPurple, WS_CHILD or WS_VISIBLE or BS_OWNERDRAW, 0, 270, 60, 30, hWnd, 104, hToolInstance, NULL 
            mov [hColorButtons + 4 * SIZEOF DWORD], eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonOrange, WS_CHILD or WS_VISIBLE or BS_OWNERDRAW, 60, 270, 60, 30, hWnd, 105, hToolInstance, NULL 
            mov [hColorButtons + 5 * SIZEOF DWORD], eax
                
            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonBlack, WS_CHILD or WS_VISIBLE or BS_OWNERDRAW, 0, 300, 60, 30, hWnd, 106, hToolInstance, NULL 
            mov [hColorButtons + 6 * SIZEOF DWORD], eax
            
            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonWhite, WS_CHILD or WS_VISIBLE or BS_OWNERDRAW, 60, 300, 60, 30, hWnd, 107, hToolInstance, NULL 
            mov [hColorButtons + 7 * SIZEOF DWORD], eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, NULL, WS_CHILD or WS_VISIBLE or BS_OWNERDRAW, 0, 330, 120, 30, hWnd, 108, hToolInstance, NULL 
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