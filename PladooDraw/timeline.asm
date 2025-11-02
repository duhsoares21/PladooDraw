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
EXTERN SetTimelineScrollPosition:proc
EXTERN GetCurrentFrameIndex:proc
EXTERN GetMaxFrameIndex:proc
EXTERN RenderLayers:proc
EXTERN RenderAnimation:proc
EXTERN AnimationForward:proc
EXTERN SetAnimationFrame:proc
EXTERN AnimationBackward:proc
EXTERN PlayAnimation:proc
EXTERN PauseAnimation:proc
EXTERN ReplayBackwards:proc
EXTERN ReplayForward:proc
EXTERN InitializeTimeline: PROC
EXTERN OnScrollWheelTimeline: PROC
EXTERN CreateAnimationFrame: PROC
EXTERN RemoveAnimationFrame: PROC
EXTERN SetHideShadow: PROC
EXTERN ShowCurrentLayerOnly: PROC

.DATA  

    EXTERN btnWidth:DWORD
    EXTERN btnHeight:DWORD
    EXTERN mainHwnd:HWND
    EXTERN timelineHwnd:HWND
    EXTERN timelineAuxHwnd:HWND
    EXTERN animationModeFlag: DWORD
    EXTERN replayModeFlag: DWORD

    szFontName dw 'S','e','g','o','e',' ','U','I',' ','S','y','m','b','o','l',0

    TimelineClassName db "TimelineClass", 0
    TimelineAppName db "Timeline",0

    TimelineAuxClassName db "TimelineAuxClass", 0
    TimelineAuxAppName db "Animation Aux",0


    szButtonClass dw 'B','U','T','T','O','N', 0
    szAnimationButtonClass db "BUTTON", 0
    szAnimationLabelClass db "STATIC", 0
   
    szButtonRW dw 23EAh, 0
    szButtonStepMinus dw 23EEh, 0
    szButtonPlay dw 23F5h, 0
    szButtonPause dw 23F8h, 0
    szButtonStepPlus dw 23EDh, 0
    szButtonFF dw 23E9h, 0
    szButtonAdd dw 002Bh, 0
    szButtonRemove dw 002Dh, 0

    szButtonCurrentLayer db "Toggle Current Layer Only", 0
    szButtonHideShadow db "Toggle Previous Frame Shadow", 0

    szLabelFrames db "0 of 0 Frames", 0

    formatString db "%d of %d frames", 0
    textBuffer db 64 dup(0)

    screenWidth DWORD 0
    screenHeight DWORD 0

    halfScreenWidth DWORD 0
    centerX DWORD 0

.DATA?
    hFontSegoeUISymbol  HFONT ?

    hTimelineInstance HINSTANCE ?
    hTimelineAuxInstance HINSTANCE ?

    hDefaultCursor HCURSOR ?

    hTimelineButtons HWND ?
    hTimelineAuxButtons HWND ?

