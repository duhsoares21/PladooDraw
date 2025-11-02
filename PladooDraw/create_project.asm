.686

.MODEL flat,stdcall

include \masm32\include\windows.inc 
include \masm32\include\user32.inc
include \masm32\include\gdi32.inc
include \masm32\include\shell32.inc
include \masm32\include\kernel32.inc

include resource_cursors.inc

EXTERN Cleanup:proc
EXTERN Initialize:proc
EXTERN InitializeDocument:proc
EXTERN InitializeWrite:proc
EXTERN InitializeSurfaceDial:proc
EXTERN GetActiveLayersCount:proc

WinDocument proto :HWND
WinTool proto :HWND
WinLayer proto :HWND
WinTimeline proto :HWND
WinTimelineAux proto :HWND

.DATA 

    EXTERN color:COLORREF
    EXTERN createProjectHwnd:HWND
    EXTERN documentWidth:DWORD
    EXTERN documentHeight:DWORD
    EXTERN szButtonClass:BYTE
    EXTERN btnWidth:DWORD
    EXTERN btnHeight:DWORD
    EXTERN mainHwnd:HWND
    EXTERN docHwnd:HWND
    EXTERN toolsHwnd:HWND
    EXTERN layerWindowHwnd:HWND
    EXTERN EditFromThisPointHWND:HWND
    EXTERN hControlButtons:HWND
    EXTERN hMainInstance:HINSTANCE

    createProjectWindowWidth DWORD 0
    createProjectWindowHeight DWORD 0

    szButtonSquare db "SQUARE (1:1)", 0
    szButtonRectangle db "RECTANGLE (16:9)", 0

    ProjectClassName db "CreateProjectWindowClass",0                 
    ProjectAppName db "Create New Project",0    

    szReplayText db "Replay Mode", 0
    szAnimationText db "Animation Mode", 0
    szEditFromThisPointText db "Edit From This Point", 0

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

    AnimationModeCheckboxHWND HWND ?
    ReplayModeCheckboxHWND HWND ?
    buttonSquare HWND ?
    buttonRectangle HWND ?
    
    EXTERN hDefaultCursor:HCURSOR
    hCreateProjectInstance HINSTANCE ?

.CODE

SetupProject proc hWnd:HWND
    ; 1) pega �rea cliente
    invoke GetClientRect, hWnd, ADDR SetupProjectRect

    ; largura = right - left
    mov eax, SetupProjectRect.right
    mov ecx, SetupProjectRect.left
    sub eax, ecx
    mov createProjectWindowWidth, eax

    ; altura = bottom - top
    mov eax, SetupProjectRect.bottom
    mov ecx, SetupProjectRect.top
    sub eax, ecx
    mov createProjectWindowHeight, eax

    ; 2) calcula centro (X e Y)
    mov eax, createProjectWindowWidth
    xor edx, edx
    mov ecx, 2
    div ecx
    mov CenterX, eax

    mov eax, createProjectWindowHeight
    xor edx, edx
    mov ecx, 2
    div ecx
    mov CenterY, eax

    ; 3) calcula altura dos bot�es = 1/3 da altura da janela
    mov eax, createProjectWindowHeight
    xor edx, edx
    mov ecx, 3
    div ecx
    mov NewButtonHeight, eax         ; altura comum aos 2 bot�es

    ; 4) largura do bot�o quadrado = mesma altura
    mov eax, NewButtonHeight
    mov WidthSquare, eax

    ; 5) largura do bot�o retangular = height * 16 / 9
    mov eax, NewButtonHeight
    mov ecx, 16
    mul ecx                          ; EDX:EAX = height * 16
    mov ecx, 9
    div ecx                          ; EAX = (height*16)/9
    mov WidthRect, eax

    ; 6) spacing entre bot�es (ajuste se quiser)
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

    ; 9) leftX = centerX - halfTotal  (in�cio do bloco centralizado)
    mov eax, CenterX
    sub eax, HalfTotal
    mov LeftX, eax

    ; 10) calcula Y dos bot�es (centerY - height/2)
    mov eax, CenterY
    mov ecx, NewButtonHeight
    shr ecx, 1
    sub eax, ecx
    mov NewButtonPositionY, eax

    ; 11) cria bot�o SQUARE (1:1) na posi��o LeftX
    mov eax, LeftX
    mov NewButtonPositionX, eax
    invoke CreateWindowEx, 0, ADDR szButtonClass, ADDR szButtonSquare, \
        WS_CHILD or WS_VISIBLE or BS_FLAT, \
        NewButtonPositionX, NewButtonPositionY, \
        WidthSquare, NewButtonHeight, \
        hWnd, 512, hCreateProjectInstance, NULL
    mov buttonSquare, eax

    ; 12) button RECTANGLE X = LeftX + widthSquare + spacing
    mov eax, LeftX
    add eax, WidthSquare
    add eax, Spacing
    mov NewButtonPositionX, eax

    invoke CreateWindowEx, 0, ADDR szButtonClass, ADDR szButtonRectangle, \
        WS_CHILD or WS_VISIBLE or BS_FLAT, \
        NewButtonPositionX, NewButtonPositionY, \
        WidthRect, NewButtonHeight, \
        hWnd, 720, hCreateProjectInstance, NULL
    mov buttonRectangle, eax
    ret
