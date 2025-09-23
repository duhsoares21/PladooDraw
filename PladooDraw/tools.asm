.686
.model flat,stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\gdi32.inc
include \masm32\include\kernel32.inc
include \masm32\include\comdlg32.inc

include resource_icons.inc

includelib PladooDraw_Direct2D_LayerSystem.lib

.DATA                
    ClassName db "ToolbarWindowClass",0                 
    AppName db "Tool Window",0                 

    szButtonBrush db "(B)", 0
    szButtonRectangle db "(R)", 0
    szButtonEllipse db "(E)", 0
    szButtonLine db "(L)", 0
    szButtonBucket db "(P)", 0
    szButtonEraser db "(D)", 0
    szButtonMove db "(M)", 0
    szButtonText db "(T)", 0
    szButtonFont db "Choose Font", 0
    szButtonSave db "Save (S)", 0
    szButtonLoad db "Load (K)", 0
    szPixelText db "Pixel Mode", 0

    szErrorFont db "Failed to choose font", 0
    szTitleSuccess db "Success", 0
    szTitleError db "Error", 0
    szDebugFmt db "lfFaceName: %ls", 0
    szDebugBuffer db 128 dup(0)
    
    hIconBrush      HICON ?
    hIconRectangle      HICON ?
    hIconEllipse      HICON ?
    hIconLine      HICON ?
    hIconPaintBucket      HICON ?
    hIconEraser      HICON ?
    hIconMove      HICON ?
    hIconText      HICON ?

    szButtonClass db "BUTTON", 0
    szNotification db "Notification", 0
    szButtonClicked db "Clicked", 0

    hColorButtons HWND 9 DUP(?)
    customColors     dd 16 dup(0)
    
    screenWidth DWORD 0
    screenHeight DWORD 0

    pddFilter db 'Paint Document (*.pdd)',0
          db '*.pdd',0
          db 0
    defaultExt db 'pdd',0

    EXTERN selectedTool:DWORD
    EXTERN brushSize:DWORD
    EXTERN color:COLORREF

    EXTERN msgText:BYTE
	EXTERN msgFmt:BYTE

    EXTERN windowTitleInformation:BYTE
	EXTERN windowTitleError:BYTE

    EXTERN btnWidth:DWORD
    EXTERN btnHeight:DWORD
    EXTERN layerID:DWORD

    EXTERN docHwnd :HWND
    toolCount EQU 8

    EXTERN SetSelectedTool:proc
    
    SaveProjectDll PROTO STDCALL :PTR BYTE
    LoadProjectDll PROTO STDCALL :PTR WORD, :HWND, :HINSTANCE, :PTR DWORD, :PTR DWORD, :PTR DWORD, :DWORD, :PTR WORD, :PTR BYTE
    
    SetFont PROTO STDCALL

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

    unicode_filename WCHAR MAX_PATH dup(?)

    EXTERN hLayerButtons:HWND
    EXTERN hWndLayer:HWND
    EXTERN hLayerInstance:HINSTANCE

    EXTERN pixelModeFlag:DWORD

    hdc HDC ?

    saveFilePath db MAX_PATH dup(?)
    ofn           OPENFILENAME <>

    openFilePath dw MAX_PATH dup(0)
    ofnOpen       OPENFILENAME <>

.CODE          

   
    SaveFileDialog PROC
        ; Zera a estrutura OPENFILENAME
        invoke RtlZeroMemory, addr ofn, sizeof ofn

        ; Configura o OPENFILENAME
        mov ofn.lStructSize, sizeof ofn
        push mainWindowHwnd
        pop ofn.hwndOwner
        mov ofn.lpstrFile, offset saveFilePath
        mov ofn.nMaxFile, MAX_PATH
        mov ofn.lpstrFilter, offset pddFilter
        mov ofn.Flags, OFN_OVERWRITEPROMPT or OFN_PATHMUSTEXIST
        mov ofn.lpstrDefExt, offset defaultExt

        mov byte ptr [saveFilePath], 0

        ; Chama o di�logo
        invoke GetSaveFileName, addr ofn
        .if eax != 0
            invoke SaveProjectDll, addr saveFilePath
        .endif

        ret
    SaveFileDialog ENDP

