# CMakeLists.txt para o projeto Assembly (PladooDraw)

set(MASM_EXE "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/14.44.35207/bin/Hostx86/x86/ml.exe")

file(GLOB ASM_SOURCES "*.asm")

set(ASM_OBJECTS "")
foreach(asm_file ${ASM_SOURCES})
    get_filename_component(asm_name ${asm_file} NAME_WE)
    set(obj_file "${CMAKE_BINARY_DIR}/${asm_name}.obj")
    list(APPEND ASM_OBJECTS ${obj_file})

    add_custom_command(
        OUTPUT ${obj_file}
        COMMAND "${MASM_EXE}" /c /nologo /Zi /Fo${obj_file} /Cp /W3 /errorReport:prompt /Ta ${asm_file}
        DEPENDS ${asm_file}
        COMMENT "🔧 Compilando ${asm_name}.asm"
    )
endforeach()

add_custom_target(PladooDraw_ASM ALL DEPENDS ${ASM_OBJECTS})
