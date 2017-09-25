include(CMakeParseArguments)

macro(combine_arguments _variable)
    set(_result "")
    foreach(_element ${${_variable}})
        set(_result "${_result} \"${_element}\"")
    endforeach()
    string(STRIP "${_result}" _result)
    set(${_variable} "${_result}")
endmacro()

function(export_all_flags _filename)
    set(_include_directories "$<TARGET_PROPERTY:${_target},INCLUDE_DIRECTORIES>")
    set(_compile_definitions "$<TARGET_PROPERTY:${_target},COMPILE_DEFINITIONS>")
    set(_compile_flags "$<TARGET_PROPERTY:${_target},COMPILE_FLAGS>")
    set(_compile_options "$<TARGET_PROPERTY:${_target},COMPILE_OPTIONS>")
    set(_include_directories "$<$<BOOL:${_include_directories}>:-I$<JOIN:${_include_directories},\n-I>\n>")
    set(_compile_definitions "$<$<BOOL:${_compile_definitions}>:-D$<JOIN:${_compile_definitions},\n-D>\n>")
    set(_compile_flags "$<$<BOOL:${_compile_flags}>:$<JOIN:${_compile_flags},\n>\n>")
    set(_compile_options "$<$<BOOL:${_compile_options}>:$<JOIN:${_compile_options},\n>\n>")
    #set(_cmake_cxx_flags "$<$<BOOL:${_compile_options}>:$<JOIN:${CMAKE_CXX_FLAGS},\n>\n>")
    string(REPLACE " " "\n" _cmake_cxx_flags ${CMAKE_CXX_FLAGS})
    file(GENERATE OUTPUT "${_filename}" CONTENT "${_compile_definitions}${_include_directories}${_compile_flags}${_compile_options}${_cmake_cxx_flags}\n")
endfunction()

function(add_precompiled_header _target _input)
    cmake_parse_arguments(_PCH "FORCEINCLUDE" "SOURCE_CXX:SOURCE_C" "EXCLUDEFORCED" ${ARGN})

    get_filename_component(_input_we ${_input} NAME_WE)
    if(NOT _PCH_SOURCE_CXX)
        set(_PCH_SOURCE_CXX "${_input_we}.cpp")
    endif()
    if(NOT _PCH_SOURCE_C)
        set(_PCH_SOURCE_C "${_input_we}.c")
    endif()

    if((CMAKE_CXX_COMPILER_ID STREQUAL "GNU") OR (CMAKE_CXX_COMPILER_ID MATCHES ".*Clang"))
        get_filename_component(_name ${_input} NAME)
        set(_pch_header "${CMAKE_CURRENT_SOURCE_DIR}/${_input}")
        set(_pch_binary_dir "${CMAKE_CURRENT_BINARY_DIR}/${_target}_pch")
        set(_pchfile "${_pch_binary_dir}/${_input}")
        set(_outdir "${CMAKE_CURRENT_BINARY_DIR}/${_target}_pch/${_name}.gch")
        make_directory(${_pch_binary_dir})
        make_directory(${_outdir})
        set(_output_cxx "${_outdir}/.c++")
        set(_output_c "${_outdir}/.c")

        set(_pch_flags_file "${_pch_binary_dir}/compile_flags.rsp")
        export_all_flags("${_pch_flags_file}")
        set(_compiler_FLAGS "@${_pch_flags_file}")
        add_custom_command(
            OUTPUT "${_pchfile}"
            COMMAND "${CMAKE_COMMAND}" -E copy "${_pch_header}" "${_pchfile}"
            DEPENDS "${_pch_header}"
            COMMENT "Updating ${_name}")
        add_custom_command(
            OUTPUT "${_output_cxx}"
            COMMAND "${CMAKE_CXX_COMPILER}" ${_compiler_FLAGS} "-I${_pch_binary_dir}" -Winvalid-pch -x c++-header -o "${_output_cxx}" "${_pch_header}"
            IMPLICIT_DEPENDS CXX "${_pch_header}"
            COMMENT "Precompiling ${_name} for ${_target} (C++)")
        add_custom_command(
            OUTPUT "${_output_c}"
            COMMAND "${CMAKE_C_COMPILER}" ${_compiler_FLAGS} "-I${_pch_binary_dir}" -Winvalid-pch -x c-header -o "${_output_c}" "${_pch_header}"
            IMPLICIT_DEPENDS C "${_pch_header}"
            COMMENT "Precompiling ${_name} for ${_target} (C)")

        get_property(_sources TARGET ${_target} PROPERTY SOURCES)
        foreach(_source ${_sources})
            set(_pch_compile_flags "")

            if(_source MATCHES \\.\(cc|cxx|cpp|c\)$)
                get_source_file_property(_pch_compile_flags "${_source}" COMPILE_FLAGS)
                if(NOT _pch_compile_flags)
                    set(_pch_compile_flags)
                endif()
                separate_arguments(_pch_compile_flags)
                list(APPEND _pch_compile_flags -Winvalid-pch)
                list(APPEND _pch_compile_flags "-I${_pch_binary_dir}")

                # add the forced -include option, if requested, and source is
                # not in the exclusion list
                get_filename_component(_source_base ${_source} NAME)
                list(FIND _PCH_EXCLUDEFORCED ${_source_base} _exclude_idx)
                if(_PCH_FORCEINCLUDE AND (_exclude_idx EQUAL -1))
                    list(APPEND _pch_compile_flags -include "${_pchfile}")
                endif(_PCH_FORCEINCLUDE AND (_exclude_idx EQUAL -1))

                get_source_file_property(_object_depends "${_source}" OBJECT_DEPENDS)
                if(NOT _object_depends)
                    set(_object_depends)
                endif()
                list(APPEND _object_depends "${_pchfile}")
                if(_source MATCHES \\.\(cc|cxx|cpp\)$)
                    list(APPEND _object_depends "${_output_cxx}")
                else()
                    list(APPEND _object_depends "${_output_c}")
                endif()

                combine_arguments(_pch_compile_flags)
                set_source_files_properties(${_source} PROPERTIES
                    COMPILE_FLAGS "${_pch_compile_flags}"
                    OBJECT_DEPENDS "${_object_depends}")
            endif()
        endforeach()
    endif((CMAKE_CXX_COMPILER_ID STREQUAL "GNU") OR (CMAKE_CXX_COMPILER_ID MATCHES ".*Clang"))
endfunction()