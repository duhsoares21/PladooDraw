.MODEL flat, stdcall

include \masm32\include\windows.inc
include \masm32\include\user32.inc

.DATA 
	EXTERN brushSize:DWORD
	EXTERN selectedTool:DWORD	

.CODE
	Shortcuts Proc hWnd:HWND, wParam:WPARAM
		
		mov al, byte ptr[wParam]

		cmp al, VK_ADD
		je Increase

		cmp al, VK_OEM_PLUS
		je Increase

		cmp al, VK_OEM_MINUS
		je Decrease

		cmp al, VK_SUBTRACT
		je Decrease

		cmp al, VK_B
		je BrushTool
		
		cmp al, VK_R
		je RectangleTool

		cmp al, VK_C
		je EllipseTool

		cmp al, VK_L
		je LineTool

		cmp al, VK_F
		je BucketTool

		cmp al, VK_E
		je Eraser

		jmp END_PROC

		Increase :
			inc DWORD PTR [brushSize]
			jmp END_PROC

		Decrease :
			dec DWORD PTR [brushSize]
			jmp END_PROC

		Eraser :
			mov DWORD PTR [selectedTool], 0
			jmp END_PROC

		BrushTool:
			mov DWORD PTR [selectedTool], 1
			jmp END_PROC

		RectangleTool:
			mov DWORD PTR [selectedTool], 2
			jmp END_PROC
		
		EllipseTool:
			mov DWORD PTR [selectedTool], 3
			jmp END_PROC

		LineTool:
			mov DWORD PTR [selectedTool], 4
			jmp END_PROC

		BucketTool:
			mov DWORD PTR [selectedTool], 5
			jmp END_PROC

		END_PROC: 
			ret

	Shortcuts endp

END