SetupProject endp

StartDraw proc   
    LOCAL rect:RECT
    LOCAL parentWidth:DWORD
    LOCAL halfParentWidth:DWORD
    LOCAL xCenter:DWORD

    .IF documentWidth > 512
        mov btnWidth, 190
        mov btnHeight, 120
    .ELSE
        mov btnWidth, 120
        mov btnHeight, 120
    .ENDIF

    call Cleanup

    push mainHwnd
    call Initialize

    push mainHwnd
    call InitializeSurfaceDial

    invoke WinDocument, mainHwnd
    invoke WinTimeline, mainHwnd
    invoke WinTimelineAux, mainHwnd
    invoke WinLayer, mainHwnd
    invoke WinTool, mainHwnd

    invoke GetClientRect, mainHwnd, addr rect
            
    mov eax, rect.right
    mov ecx, rect.left
    sub eax, ecx
            
    mov parentWidth, eax

    mov eax, parentWidth
    mov ecx, 2
    div ecx

    mov halfParentWidth, eax

    mov eax, halfParentWidth
    sub eax, 60

    mov xCenter, eax

    ; Checkbox: Replay Mode
    invoke CreateWindowEx, 0, ADDR szButtonClass, OFFSET szReplayText, WS_VISIBLE or WS_CHILD or BS_AUTOCHECKBOX, xCenter, 50, 120, 30, mainHwnd, 108, hMainInstance, NULL
    mov ReplayModeCheckboxHWND, eax

    mov eax, halfParentWidth
    sub eax, 75

    mov xCenter, eax

    ; Checkbox: Animation Mode
    invoke CreateWindowEx, 0, ADDR szButtonClass, OFFSET szAnimationText, WS_VISIBLE or WS_CHILD or BS_AUTOCHECKBOX, xCenter, 100, 150, 30, mainHwnd, 110, hMainInstance, NULL
    mov AnimationModeCheckboxHWND, eax

    mov eax, halfParentWidth
    sub eax, 75

    mov xCenter, eax

    ;Button: Edit From this Point
    invoke CreateWindowEx, 0, ADDR szButtonClass, OFFSET szEditFromThisPointText, WS_CHILD or BS_PUSHBUTTON, xCenter, 100, 150, 30, mainHwnd, 109, hMainInstance, NULL
    mov EditFromThisPointHWND, eax

    invoke SendMessage, createProjectHwnd, WM_CLOSE, 0, 0

    ret 
StartDraw endp

 WinCreateProject proc hWnd:HWND
	LOCAL wc:WNDCLASSEX                                         
    LOCAL workArea: RECT

    invoke RtlZeroMemory, addr wc, SIZEOF WNDCLASSEX

    mov color, 00000000h
            
    mov wc.cbClsExtra, 0
    mov wc.cbWndExtra, 0
    mov wc.cbSize,SIZEOF WNDCLASSEX                           
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, OFFSET WndCreateProjectProc

    invoke GetModuleHandle, NULL            
    mov wc.hInstance, eax
    mov hCreateProjectInstance, eax

    xor eax, eax

    mov wc.hbrBackground,COLOR_WINDOWFRAME+1
    mov wc.lpszMenuName,NULL
    mov wc.lpszClassName,OFFSET ProjectClassName
            
    invoke LoadIcon,hCreateProjectInstance,ID_ICON_APPLICATION

    mov wc.hIcon,eax
    mov wc.hIconSm,eax
            
    invoke LoadCursor,NULL,IDC_ARROW
    mov wc.hCursor, eax
    mov hDefaultCursor, eax
        
    invoke RegisterClassEx, addr wc       
        
    invoke CreateWindowEx, 
    0, 
    ADDR ProjectClassName, 
    ADDR ProjectAppName, 
    WS_OVERLAPPEDWINDOW or WS_CLIPCHILDREN, 
    500, 
    400, 
    400, 
    400, 
    hWnd, 
    NULL, 
    hCreateProjectInstance, 
    NULL

    mov createProjectHwnd, eax

    invoke ShowWindow,createProjectHwnd,SW_SHOWDEFAULT
    invoke UpdateWindow, createProjectHwnd
    
    ret
 WinCreateProject endp

 WndCreateProjectProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
         LOCAL dwStyle:DWORD

        .IF uMsg == WM_CREATE

            invoke GetWindowLong, hWnd, GWL_STYLE
            mov dwStyle, eax
        
            invoke SetWindowLong, hWnd, GWL_STYLE, dwStyle
            invoke SetCursor, hDefaultCursor

            push hWnd
            call SetupProject

            ret
        .ELSEIF uMsg == WM_COMMAND
            .IF wParam == 512
                mov ecx, wParam
                mov documentWidth, ecx
                mov documentHeight, ecx

                xor ecx, ecx

                call StartDraw
                ret
            .ELSEIF wParam == 720
              
                mov ecx, wParam
                mov documentWidth, 1280
                mov documentHeight, ecx
                
                xor ecx, ecx

                call StartDraw
                ret
            .ENDIF
            ret
        .ELSE
            invoke DefWindowProc,hWnd,uMsg,wParam,lParam
            ret
        .ENDIF
        ret
 WndCreateProjectProc endp

 END