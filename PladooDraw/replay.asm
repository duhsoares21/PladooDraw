.686
.model flat,stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\gdi32.inc
include \masm32\include\kernel32.inc
include \masm32\include\comdlg32.inc
include \masm32\include\shell32.inc

include resource_icons.inc

includelib shell32.lib
includelib PladooDraw_Direct2D_LayerSystem.lib

EXTERN SetSelectedTool:proc
EXTERN AnimationForward:proc
EXTERN AnimationBackward:proc
EXTERN PlayAnimation:proc
EXTERN PauseAnimation:proc
EXTERN ReplayBackwards:proc
EXTERN ReplayForward:proc
EXTERN InitializeReplay: PROC
EXTERN OnScrollWheelReplay: PROC
EXTERN CreateAnimationFrame: PROC
EXTERN RemoveAnimationFrame: PROC

.DATA  

    EXTERN btnWidth:DWORD
    EXTERN btnHeight:DWORD
    EXTERN timelineHwnd:HWND
    EXTERN animationModeFlag: DWORD
    EXTERN replayModeFlag: DWORD

    szFontName dw 'S','e','g','o','e',' ','U','I',' ','S','y','m','b','o','l',0

    ReplayClassName db "ReplayClass", 0
    ReplayAppName db "Timeline",0

    szButtonClass dw 'B','U','T','T','O','N', 0
   
    szButtonRW dw 23EAh, 0
    szButtonStepMinus dw 23EEh, 0
    szButtonPlay dw 23F5h, 0
    szButtonPause dw 23F8h, 0
    szButtonStepPlus dw 23EDh, 0
    szButtonFF dw 23E9h, 0
    szButtonAdd dw 002Bh, 0
    szButtonRemove dw 002Dh, 0

    screenWidth DWORD 0
    screenHeight DWORD 0

    halfScreenWidth DWORD 0
    centerX DWORD 0

.DATA?
    hFontSegoeUISymbol  HFONT ?

    hReplayInstance HINSTANCE ?
    hDefaultCursor HCURSOR ?
    hReplayButtons HWND ?