.CODE  

    WinTimeline proc hWnd:HWND    
        LOCAL rect:RECT

        LOCAL wc:WNDCLASSEX                                         

        invoke GetModuleHandle, NULL            

        mov hTimelineInstance,eax
        mov wc.hInstance, eax
               
        mov wc.cbSize,SIZEOF WNDCLASSEX                           
        mov wc.style, CS_HREDRAW or CS_VREDRAW
        mov wc.lpfnWndProc, OFFSET TimelineWndProc
                                
        xor eax, eax

        mov wc.hbrBackground,COLOR_BTNFACE+1
        mov wc.lpszMenuName,NULL
        mov wc.lpszClassName,OFFSET TimelineClassName
        
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
        ADDR TimelineClassName,\
        ADDR TimelineAppName,\
        WS_BORDER or WS_CLIPSIBLINGS,\
        centerX,\
        screenHeight,\
        600,\
        220,\
        hWnd,\
        NULL,\
        hTimelineInstance,\
        NULL

        mov timelineHwnd, eax

        invoke ShowWindow,timelineHwnd,SW_HIDE
        invoke UpdateWindow, timelineHwnd
           
        ret
    WinTimeline endp

    KillTimers proc
        invoke KillTimer, timelineHwnd, 1
        invoke KillTimer, timelineHwnd, 2
        invoke KillTimer, timelineHwnd, 3
        invoke KillTimer, timelineHwnd, 4
        ret
    KillTimers endp

    UpdateFrames proc

        call GetCurrentFrameIndex
        mov ebx, eax

        call GetMaxFrameIndex
        mov ecx, eax

        invoke wsprintfA, offset textBuffer, offset formatString,ebx,ecx
        invoke SetWindowText, hTimelineAuxButtons[24 * SIZEOF DWORD], ADDR textBuffer
        ret
    UpdateFrames endp

    TimelineWndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
        LOCAL rect:RECT
        LOCAL parentWidth:DWORD
        LOCAL halfParentWidth:DWORD
        LOCAL CenterX:DWORD

        .IF uMsg == WM_CREATE
        
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

            invoke CreateWindowExW, 0, OFFSET szButtonClass, OFFSET szButtonRemove, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, 145, 50, 24, hWnd, 4507, hTimelineInstance, NULL
            mov hTimelineButtons[14 * SIZEOF DWORD], eax

            xor eax, eax
            mov eax, CenterX
            add eax, 0
            sub eax, 175

            invoke CreateWindowExW, 0, OFFSET szButtonClass, OFFSET szButtonRW, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, 145, 50, 24, hWnd, 4500, hTimelineInstance, NULL
            mov hTimelineButtons[15 * SIZEOF DWORD], eax

            xor eax, eax
            mov eax, CenterX
            add eax, 70
            sub eax, 175

            invoke CreateWindowExW, 0, OFFSET szButtonClass, OFFSET szButtonStepMinus, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, 145, 50, 24, hWnd, 4501, hTimelineInstance, NULL
            mov hTimelineButtons[16 * SIZEOF DWORD], eax

            xor eax, eax
            mov eax, CenterX
            add eax, 140
            sub eax, 175

            invoke CreateWindowExW, 0, OFFSET szButtonClass, OFFSET szButtonPlay, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, 145, 50, 24, hWnd, 4502, hTimelineInstance, NULL
            mov hTimelineButtons[17 * SIZEOF DWORD], eax

            xor eax, eax
            mov eax, CenterX
            add eax, 210
            sub eax, 175

            invoke CreateWindowExW, 0, OFFSET szButtonClass, OFFSET szButtonPause, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, 145, 50, 24, hWnd, 4503, hTimelineInstance, NULL
            mov hTimelineButtons[18 * SIZEOF DWORD], eax

            xor eax, eax
            mov eax, CenterX
            add eax, 280
            sub eax, 175

            invoke CreateWindowExW, 0, OFFSET szButtonClass, OFFSET szButtonStepPlus, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, 145, 50, 24, hWnd, 4504, hTimelineInstance, NULL
            mov hTimelineButtons[19 * SIZEOF DWORD], eax

            xor eax, eax
            mov eax, CenterX
            add eax, 350
            sub eax, 175

            invoke CreateWindowExW, 0, OFFSET szButtonClass, OFFSET szButtonFF, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, 145, 50, 24, hWnd, 4505, hTimelineInstance, NULL
            mov hTimelineButtons[20 * SIZEOF DWORD], eax

            xor eax, eax
            mov eax, CenterX
            add eax, 420
            sub eax, 175

            invoke CreateWindowExW, 0, OFFSET szButtonClass, OFFSET szButtonAdd, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, eax, 145, 50, 24, hWnd, 4506, hTimelineInstance, NULL
            mov hTimelineButtons[21 * SIZEOF DWORD], eax

            invoke CreateFontW, 24, 30, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, \
                    DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, \
                    DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE, \
                    OFFSET szFontName
            mov hFontSegoeUISymbol, eax

            invoke SendMessageW, hTimelineButtons[14 * SIZEOF DWORD], WM_SETFONT, hFontSegoeUISymbol, TRUE
            invoke SendMessageW, hTimelineButtons[15 * SIZEOF DWORD], WM_SETFONT, hFontSegoeUISymbol, TRUE
            invoke SendMessageW, hTimelineButtons[16 * SIZEOF DWORD], WM_SETFONT, hFontSegoeUISymbol, TRUE
            invoke SendMessageW, hTimelineButtons[17 * SIZEOF DWORD], WM_SETFONT, hFontSegoeUISymbol, TRUE
            invoke SendMessageW, hTimelineButtons[18 * SIZEOF DWORD], WM_SETFONT, hFontSegoeUISymbol, TRUE
            invoke SendMessageW, hTimelineButtons[19 * SIZEOF DWORD], WM_SETFONT, hFontSegoeUISymbol, TRUE
            invoke SendMessageW, hTimelineButtons[20 * SIZEOF DWORD], WM_SETFONT, hFontSegoeUISymbol, TRUE
            invoke SendMessageW, hTimelineButtons[21 * SIZEOF DWORD], WM_SETFONT, hFontSegoeUISymbol, TRUE

            push hWnd
            call InitializeTimeline

            ret
        .ELSEIF uMsg == WM_COMMAND
            .IF wParam == 4500
                call KillTimers
                invoke SetTimer, hWnd, 1, 100, NULL
                ret
            .ELSEIF wParam == 4501
                call KillTimers

                .IF animationModeFlag == 1
                    call AnimationBackward
                    call UpdateFrames
                .ENDIF

                .IF replayModeFlag == 1
                    call ReplayBackwards
                .ENDIF

                ret
            .ELSEIF wParam == 4502
                .IF animationModeFlag == 1
                    call KillTimers
                    invoke SetTimer, hWnd, 4, 83, NULL
                .ENDIF

                .IF replayModeFlag == 1
                    call KillTimers
                    invoke SetTimer, hWnd, 2, 300, NULL
                .ENDIF
                ret
            .ELSEIF wParam == 4503
                call KillTimers

                .IF animationModeFlag == 1
                    call PauseAnimation
                .ENDIF

                ret
            .ELSEIF wParam == 4504
                call KillTimers

                .IF animationModeFlag == 1
                    call AnimationForward
                    call UpdateFrames
                .ENDIF

                .IF replayModeFlag == 1
                    call ReplayForward
                .ENDIF
                ret
            .ELSEIF wParam == 4505
                call KillTimers
                invoke SetTimer, hWnd, 3, 100, NULL
                ret
            .ELSEIF wParam == 4506
                call CreateAnimationFrame
                call UpdateFrames
                ret
            .ELSEIF wParam == 4507
                call RemoveAnimationFrame
                call UpdateFrames
                ret
            .ELSEIF wParam >= 0 && wParam <= 1000
                push wParam
                call SetAnimationFrame

                push wParam
                call SetTimelineScrollPosition

                call RenderLayers
                call RenderAnimation

                call UpdateFrames
            .ENDIF
        .ELSEIF uMsg == BM_SETCHECK
            push wParam
            ret
        .ELSEIF uMsg == WM_TIMER
            .IF wParam == 1
                .IF animationModeFlag == 1
                    call AnimationBackward
                    call UpdateFrames
                .ENDIF

                .IF replayModeFlag == 1
                    call ReplayBackwards
                .ENDIF
                
                ret
            .ELSEIF wParam == 2 || wParam == 3 
                .IF animationModeFlag == 1
                    call AnimationForward
                    call UpdateFrames
                .ENDIF

                .IF replayModeFlag == 1
                    call ReplayForward
                .ENDIF
                ret
            .ELSEIF wParam == 4
                call PlayAnimation
                call UpdateFrames
                ret
            .ENDIF
        .ELSEIF uMsg == WM_MOUSEWHEEL           

            cmp wParam, 0
            jg LForward
            jl LBackwards

            LForward:
                .IF animationModeFlag == 1
                    call AnimationForward
                    call UpdateFrames
                    jmp LEndMessage
                .ENDIF
                
                .IF replayModeFlag == 1
                    call ReplayForward
                .ENDIF

                jmp LEndMessage

            LBackwards:
                .IF animationModeFlag == 1
                    call AnimationBackward
                    call UpdateFrames
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
    TimelineWndProc endp

    WinTimelineAux proc hWnd:HWND
        LOCAL rect:RECT

        LOCAL wc:WNDCLASSEX

        invoke GetModuleHandle, NULL

        mov hTimelineAuxInstance,eax
        mov wc.hInstance, eax

        mov wc.cbSize,SIZEOF WNDCLASSEX
        mov wc.style, CS_HREDRAW or CS_VREDRAW
        mov wc.lpfnWndProc, OFFSET TimelineAuxWndProc

        xor eax, eax

        mov wc.hbrBackground,COLOR_BTNFACE+1
        mov wc.lpszMenuName,NULL
        mov wc.lpszClassName,OFFSET TimelineAuxClassName

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
        mov ecx, 600
        sub eax, ecx

        mov centerX, eax

        invoke CreateWindowEx,
        NULL,\
        ADDR TimelineAuxClassName,\
        ADDR TimelineAuxAppName,\
        WS_BORDER or WS_CLIPSIBLINGS,\
        centerX,\
        screenHeight,\
        300,\
        220,\
        hWnd,\
        NULL,\
        hTimelineAuxInstance,\
        NULL

        mov timelineAuxHwnd, eax

        invoke ShowWindow,timelineAuxHwnd,SW_HIDE
        invoke UpdateWindow, timelineAuxHwnd

        ret
    WinTimelineAux endp

    TimelineAuxWndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
        .IF uMsg == WM_CREATE
            invoke CreateWindowEx, 0, OFFSET szAnimationButtonClass, OFFSET szButtonCurrentLayer, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 30, 30, 220, 30, hWnd, 4508, hTimelineInstance, NULL
            mov hTimelineAuxButtons[22 * SIZEOF DWORD], eax

            invoke CreateWindowEx, 0, OFFSET szAnimationButtonClass, OFFSET szButtonHideShadow, WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, 30, 70, 220, 30, hWnd, 4509, hTimelineInstance, NULL
            mov hTimelineAuxButtons[23 * SIZEOF DWORD], eax

            invoke CreateWindowEx, 0, OFFSET szAnimationLabelClass, OFFSET szLabelFrames, WS_CHILD or WS_VISIBLE or SS_CENTER, 30, 110, 220, 30, hWnd, 4510, hTimelineInstance, NULL
            mov hTimelineAuxButtons[24 * SIZEOF DWORD], eax

            ret
        .ELSEIF uMsg == WM_COMMAND
            .IF wParam == 4508
                call ShowCurrentLayerOnly
                ret
            .ELSEIF wParam == 4509
                call SetHideShadow
                ret
            .ENDIF
            ret
        .ELSE
            invoke DefWindowProc,hWnd,uMsg,wParam,lParam
            ret
        .ENDIF
    TimelineAuxWndProc endp
End