LoadFileDialog PROC
    invoke RtlZeroMemory, addr ofnOpen, sizeof ofnOpen
    mov ofnOpen.lStructSize, sizeof ofnOpen
    push mainWindowHwnd
    pop ofnOpen.hwndOwner
    mov ofnOpen.lpstrFile, offset openFilePath
    mov ofnOpen.nMaxFile, MAX_PATH
    mov ofnOpen.lpstrFilter, offset pddFilter
    mov ofnOpen.Flags, OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST
    mov ofnOpen.lpstrDefExt, offset defaultExt
    mov byte ptr [openFilePath], 0
    invoke GetOpenFileName, addr ofnOpen
    .if eax != 0
        ; Mostra o nome do arquivo selecionado
        invoke LoadProjectDll, addr openFilePath, hWndLayer, hLayerInstance, btnWidth, btnHeight, addr hLayerButtons, addr layerID, addr szButtonClass, addr msgText
    .endif
    ret
LoadFileDialog ENDP

    
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

            ;Eraser Tool

            invoke LoadImage, hToolInstance, ID_ICON_ERASER, IMAGE_ICON, 24, 24, LR_DEFAULTCOLOR or LR_DEFAULTSIZE
            mov hIconEraser, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonEraser, WS_CHILD or WS_VISIBLE or BS_ICON, 60, 60, 60, 30, hWnd, 0, hToolInstance, NULL
            mov [hToolButtons + 0 * SIZEOF DWORD], eax

            invoke SendMessage, eax, BM_SETIMAGE, IMAGE_ICON, hIconEraser

            ;Brush Tool
            invoke LoadImage, hToolInstance, ID_ICON_BRUSH, IMAGE_ICON, 24, 24, LR_DEFAULTCOLOR or LR_DEFAULTSIZE
            mov hIconBrush, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonBrush, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON or BS_ICON, 0, 0, 60, 30, hWnd, 1, hToolInstance, NULL 
            mov [hToolButtons + 1 * SIZEOF DWORD], eax

            invoke SendMessage, eax, BM_SETIMAGE, IMAGE_ICON, hIconBrush

            ;Rectangle Tool
            invoke LoadImage, hToolInstance, ID_ICON_RECTANGLE, IMAGE_ICON, 24, 24, LR_DEFAULTCOLOR or LR_DEFAULTSIZE
            mov hIconRectangle, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonRectangle, WS_CHILD or WS_VISIBLE or BS_ICON, 60, 0, 60, 30, hWnd, 2, hToolInstance, NULL
            mov [hToolButtons + 2 * SIZEOF DWORD], eax

            invoke SendMessage, eax, BM_SETIMAGE, IMAGE_ICON, hIconRectangle

            ;Ellipse Tool
            invoke LoadImage, hToolInstance, ID_ICON_ELLIPSE, IMAGE_ICON, 24, 24, LR_DEFAULTCOLOR or LR_DEFAULTSIZE
            mov hIconEllipse, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonEllipse, WS_CHILD or WS_VISIBLE or BS_ICON, 0, 30, 60, 30, hWnd, 3, hToolInstance, NULL
            mov [hToolButtons + 3 * SIZEOF DWORD], eax

            invoke SendMessage, eax, BM_SETIMAGE, IMAGE_ICON, hIconEllipse

            ;Line Tool
            invoke LoadImage, hToolInstance, ID_ICON_LINE, IMAGE_ICON, 24, 24, LR_DEFAULTCOLOR or LR_DEFAULTSIZE
            mov hIconLine, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonLine, WS_CHILD or WS_VISIBLE or BS_ICON, 60, 30, 60, 30, hWnd, 4, hToolInstance, NULL
            mov [hToolButtons + 4 * SIZEOF DWORD], eax

            invoke SendMessage, eax, BM_SETIMAGE, IMAGE_ICON, hIconLine

            ;Paint Bucket Tool
            
            invoke LoadImage, hToolInstance, ID_ICON_PAINT_BUCKET, IMAGE_ICON, 24, 24, LR_DEFAULTCOLOR or LR_DEFAULTSIZE
            mov hIconPaintBucket, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonBucket, WS_CHILD or WS_VISIBLE or BS_ICON, 0, 60, 60, 30, hWnd, 5, hToolInstance, NULL
            mov [hToolButtons + 5 * SIZEOF DWORD], eax

            invoke SendMessage, eax, BM_SETIMAGE, IMAGE_ICON, hIconPaintBucket

            ;Move Tool
            invoke LoadImage, hToolInstance, ID_ICON_MOVE, IMAGE_ICON, 24, 24, LR_DEFAULTCOLOR or LR_DEFAULTSIZE
            mov hIconMove, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonMove, WS_CHILD or WS_VISIBLE or BS_ICON, 0, 90, 60, 30, hWnd, 6, hToolInstance, NULL
            mov [hToolButtons + 6 * SIZEOF DWORD], eax

            invoke SendMessage, eax, BM_SETIMAGE, IMAGE_ICON, hIconMove

            ;Text Tool
            invoke LoadImage, hToolInstance, ID_ICON_TEXT, IMAGE_ICON, 24, 24, LR_DEFAULTCOLOR or LR_DEFAULTSIZE
            mov hIconText, eax

            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonText, WS_CHILD or WS_VISIBLE or BS_ICON, 60, 90, 60, 30, hWnd, 7, hToolInstance, NULL
            mov [hToolButtons + 7 * SIZEOF DWORD], eax

            invoke SendMessage, eax, BM_SETIMAGE, IMAGE_ICON, hIconText

            ;Color Button

            invoke CreateWindowEx, 0, OFFSET szButtonClass, NULL, WS_CHILD or WS_VISIBLE or BS_OWNERDRAW, 0, 120, 120, 30, hWnd, 101, hToolInstance, NULL 
            mov [hColorButtons + 8 * SIZEOF DWORD], eax

            ;Font Button
            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonFont, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, 150, 120, 30, hWnd, 105, hToolInstance, NULL
            mov [hToolButtons + 9 * SIZEOF DWORD], eax

            ;Save Button
            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonSave, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, 180, 120, 30, hWnd, 102, hToolInstance, NULL
            mov [hToolButtons + 10 * SIZEOF DWORD], eax

            ;Load Button
            invoke CreateWindowEx, 0, OFFSET szButtonClass, OFFSET szButtonLoad, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 0, 210, 120, 30, hWnd, 103, hToolInstance, NULL
            mov [hToolButtons + 11 * SIZEOF DWORD], eax

            ; Checkbox: Pixel Mode
            invoke CreateWindowEx, 0, ADDR szButtonClass, OFFSET szPixelText, WS_CHILD or WS_VISIBLE or BS_AUTOCHECKBOX, 0, 240, 120, 30, hWnd, 104, hToolInstance, NULL
            mov [hToolButtons + 12 * SIZEOF DWORD], eax

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

            .if ecx == 101
                mov ecx, color
                mov edx, ecx
            .endif 

            invoke CreateSolidBrush, edx
            ret
        .ELSEIF uMsg == WM_COMMAND
                
                .IF wParam >= 0 && wParam <= 100 
                    mov edx, wParam 
                    mov DWORD PTR [selectedTool], edx
                    push selectedTool
                    call SetSelectedTool
                    invoke SetFocus, docHwnd

                    invoke SendMessage, [hToolButtons + 0 * SIZEOF DWORD], BM_SETSTATE, 0, 0
                    invoke SendMessage, [hToolButtons + 1 * SIZEOF DWORD], BM_SETSTATE, 0, 0
                    invoke SendMessage, [hToolButtons + 2 * SIZEOF DWORD], BM_SETSTATE, 0, 0
                    invoke SendMessage, [hToolButtons + 3 * SIZEOF DWORD], BM_SETSTATE, 0, 0
                    invoke SendMessage, [hToolButtons + 4 * SIZEOF DWORD], BM_SETSTATE, 0, 0
                    invoke SendMessage, [hToolButtons + 5 * SIZEOF DWORD], BM_SETSTATE, 0, 0
                    invoke SendMessage, [hToolButtons + 6 * SIZEOF DWORD], BM_SETSTATE, 0, 0
                    invoke SendMessage, [hToolButtons + 7 * SIZEOF DWORD], BM_SETSTATE, 0, 0

                    mov ebx, wParam
                    invoke SendMessage, [hToolButtons + ebx * SIZEOF DWORD], BM_SETSTATE, 1, 0
                .ENDIF
                
                .IF wParam == 101
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

                .IF wParam == 102
                    invoke SaveFileDialog
                .ENDIF

                .IF wParam == 103
                    invoke LoadFileDialog
                .ENDIF

                .IF wParam == 104
                    ; Get checkbox state
                    invoke SendDlgItemMessage, hWnd, 104, BM_GETCHECK, 0, 0
                    .IF eax == BST_CHECKED
                        mov pixelModeFlag, 1
                    .ELSE
                        mov pixelModeFlag, 0
                    .ENDIF
                .ENDIF

                 .IF wParam == 105  
                    invoke SetFont
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
