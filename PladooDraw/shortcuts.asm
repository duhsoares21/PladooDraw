.MODEL flat, stdcall

include \masm32\include\windows.inc
include \masm32\include\user32.inc

includelib PladooDraw_Direct2D_LayerSystem.lib

.DATA 
	EXTERN brushSize:DWORD
	EXTERN selectedTool:DWORD	
	EXTERN Undo:proc
	EXTERN Redo:proc
	EXTERN ReorderLayerUp:proc
	EXTERN ReorderLayerDown:proc
	EXTERN RenderLayers:proc
	EXTERN UpdateLayers:proc

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

		cmp al, VK_Z
		je LUndo

		cmp al, VK_J
		je LRedo

		cmp al, VK_UP
		je LOrderUp

		cmp al, VK_DOWN
		je LOrderDown

		jmp END_PROC

		ApplyDecrease :
				dec DWORD PTR [brushSize]
				jmp END_PROC

		Increase :
			inc DWORD PTR [brushSize]
			jmp END_PROC

		Decrease :
			cmp DWORD PTR [brushSize], 1
			jg ApplyDecrease
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

		LUndo: 
			call Undo
			;call UpdateLayers
			jmp END_PROC

		LRedo: 
			call Redo
			;call UpdateLayers
			jmp END_PROC

		LOrderUp:
			call ReorderLayerUp
			call RenderLayers
			jmp END_PROC

		LOrderDown:
			call ReorderLayerDown
			call RenderLayers
			jmp END_PROC

		END_PROC: 
			ret

	Shortcuts endp

END