.CODE  

    WinReplay proc hWnd:HWND    
        LOCAL rect:RECT

        LOCAL wc:WNDCLASSEX                                         

        invoke GetModuleHandle, NULL            

        mov hReplayInstance,eax
        mov wc.hInstance, eax
               
        mov wc.cbSize,SIZEOF WNDCLASSEX                           
        mov wc.style, CS_HREDRAW or CS_VREDRAW
        mov wc.lpfnWndProc, OFFSET ReplayWndProc
                                
        xor eax, eax

        mov wc.hbrBackground,COLOR_BTNFACE+1
        mov wc.lpszMenuName,NULL
        mov wc.lpszClassName,OFFSET ReplayClassName
        
        invoke LoadIcon,NULL,IDI_APPLICATION

        mov wc.hIcon,eax
        mov wc.hIconSm,eax
        
        invoke LoadCursor,NULL,IDC_ARROW
        mov wc.hCursor, eax
        mov hDefaultCursor, eax
        
        invoke RegisterClassEx, addr wc

        invoke GetClientRect, hWnd, addr rect
        mov eax, rect.bottom
        sub eax, 190
        mov screenHeight, eax

        mov eax, rect.right
        mov ecx, rect.left
        sub eax, ecx 
        mov screenWidth, eax

        mov eax, screenWidth
        mov ecx, 2
        div ecx

        mov halfScreenWidth, eax

        xor eax, eax

        mov eax, halfScreenWidth
        mov ecx, 300
        sub eax, ecx

        mov centerX, eax

        invoke CreateWindowEx,
        NULL,\
        ADDR ReplayClassName,\
        ADDR ReplayAppName,\
        WS_VISIBLE or WS_BORDER or WS_CLIPSIBLINGS,\
        centerX,\
        screenHeight,\
        600,\
        220,\
        hWnd,\
        NULL,\
        hReplayInstance,\
        NULL

        mov timelineHwnd, eax

        invoke ShowWindow,timelineHwnd,SW_HIDE
        invoke UpdateWindow, timelineHwnd
           
        ret
    WinReplay endp

    KillTimers proc
        invoke KillTimer, timelineHwnd, 1
        invoke KillTimer, timelineHwnd, 2
        invoke KillTimer, timelineHwnd, 3
        invoke KillTimer, timelineHwnd, 4
        ret
    KillTimers endp

    ReplayWndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
        LOCAL rect:RECT
        LOCAL parentWidth:DWORD
        LOCAL halfParentWidth:DWORD
        LOCAL CenterX:DWORD

        .IF uMsg == WM_SHOWWINDOW
        
            invoke GetClientRect, hWnd, addr rect
            
            mov eax, rect.right
            mov ecx, rect.left
            sub eax, ecx
            
            mov parentWidth, eax

            mov eax, parentWidth
            mov ecx, 2
            div ecx

            mov halfParentWidth, eax

            mov eax, halfParentWidth
            sub eax, 25

            mov CenterX, eax

            xor eax, eax
            mov eax, CenterX
            sub eax, 70
            sub eax, 175

            invoke CreateWindowExW, 0, OFFSET szButtonClass, OFFSET szButtonRemove, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, 145, 50, 24, hWnd, 507, hReplayInstance, NULL 
            mov hReplayButtons[14 * SIZEOF DWORD], eax

            xor eax, eax
            mov eax, CenterX
            add eax, 0
            sub eax, 175

            invoke CreateWindowExW, 0, OFFSET szButtonClass, OFFSET szButtonRW, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, 145, 50, 24, hWnd, 500, hReplayInstance, NULL 
            mov hReplayButtons[15 * SIZEOF DWORD], eax

            xor eax, eax
            mov eax, CenterX
            add eax, 70
            sub eax, 175

            invoke CreateWindowExW, 0, OFFSET szButtonClass, OFFSET szButtonStepMinus, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, 145, 50, 24, hWnd, 501, hReplayInstance, NULL 
            mov hReplayButtons[16 * SIZEOF DWORD], eax

            xor eax, eax
            mov eax, CenterX
            add eax, 140
            sub eax, 175

            invoke CreateWindowExW, 0, OFFSET szButtonClass, OFFSET szButtonPlay, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, 145, 50, 24, hWnd, 502, hReplayInstance, NULL 
            mov hReplayButtons[17 * SIZEOF DWORD], eax

            xor eax, eax
            mov eax, CenterX
            add eax, 210
            sub eax, 175

            invoke CreateWindowExW, 0, OFFSET szButtonClass, OFFSET szButtonPause, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, 145, 50, 24, hWnd, 503, hReplayInstance, NULL 
            mov hReplayButtons[18 * SIZEOF DWORD], eax

            xor eax, eax
            mov eax, CenterX
            add eax, 280
            sub eax, 175

            invoke CreateWindowExW, 0, OFFSET szButtonClass, OFFSET szButtonStepPlus, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, 145, 50, 24, hWnd, 504, hReplayInstance, NULL 
            mov hReplayButtons[19 * SIZEOF DWORD], eax

            xor eax, eax
            mov eax, CenterX
            add eax, 350
            sub eax, 175

            invoke CreateWindowExW, 0, OFFSET szButtonClass, OFFSET szButtonFF, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, 145, 50, 24, hWnd, 505, hReplayInstance, NULL 
            mov hReplayButtons[20 * SIZEOF DWORD], eax

            xor eax, eax
            mov eax, CenterX
            add eax, 420
            sub eax, 175

            invoke CreateWindowExW, 0, OFFSET szButtonClass, OFFSET szButtonAdd, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, 145, 50, 24, hWnd, 506, hReplayInstance, NULL 
            mov hReplayButtons[21 * SIZEOF DWORD], eax

            invoke CreateFontW, 24, 30, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, \
                    DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, \
                    DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, \
                    OFFSET szFontName
            mov hFontSegoeUISymbol, eax

            invoke SendMessageW, hReplayButtons[14 * SIZEOF DWORD], WM_SETFONT, hFontSegoeUISymbol, TRUE
            invoke SendMessageW, hReplayButtons[15 * SIZEOF DWORD], WM_SETFONT, hFontSegoeUISymbol, TRUE
            invoke SendMessageW, hReplayButtons[16 * SIZEOF DWORD], WM_SETFONT, hFontSegoeUISymbol, TRUE
            invoke SendMessageW, hReplayButtons[17 * SIZEOF DWORD], WM_SETFONT, hFontSegoeUISymbol, TRUE
            invoke SendMessageW, hReplayButtons[18 * SIZEOF DWORD], WM_SETFONT, hFontSegoeUISymbol, TRUE
            invoke SendMessageW, hReplayButtons[19 * SIZEOF DWORD], WM_SETFONT, hFontSegoeUISymbol, TRUE
            invoke SendMessageW, hReplayButtons[20 * SIZEOF DWORD], WM_SETFONT, hFontSegoeUISymbol, TRUE
            invoke SendMessageW, hReplayButtons[21 * SIZEOF DWORD], WM_SETFONT, hFontSegoeUISymbol, TRUE

            push hWnd
            call InitializeReplay

            ret
        .ELSEIF uMsg == WM_COMMAND
            .IF wParam == 500
                call KillTimers
                invoke SetTimer, hWnd, 1, 100, NULL
                ret
            .ELSEIF wParam == 501
                call KillTimers

                .IF animationModeFlag == 1
                    call AnimationBackward
                .ENDIF

                .IF replayModeFlag == 1
                    call ReplayBackwards
                .ENDIF

                ret
            .ELSEIF wParam == 502
                .IF animationModeFlag == 1
                    call KillTimers
                    invoke SetTimer, hWnd, 4, 83, NULL
                .ENDIF

                .IF replayModeFlag == 1
                    call KillTimers
                    invoke SetTimer, hWnd, 2, 300, NULL
                .ENDIF
                ret
            .ELSEIF wParam == 503
                call KillTimers

                .IF animationModeFlag == 1
                    call PauseAnimation
                .ENDIF

                ret
            .ELSEIF wParam == 504
                call KillTimers

                .IF animationModeFlag == 1
                    call AnimationForward
                .ENDIF

                .IF replayModeFlag == 1
                    call ReplayForward
                .ENDIF
                ret
            .ELSEIF wParam == 505
                call KillTimers
                invoke SetTimer, hWnd, 3, 100, NULL
                ret
            .ELSEIF wParam == 506
                call CreateAnimationFrame
                ret
            .ELSEIF wParam == 507
                call RemoveAnimationFrame
                ret
            .ENDIF
        .ELSEIF uMsg == BM_SETCHECK
            push wParam
            ret
        .ELSEIF uMsg == WM_TIMER
            .IF wParam == 1
                .IF animationModeFlag == 1
                    call AnimationBackward
                .ENDIF

                .IF replayModeFlag == 1
                    call ReplayBackwards
                .ENDIF
                
                ret
            .ELSEIF wParam == 2 || wParam == 3 
                .IF animationModeFlag == 1
                    call AnimationForward
                .ENDIF

                .IF replayModeFlag == 1
                    call ReplayForward
                .ENDIF
                ret
            .ELSEIF wParam == 4
                call PlayAnimation
                ret
            .ENDIF
        .ELSEIF uMsg == WM_MOUSEWHEEL           

            cmp wParam, 0
            jg LForward
            jl LBackwards

            LForward:
                .IF animationModeFlag == 1
                    call AnimationForward
                    jmp LEndMessage
                .ENDIF
                
                .IF replayModeFlag == 1
                    call ReplayForward
                .ENDIF

                jmp LEndMessage

            LBackwards:
                .IF animationModeFlag == 1
                    call AnimationBackward
                    jmp LEndMessage
                .ENDIF

                .IF replayModeFlag == 1
                    call ReplayBackwards
                .ENDIF

            LEndMessage:
            ret
            
        .ELSE
            invoke DefWindowProc,hWnd,uMsg,wParam,lParam
            ret
        .ENDIF
        ret
    ReplayWndProc endp
End