cmake_minimum_required(VERSION 3.14...3.31 FATAL_ERROR)

# # Required...
if(NOT DEFINED ENV{RACK_DIR} AND NOT DEFINED RACK_DIR)
    message(FATAL_ERROR "You need to set $RACK_DIR")
endif()

# # Take RACK_DIR from env, if not passed as -DRACK_DIR=...
if(DEFINED ENV{RACK_DIR} AND NOT DEFINED RACK_DIR)
    set(RACK_DIR "$ENV{RACK_DIR}" CACHE STRING "" FORCE)
endif()

set(PROJECT_VENDOR "VCV" CACHE STRING "" FORCE) # UNOFFICIAL!
set(RACK_SDK_VERSION_MAJOR 2 CACHE STRING "" FORCE)
set(RACK_SDK_VERSION_MINOR 5 CACHE STRING "" FORCE)
set(RACK_SDK_VERSION_PATCH 2 CACHE STRING "" FORCE)
set(RACK_SDK_LANGUAGES "C" "CXX" CACHE STRING "" FORCE)

set(RACK_VERSION ${RACK_SDK_VERSION_MAJOR}.${RACK_SDK_VERSION_MINOR}.${RACK_SDK_VERSION_PATCH})

include(CMakeDependentOption)

option(CPACK_STRIP_FILES "" ON)
option(CPACK_SOURCE_STRIP_FILES "" ON)

option(RACK_SDK_DISABLE_USAGE_MESSAGE "" OFF)
option(RACK_SDK_INSTALL_DEPS "" ON)
cmake_dependent_option(RACK_SDK_INSTALL_CORE "" ON "RACK_SDK_INSTALL_DEPS" ON)
cmake_dependent_option(RACK_SDK_INSTALL_LIB "" ON "RACK_SDK_INSTALL_CORE" ON)
cmake_dependent_option(RACK_SDK_INSTALL_RUNTIME_LIBS "" OFF "RACK_SDK_INSTALL_LIB" ON)

project(RACK_SDK
    VERSION ${RACK_VERSION}
    LANGUAGES ${RACK_SDK_LANGUAGES}
)

# Not known until first "project()..."
if(WIN32 AND NOT MINGW)
    message(FATAL_ERROR [==[
VCV Rack for Windows requires MSYS2 with the MinGW64 toolchain and shell....
]==])
endif()

include(GNUInstallDirs)
set(RACK_SDK_TARGETS)

if(RACK_SDK_INSTALL_DEPS)
    #[==[Rack SDK Deps]==]
    add_library(dep INTERFACE)
    add_library(rack-sdk::dep ALIAS dep)
    add_library(unofficial-vcvrack::rack-sdk::dep ALIAS dep)

    target_compile_features(dep INTERFACE cxx_std_11)
    target_compile_features(dep INTERFACE c_std_11)

    set_target_properties(dep
        PROPERTIES
        VERSION "${RACK_SDK_VERSION_MAJOR}.${RACK_SDK_VERSION_MINOR}.${RACK_SDK_VERSION_PATCH}"
        SOVERSION "${RACK_SDK_VERSION_MAJOR}.${RACK_SDK_VERSION_MINOR}.${RACK_SDK_VERSION_PATCH}"

        EXPORT_NO_SYSTEM TRUE
        SYSTEM FALSE

        RUNTIME_OUTPUT_DIRECTORY "bin"
        LIBRARY_OUTPUT_DIRECTORY "lib"
        ARCHIVE_OUTPUT_DIRECTORY "lib"
        PDB_OUTPUT_DIRECTORY "bin"

        # Compatible Interface
        INTERFACE_dep_MAJOR_VERSION "${RACK_SDK_VERSION_MAJOR}"
        INTERFACE_dep_MINOR_VERSION "${RACK_SDK_VERSION_MINOR}"
        INTERFACE_dep_PATCH_VERSION "${RACK_SDK_VERSION_PATCH}"
    )
    set_property(TARGET dep APPEND PROPERTY
        COMPATIBLE_INTERFACE_STRING INTERFACE_dep_MAJOR_VERSION
    )
    set_property(TARGET dep APPEND PROPERTY
        COMPATIBLE_INTERFACE_STRING INTERFACE_dep_MINOR_VERSION
    )
    set_property(TARGET dep APPEND PROPERTY
        COMPATIBLE_INTERFACE_STRING INTERFACE_dep_PATCH_VERSION
    )

    set(__rack_dep_headers_glob "")
    file(GLOB_RECURSE __rack_dep_headers_glob CONFIGURE_DEPENDS "${RACK_DIR}/dep/*.h*")

    # This contains all the VCV Rack library headers... globs are a bit unsafe
    # though, so...
    message(DEBUG "${__rack_dep_headers_glob}")

    # Let's make a FILE_SET which we can export
    foreach(__rack_dep_header IN LISTS __rack_dep_headers_glob)

        get_filename_component(abs_path_to_file "${__rack_dep_header}" ABSOLUTE)
        get_filename_component(name_of_file "${abs_path_to_file}" NAME)
        file(RELATIVE_PATH rel_path_to_file "${RACK_DIR}/dep/include" "${abs_path_to_file}") # dep/include/somedep/someheader.hpp

        configure_file(
            "${RACK_DIR}/dep/include/${rel_path_to_file}"
            "include/Rack-SDK/dep/${rel_path_to_file}"
            @ONLY
        )

        unset(abs_path_to_file)
        unset(name_of_file)
        unset(rel_path_to_file)

    endforeach()

    unset(__rack_dep_headers_glob)
    file(GLOB_RECURSE __rack_dep_headers_glob CONFIGURE_DEPENDS "${PROJECT_BINARY_DIR}/include/Rack-SDK/dep/*.h*")

    foreach(__rack_dep_header IN LISTS __rack_dep_headers_glob)

        get_filename_component(abs_path_to_file "${__rack_dep_header}" ABSOLUTE)
        get_filename_component(name_of_file "${__rack_dep_header}" NAME)
        file(RELATIVE_PATH rel_path_to_file "${PROJECT_BINARY_DIR}" "${abs_path_to_file}")
        get_filename_component(name_of_file_dir "${rel_path_to_file}" DIRECTORY)

        message(DEBUG "")
        message(DEBUG "name_of_file: ${name_of_file}")          # "someheader.hpp"
        message(DEBUG "name_of_file_dir: ${name_of_file_dir}")  # "include/Rack-SDK/dep/somedep"
        message(DEBUG "abs_path_to_file: ${abs_path_to_file}")  # "C:/..." or "/home/.../
        message(DEBUG "rel_path_to_file: ${rel_path_to_file}")  # "include/Rack-SDK/dep/somedep/someheader.hpp"
        message(DEBUG "")

        target_sources(dep INTERFACE
            FILE_SET rack_DEP_INTERFACE_HEADERS
            TYPE HEADERS
            BASE_DIRS
            $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include/Rack-SDK/dep>
            $<INSTALL_INTERFACE:include/Rack-SDK/dep>
            FILES
            $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/${rel_path_to_file}>
            $<INSTALL_INTERFACE:${rel_path_to_file}>
        )

        unset(abs_path_to_file)
        unset(name_of_file)
        unset(rel_path_to_file)
        unset(name_of_file_dir)

    endforeach()

    target_compile_options(dep
        INTERFACE
        "-fPIC"
    )

    # install the target and create export-set
    install(TARGETS dep
        EXPORT DepExport
        COMPONENT dep
        LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
        INCLUDES DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
        FILE_SET rack_DEP_INTERFACE_HEADERS DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/Rack-SDK/dep"
    )

    # generate and install export file
    install(EXPORT DepExport
        FILE "rack-sdk-dep-targets.cmake"
        NAMESPACE unofficial-vcvrack::rack-sdk::
        DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/Rack-SDK"
    )

    export(SETUP DepExport)
    export(
        EXPORT DepExport
        FILE "${CMAKE_CURRENT_BINARY_DIR}/lib/cmake/Rack-SDK/rack-sdk-dep-targets.cmake"
        NAMESPACE unofficial-vcvrack::rack-sdk::
    )

    list(APPEND RACK_SDK_TARGETS dep)

endif(RACK_SDK_INSTALL_DEPS)


if(RACK_SDK_INSTALL_CORE)
    # Install misc. files
    configure_file("${RACK_DIR}/helper.py"              "share/Rack-SDK/helper.py"          @ONLY)
    configure_file("${RACK_DIR}/LICENSE-dist.html"      "share/Rack-SDK/LICENSE-dist.html"  @ONLY)
    configure_file("${RACK_DIR}/LICENSE.html"           "share/Rack-SDK/LICENSE.html"       @ONLY)
    configure_file("${RACK_DIR}/README.html"            "share/Rack-SDK/README.html"        @ONLY)
    configure_file("${RACK_DIR}/CHANGELOG.html"         "share/Rack-SDK/CHANGELOG.html"     @ONLY)
    configure_file("${RACK_DIR}/arch.mk"                "share/Rack-SDK/arch.mk"            @ONLY)
    configure_file("${RACK_DIR}/compile.mk"             "share/Rack-SDK/compile.mk"         @ONLY)
    configure_file("${RACK_DIR}/dep.mk"                 "share/Rack-SDK/dep.mk"             @ONLY)
    configure_file("${RACK_DIR}/plugin.mk"              "share/Rack-SDK/plugin.mk"          @ONLY)
    install(
        FILES
            "${CMAKE_CURRENT_BINARY_DIR}/share/Rack-SDK/helper.py"
            "${CMAKE_CURRENT_BINARY_DIR}/share/Rack-SDK/LICENSE-dist.html"
            "${CMAKE_CURRENT_BINARY_DIR}/share/Rack-SDK/LICENSE.html"
            "${CMAKE_CURRENT_BINARY_DIR}/share/Rack-SDK/README.html"
            "${CMAKE_CURRENT_BINARY_DIR}/share/Rack-SDK/CHANGELOG.html"
            "${CMAKE_CURRENT_BINARY_DIR}/share/Rack-SDK/arch.mk"
            "${CMAKE_CURRENT_BINARY_DIR}/share/Rack-SDK/compile.mk"
            "${CMAKE_CURRENT_BINARY_DIR}/share/Rack-SDK/dep.mk"
            "${CMAKE_CURRENT_BINARY_DIR}/share/Rack-SDK/plugin.mk"
        DESTINATION
            "${CMAKE_INSTALL_DATADIR}/Rack-SDK"
    )

    #[==[Rack SDK]==]
    add_library(core INTERFACE)
    add_library(rack-sdk::core ALIAS core)
    add_library(unofficial-vcvrack::rack-sdk::core ALIAS core)

    target_compile_features(core INTERFACE cxx_std_11)
    target_compile_features(core INTERFACE c_std_11)

    set_target_properties(core
        PROPERTIES
        VERSION "${RACK_SDK_VERSION_MAJOR}.${RACK_SDK_VERSION_MINOR}.${RACK_SDK_VERSION_PATCH}"
        SOVERSION "${RACK_SDK_VERSION_MAJOR}.${RACK_SDK_VERSION_MINOR}.${RACK_SDK_VERSION_PATCH}"

        EXPORT_NO_SYSTEM TRUE
        SYSTEM FALSE

        RUNTIME_OUTPUT_DIRECTORY "bin"
        LIBRARY_OUTPUT_DIRECTORY "lib"
        ARCHIVE_OUTPUT_DIRECTORY "lib"
        PDB_OUTPUT_DIRECTORY "bin"

        # Compatible Interface
        INTERFACE_core_MAJOR_VERSION "${RACK_SDK_VERSION_MAJOR}"
        INTERFACE_core_MINOR_VERSION "${RACK_SDK_VERSION_MINOR}"
        INTERFACE_core_PATCH_VERSION "${RACK_SDK_VERSION_PATCH}"
    )
    set_property(TARGET core APPEND PROPERTY
        COMPATIBLE_INTERFACE_STRING INTERFACE_core_MAJOR_VERSION
    )
    set_property(TARGET core APPEND PROPERTY
        COMPATIBLE_INTERFACE_STRING INTERFACE_core_MINOR_VERSION
    )
    set_property(TARGET core APPEND PROPERTY
        COMPATIBLE_INTERFACE_STRING INTERFACE_core_PATCH_VERSION
    )

    set(__rack_sdk_headers_glob "")
    file(GLOB_RECURSE __rack_sdk_headers_glob CONFIGURE_DEPENDS "${RACK_DIR}/include/*.h*")

    # This contains all the VCV Rack library headers... globs are a bit unsafe
    # though, so...
    message(DEBUG "${__rack_sdk_headers_glob}")

    # Let's make a FILE_SET which we can export
    foreach(__rack_sdk_header IN LISTS __rack_sdk_headers_glob)

        get_filename_component(abs_path_to_file "${__rack_sdk_header}" ABSOLUTE)
        get_filename_component(name_of_file "${abs_path_to_file}" NAME)
        file(RELATIVE_PATH rel_path_to_file "${RACK_DIR}/include" "${abs_path_to_file}")

        configure_file(
            "${RACK_DIR}/include/${rel_path_to_file}"
            "include/Rack-SDK/rack/${rel_path_to_file}"
            @ONLY
        )

        unset(abs_path_to_file)
        unset(name_of_file)
        unset(rel_path_to_file)

    endforeach()

    unset(__rack_sdk_headers_glob)
    file(GLOB_RECURSE __rack_sdk_headers_glob CONFIGURE_DEPENDS "${PROJECT_BINARY_DIR}/include/Rack-SDK/rack/*.h*")

    foreach(__rack_sdk_header IN LISTS __rack_sdk_headers_glob)

        get_filename_component(abs_path_to_file "${__rack_sdk_header}" ABSOLUTE)
        get_filename_component(name_of_file "${__rack_dep_header}" NAME)
        file(RELATIVE_PATH rel_path_to_file "${PROJECT_BINARY_DIR}" "${abs_path_to_file}")
        get_filename_component(name_of_file_dir "${rel_path_to_file}" DIRECTORY)

        message(DEBUG "")
        message(DEBUG "name_of_file: ${name_of_file}")          # "someheader.hpp"
        message(DEBUG "name_of_file_dir: ${name_of_file_dir}")  # "include/Rack-SDK/rack/someobject"
        message(DEBUG "abs_path_to_file: ${abs_path_to_file}")  # "C:/..." or "/home/.../
        message(DEBUG "rel_path_to_file: ${rel_path_to_file}")  # "include/Rack-SDK/rack/someobject/someheader.hpp"
        message(DEBUG "")

        target_sources(core INTERFACE
            FILE_SET rack_sdk_CORE_INTERFACE_HEADERS
            TYPE HEADERS
            BASE_DIRS
            $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include/Rack-SDK/rack>
            $<INSTALL_INTERFACE:include/Rack-SDK/rack>
            FILES
            $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/${rel_path_to_file}>
            $<INSTALL_INTERFACE:${rel_path_to_file}>
        )

        unset(abs_path_to_file)
        unset(name_of_file)
        unset(rel_path_to_file)
        unset(name_of_file_dir)

    endforeach()

    target_compile_options(core
        INTERFACE
        "-fPIC"
    )
    target_link_libraries(core
        INTERFACE
        unofficial-vcvrack::rack-sdk::dep
    )

    # install the target and create export-set
    install(TARGETS core
        EXPORT CoreExport
        COMPONENT core
        LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
        INCLUDES DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
        FILE_SET rack_sdk_CORE_INTERFACE_HEADERS DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/Rack-SDK/rack"
        OPTIONAL
    )

    # generate and install export file
    install(EXPORT CoreExport
        FILE "rack-sdk-core-targets.cmake"
        NAMESPACE unofficial-vcvrack::rack-sdk::
        DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/Rack-SDK"
    )

    export(SETUP CoreExport)
    export(
        EXPORT CoreExport
        FILE "lib/cmake/Rack-SDK/rack-sdk-core-targets.cmake"
        NAMESPACE unofficial-vcvrack::rack-sdk::
    )

    list(APPEND RACK_SDK_TARGETS core)

    # ## Intellisense helper...
    # add_library(rack-sdk INTERFACE)
    # add_library(unofficial-vcvrack::rack-sdk ALIAS rack-sdk)

    # configure_file("include/rack.hpp" "include/rack.hpp")
    # target_sources(rack-sdk INTERFACE
    #     FILE_SET rack_sdk_INTERFACE_HEADERS
    #     TYPE HEADERS
    #     BASE_DIRS
    #     $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
    #     $<INSTALL_INTERFACE:include>
    #     FILES
    #     $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include/rack.hpp>
    #     $<INSTALL_INTERFACE:include/rack.hpp>
    # )
    # target_compile_options(rack-sdk
    #     INTERFACE
    #         "-fPIC"
    # )
    # target_link_libraries(rack-sdk
    #     INTERFACE
    #         unofficial-vcvrack::rack-sdk::core
    # )

    # # install the target and create export-set
    # install(TARGETS rack-sdk
    #     EXPORT RackSDKExport
    #     COMPONENT RackSDK
    #     LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    #     ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    #     RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
    #     INCLUDES DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
    #     FILE_SET rack_sdk_INTERFACE_HEADERS DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
    # )

    # # generate and install export file
    # install(EXPORT RackSDKExport
    #     FILE "rack-sdk-targets.cmake"
    #     NAMESPACE unofficial-vcvrack::
    #     DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/Rack-SDK"
    # )

    # export(SETUP RackSDKExport)
    # export(
    #     EXPORT RackSDKExport
    #     FILE "lib/cmake/Rack-SDK/rack-sdk-targets.cmake"
    #     NAMESPACE unofficial-vcvrack::
    # )

endif(RACK_SDK_INSTALL_CORE)

if(RACK_SDK_INSTALL_LIB)

    #[==[Rack Library]==]
    add_library(lib SHARED IMPORTED GLOBAL)
    add_library(rack-sdk::lib ALIAS lib)
    add_library(unofficial-vcvrack::rack-sdk::lib ALIAS lib)

    target_compile_features(lib INTERFACE cxx_std_11)
    target_compile_features(lib INTERFACE c_std_11)

    set(RACK_SDK_LIB_FILE_EXTENSION)
    set(RACK_SDK_LIB_FILE_DESTINATION)
    set(RACK_SDK_LIB_INSTALL_DIR)

    if(APPLE)
        set(RACK_SDK_LIB_FILE_EXTENSION ".dylib")
    elseif(UNIX AND NOT APPLE) # Linux
        set(RACK_SDK_LIB_FILE_EXTENSION ".so")
    endif()

    if(MINGW)
        set(RACK_SDK_LIB_FILE_EXTENSION ".dll.a")
        set(RACK_SDK_LIB_FILE_DESTINATION "bin")
        set(RACK_SDK_LIB_INSTALL_DIR "${CMAKE_INSTALL_BINDIR}")
    else()
        set(RACK_SDK_LIB_FILE_DESTINATION "lib")
        set(RACK_SDK_LIB_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}")
    endif()

    set(RACK_SDK_DLL_IMPORTED_LOCATION)

    if(WIN32)
        cmake_path(CONVERT "$ENV{ProgramFiles}\\VCV\\Rack2Free" TO_CMAKE_PATH_LIST dll_dir)
        set(RACK_SDK_DLL_IMPORTED_LOCATION "${dll_dir}/libRack.dll")
    else()
        set(dll_dir "${RACK_DIR}")
        set(RACK_SDK_DLL_IMPORTED_LOCATION "${dll_dir}/libRack${RACK_SDK_LIB_FILE_EXTENSION}")
    endif()

    set_target_properties(lib
        PROPERTIES
        VERSION "${RACK_SDK_VERSION_MAJOR}.${RACK_SDK_VERSION_MINOR}.${RACK_SDK_VERSION_PATCH}"
        SOVERSION "${RACK_SDK_VERSION_MAJOR}"

        ENABLE_EXPORTS TRUE
        EXPORT_NO_SYSTEM TRUE
        SYSTEM FALSE

        INTERFACE_COMPILE_FEATURES "cxx_std_11;c_std_11"
        INTERFACE_COMPILE_OPTIONS "-fPIC"
        INTERFACE_LINK_DIRECTORIES "${RACK_SDK_LIB_INSTALL_DIR}"
        INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_INSTALL_INCLUDEDIR}"

        IMPORTED_LOCATION "${RACK_SDK_DLL_IMPORTED_LOCATION}"
        IMPORTED_IMPLIB "${RACK_DIR}/libRack${RACK_SDK_LIB_FILE_EXTENSION}"
        IMPORTED_NO_SONAME TRUE

        # Compatible Interface
        INTERFACE_lib_MAJOR_VERSION "${RACK_SDK_VERSION_MAJOR}"
        INTERFACE_lib_MINOR_VERSION "${RACK_SDK_VERSION_MINOR}"
        INTERFACE_lib_PATCH_VERSION "${RACK_SDK_VERSION_PATCH}"
    )
    set_property(TARGET lib APPEND PROPERTY
        COMPATIBLE_INTERFACE_STRING INTERFACE_lib_MAJOR_VERSION
    )
    set_property(TARGET lib APPEND PROPERTY
        COMPATIBLE_INTERFACE_STRING INTERFACE_lib_MINOR_VERSION
    )
    set_property(TARGET lib APPEND PROPERTY
        COMPATIBLE_INTERFACE_STRING INTERFACE_lib_PATCH_VERSION
    )

    if(WIN32)
        install(
            FILES "${RACK_DIR}/libRack${RACK_SDK_LIB_FILE_EXTENSION}"
            DESTINATION "${RACK_SDK_LIB_INSTALL_DIR}"
        )
    endif()
    target_compile_options(lib
        INTERFACE
        "-fPIC"
    )

    # set_property(TARGET lib APPEND PROPERTY
    # INTERFACE_LINK_OPTIONS "-fPIC"
    # )
    # set_property(TARGET lib APPEND PROPERTY
    # INTERFACE_LINK_OPTIONS "-shared"
    # )

    target_link_libraries(lib
        INTERFACE
        unofficial-vcvrack::rack-sdk::core
    )

    install(
        IMPORTED_RUNTIME_ARTIFACTS lib
        RUNTIME_DEPENDENCY_SET LibExports
        COMPONENT lib
        LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
        RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
        OPTIONAL
    )

    if(RACK_SDK_INSTALL_RUNTIME_LIBS)
        # Installs/symlinks lots of system libs... be warned
        install(
            RUNTIME_DEPENDENCY_SET LibExports
            COMPONENT runtimes
            LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
            RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
            EXCLUDE_FROM_ALL
            OPTIONAL
        )
    endif()

    # The below codeblob is a big multi-line string (not a comment!) which writes
    # information about the `lib` target to a file...
    file(CONFIGURE OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/lib/cmake/Rack-SDK/rack-sdk-lib-targets.cmake" CONTENT [==[
if("${CMAKE_MAJOR_VERSION}.${CMAKE_MINOR_VERSION}" LESS 2.8)
    message(FATAL_ERROR "CMake >= 2.8.0 required")
endif()

if(CMAKE_VERSION VERSION_LESS "3.0.0")
    message(FATAL_ERROR "CMake >= 3.0.0 required")
endif()

cmake_policy(PUSH)
cmake_policy(VERSION 3.0.0...3.28)

# ----------------------------------------------------------------
# Generated CMake target import file.
# ----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Protect against multiple inclusion, which would fail when already imported targets are added once more.
set(_cmake_targets_defined "")
set(_cmake_targets_not_defined "")
set(_cmake_expected_targets "")

foreach(_cmake_expected_target IN ITEMS unofficial-vcvrack::rack-sdk::lib)
    list(APPEND _cmake_expected_targets "${_cmake_expected_target}")

    if(TARGET "${_cmake_expected_target}")
        list(APPEND _cmake_targets_defined "${_cmake_expected_target}")
    else()
        list(APPEND _cmake_targets_not_defined "${_cmake_expected_target}")
    endif()
endforeach()

unset(_cmake_expected_target)

if(_cmake_targets_defined STREQUAL _cmake_expected_targets)
    unset(_cmake_targets_defined)
    unset(_cmake_targets_not_defined)
    unset(_cmake_expected_targets)
    unset(CMAKE_IMPORT_FILE_VERSION)
    cmake_policy(POP)
    return()
endif()

if(NOT _cmake_targets_defined STREQUAL "")
    string(REPLACE ";" ", " _cmake_targets_defined_text "${_cmake_targets_defined}")
    string(REPLACE ";" ", " _cmake_targets_not_defined_text "${_cmake_targets_not_defined}")
    message(FATAL_ERROR "Some (but not all) targets in this export set were already defined.\nTargets Defined: ${_cmake_targets_defined_text}\nTargets not yet defined: ${_cmake_targets_not_defined_text}\n")
endif()

unset(_cmake_targets_defined)
unset(_cmake_targets_not_defined)
unset(_cmake_expected_targets)

# Compute the installation prefix relative to this file.
get_filename_component(_IMPORT_PREFIX "${CMAKE_CURRENT_LIST_FILE}" PATH)
get_filename_component(_IMPORT_PREFIX "${_IMPORT_PREFIX}" PATH)
get_filename_component(_IMPORT_PREFIX "${_IMPORT_PREFIX}" PATH)
get_filename_component(_IMPORT_PREFIX "${_IMPORT_PREFIX}" PATH)
if(_IMPORT_PREFIX STREQUAL "/")
  set(_IMPORT_PREFIX "")
endif()

set(RACK_SDK_LIB_FILE_EXTENSION)

if(APPLE)
    set(RACK_SDK_LIB_FILE_EXTENSION ".dylib")
elseif(UNIX AND NOT APPLE) # Linux
    set(RACK_SDK_LIB_FILE_EXTENSION ".so")
endif()

if(MINGW)
    set(RACK_SDK_LIB_FILE_EXTENSION ".dll.a")
endif()

if(WIN32)
    cmake_path(CONVERT "$ENV{ProgramFiles}\\VCV\\Rack2Free" TO_CMAKE_PATH_LIST dll_dir)
    set_and_check(RACK_SDK_DLL_IMPORTED_LOCATION "${dll_dir}/libRack.dll")
else()
    set_and_check(RACK_SDK_DLL_IMPORTED_LOCATION "${_IMPORT_PREFIX}/lib/libRack${RACK_SDK_LIB_FILE_EXTENSION}")
endif()

# Create imported target unofficial-vcvrack::rack-sdk::lib
add_library(unofficial-vcvrack::rack-sdk::lib SHARED IMPORTED GLOBAL)

set_target_properties(unofficial-vcvrack::rack-sdk::lib PROPERTIES
    VERSION "@RACK_SDK_VERSION_MAJOR@.@RACK_SDK_VERSION_MINOR@.@RACK_SDK_VERSION_PATCH@"
    SOVERSION "@RACK_SDK_VERSION_MAJOR@.@RACK_SDK_VERSION_MINOR@.@RACK_SDK_VERSION_PATCH@"
    ENABLE_EXPORTS TRUE
    EXPORT_NO_SYSTEM TRUE
    SYSTEM FALSE
    INTERFACE_COMPILE_FEATURES "cxx_std_11;c_std_11"
    INTERFACE_COMPILE_OPTIONS "-fPIC"
    INTERFACE_INCLUDE_DIRECTORIES "${_IMPORT_PREFIX}/include"
    # INTERFACE_LINK_OPTIONS "-fPIC;-shared"
    INTERFACE_LINK_DIRECTORIES "${_IMPORT_PREFIX}/@RACK_SDK_LIB_FILE_DESTINATION@"
    INTERFACE_LINK_LIBRARIES "unofficial-vcvrack::rack-sdk::core"
    IMPORTED_LOCATION "${RACK_SDK_DLL_IMPORTED_LOCATION}"
    IMPORTED_IMPLIB "${_IMPORT_PREFIX}/@RACK_SDK_LIB_FILE_DESTINATION@/libRack${RACK_SDK_LIB_FILE_EXTENSION}"
    IMPORTED_NO_SONAME "TRUE"
    COMPATIBLE_INTERFACE_STRING "INTERFACE_lib_MAJOR_VERSION;INTERFACE_lib_MINOR_VERSION;INTERFACE_lib_PATCH_VERSION"
    INTERFACE_lib_MAJOR_VERSION "@RACK_SDK_VERSION_MAJOR@"
    INTERFACE_lib_MINOR_VERSION "@RACK_SDK_VERSION_MINOR@"
    INTERFACE_lib_PATCH_VERSION "@RACK_SDK_VERSION_PATCH@"
)

# Load information for each installed configuration.
file(GLOB _cmake_config_files "${CMAKE_CURRENT_LIST_DIR}/rack-sdk-lib-targets-*.cmake")

foreach(_cmake_config_file IN LISTS _cmake_config_files)
    include("${_cmake_config_file}")
endforeach()

unset(_cmake_config_file)
unset(_cmake_config_files)

# Cleanup temporary variables.
set(_IMPORT_PREFIX)

# Loop over all imported files and verify that they actually exist
foreach(_cmake_target IN LISTS _cmake_import_check_targets)
    if(CMAKE_VERSION VERSION_LESS "3.28"
        OR NOT DEFINED _cmake_import_check_xcframework_for_${_cmake_target}
        OR NOT IS_DIRECTORY "${_cmake_import_check_xcframework_for_${_cmake_target}}")
        foreach(_cmake_file IN LISTS "_cmake_import_check_files_for_${_cmake_target}")
            if(NOT EXISTS "${_cmake_file}")
                message(FATAL_ERROR "The imported target \"${_cmake_target}\" references the file
\"${_cmake_file}\"
but this file does not exist.  Possible reasons include:
* The file was deleted, renamed, or moved to another location.
* An install or uninstall procedure did not complete successfully.
* The installation package was faulty and contained
\"${CMAKE_CURRENT_LIST_FILE}\"
but not all the files it references.
")
            endif()
        endforeach()
    endif()

    unset(_cmake_file)
    unset("_cmake_import_check_files_for_${_cmake_target}")
endforeach()

unset(_cmake_target)
unset(_cmake_import_check_targets)

# Make sure the targets which have been exported in some other
# export set exist.
unset(${CMAKE_FIND_PACKAGE_NAME}_NOT_FOUND_MESSAGE_targets)
foreach(_target "unofficial-vcvrack::rack-sdk::core" )
  if(NOT TARGET "${_target}" )
    set(${CMAKE_FIND_PACKAGE_NAME}_NOT_FOUND_MESSAGE_targets "${${CMAKE_FIND_PACKAGE_NAME}_NOT_FOUND_MESSAGE_targets} ${_target}")
  endif()
endforeach()

if(DEFINED ${CMAKE_FIND_PACKAGE_NAME}_NOT_FOUND_MESSAGE_targets)
  if(CMAKE_FIND_PACKAGE_NAME)
    set( ${CMAKE_FIND_PACKAGE_NAME}_FOUND FALSE)
    set( ${CMAKE_FIND_PACKAGE_NAME}_NOT_FOUND_MESSAGE "The following imported targets are referenced, but are missing: ${${CMAKE_FIND_PACKAGE_NAME}_NOT_FOUND_MESSAGE_targets}")
  else()
    message(FATAL_ERROR "The following imported targets are referenced, but are missing: ${${CMAKE_FIND_PACKAGE_NAME}_NOT_FOUND_MESSAGE_targets}")
  endif()
endif()
unset(${CMAKE_FIND_PACKAGE_NAME}_NOT_FOUND_MESSAGE_targets)

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
cmake_policy(POP)

]==] @ONLY)

    # export(
    # TARGETS lib
    # FILE "share/cmake/rack-sdk-lib-targets.cmake"
    # NAMESPACE unofficial-vcvrack::rack-sdk::
    # )

    list(APPEND RACK_SDK_TARGETS lib)

endif(RACK_SDK_INSTALL_LIB)

include(CMakePackageConfigHelpers)

# The Rack SDK helper functiona are here... store the file contents to a variable...
file(READ "${PROJECT_SOURCE_DIR}/share/cmake/Modules/rack-sdk.cmake" __RACK_SDK_HELPERS_FILE)

# The following codeblob is a multi-line string (not a comment) which
# explains to CMake how to set up the package "rack-sdk" and it's components...
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/rack-sdk-config.cmake.in" [==[
@PACKAGE_INIT@

include("${CMAKE_CURRENT_LIST_DIR}/rack-sdk-config-version.cmake")

set(_rack_sdk_supported_components)
list(APPEND _rack_sdk_supported_components
    @RACK_SDK_TARGETS@
)
## Custom 'check_required_components' macro
foreach(_requested_component ${rack-sdk_FIND_COMPONENTS})
    if (NOT _requested_component IN_LIST _rack_sdk_supported_components)
        message(FATAL_ERROR "Unsupported component: ${_requested_component}")
        set(rack-sdk_FOUND False)
        set(rack-sdk_NOT_FOUND_MESSAGE "Unsupported component: ${_requested_component}")
    endif()
    include("${CMAKE_CURRENT_LIST_DIR}/rack-sdk-${_requested_component}-targets.cmake")
    # Tell the user what is happening
    message(STATUS "Imported target: unofficial-vcvrack::rack-sdk::${_requested_component}")
endforeach()

unset(_rack_sdk_supported_components)

# include("${CMAKE_CURRENT_LIST_DIR}/rack-sdk-targets.cmake")
# Tell the user what is happening
message(STATUS "Imported module: unofficial-vcvrack::rack-sdk")

####################################################################################

set(RACK_SDK_DISABLE_USAGE_MESSAGE @RACK_SDK_DISABLE_USAGE_MESSAGE@)

# Begin Rack SDK helper functions...
@__RACK_SDK_HELPERS_FILE@

]==])

# Create pkgconfig file

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/Rack-SDK.pc.in" [==[
prefix=@CMAKE_INSTALL_PREFIX@
exec_prefix=${prefix}
libdir=${exec_prefix}/@CMAKE_INSTALL_LIBDIR@
includedir=${prefix}/@CMAKE_INSTALL_INCLUDEDIR@

Name: Rack-SDK
Description: @PROJECT_DESCRIPTION@
Version: @PROJECT_VERSION@
Libs: -L${libdir}
Cflags: -I${includedir} -I${includedir}/Rack-SDK/dep -I${includedir}/Rack-SDK/rack
]==])

# Configure pkgconfig file
configure_file (
  "${CMAKE_CURRENT_BINARY_DIR}/Rack-SDK.pc.in"
  "${CMAKE_CURRENT_BINARY_DIR}/lib/pkgconfig/Rack-SDK.pc"
  @ONLY
)

# Install pkgconfig file
install(
    FILES
    "${CMAKE_CURRENT_BINARY_DIR}/lib/pkgconfig/Rack-SDK.pc"
    DESTINATION
    "${CMAKE_INSTALL_LIBDIR}/pkgconfig"
)

# create cmake config file
configure_package_config_file(
    "${CMAKE_CURRENT_BINARY_DIR}/rack-sdk-config.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/lib/cmake/Rack-SDK/rack-sdk-config.cmake"
    INSTALL_DESTINATION
    "${CMAKE_INSTALL_LIBDIR}/cmake/Rack-SDK"

    # Use custom 'check_required_components' macro
    NO_CHECK_REQUIRED_COMPONENTS_MACRO
)

# generate the version file for the cmake config file
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/lib/cmake/Rack-SDK/rack-sdk-config-version.cmake"
    VERSION ${RACK_SDK_VERSION_MAJOR}.${RACK_SDK_VERSION_MINOR}.${RACK_SDK_VERSION_PATCH}
    COMPATIBILITY ExactVersion
)

# install config files
install(
    FILES
    "${CMAKE_CURRENT_BINARY_DIR}/lib/cmake/Rack-SDK/rack-sdk-config.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/lib/cmake/Rack-SDK/rack-sdk-config-version.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/lib/cmake/Rack-SDK/rack-sdk-lib-targets.cmake"
    DESTINATION
    "${CMAKE_INSTALL_LIBDIR}/cmake/Rack-SDK"
)

if(RACK_SDK_IS_TOP_LEVEL)
    # add CPack to project
    set(CPACK_PACKAGE_NAME "Rack-SDK")
    set(CPACK_PACKAGE_VENDOR "VCV")
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "CPack Component Installation")
    set(CPACK_SYSTEM_NAME "${CMAKE_SYSTEM_NAME}")
    set(CPACK_PACKAGE_VERSION_MAJOR "${RACK_SDK_VERSION_MAJOR}")
    set(CPACK_PACKAGE_VERSION_MINOR "${RACK_SDK_VERSION_MINOR}")
    set(CPACK_PACKAGE_VERSION_PATCH "${RACK_SDK_VERSION_PATCH}")
    set(CPACK_PACKAGE_VERSION "${CPACK_PACKAGE_VERSION_MAJOR}.${CPACK_PACKAGE_VERSION_MINOR}.${CPACK_PACKAGE_VERSION_PATCH}")
    set(CPACK_PACKAGE_INSTALL_DIRECTORY "Rack-SDK-${CPACK_PACKAGE_VERSION_MAJOR}.${CPACK_PACKAGE_VERSION_MINOR}.${CPACK_PACKAGE_VERSION_PATCH}")
    set(CPACK_PACKAGE_DIRECTORY "${CMAKE_INSTALL_PREFIX}")
    set(CPACK_RESOURCE_FILE_README "${CMAKE_CURRENT_SOURCE_DIR}/README.md")
    # set(CPACK_SOURCE_IGNORE_FILES)
    set(CPACK_SOURCE_IGNORE_FILES "${CPACK_IGNORE_FILES}")
    list(APPEND CPACK_SOURCE_IGNORE_FILES
        "/CVS/;/\.svn/;/\.bzr/;/\.hg/;/\.git/;\.swp\$;\.#;/#"
        "/install/"
        "/build/"
        "/dist/"
        "/out/"
        "/\.github/"
        "/\.vscode/"
    )
    # ${CPACK_PACKAGE_FILE_NAME}.${CPACK_PACKAGE_CHECKSUM}
    # set(CPACK_OUTPUT_CONFIG_FILE "${CMAKE_CURRENT_BINARY_DIR}/CPackConfig.cmake")
    # set(CPACK_SOURCE_OUTPUT_CONFIG_FILE "${CMAKE_CURRENT_BINARY_DIR}/CPackSourceConfig.cmake")
    set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-${CPACK_SYSTEM_NAME}")
    set(CPACK_SOURCE_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-Source")
    # This must always be after all CPACK\_\* variables are defined
    include(CPack)
    cpack_add_component(dep
        DISPLAY_NAME "Dependency C++ Headers"
        DESCRIPTION "C/C++ header files for Rack-SDK's dependencies"
        GROUP "Rack-SDK"
    )
    cpack_add_component(core
        DISPLAY_NAME "C++ Headers"
        DESCRIPTION "C/C++ header files for Rack-SDK"
        GROUP "Rack-SDK"
        DEPENDS dep
    )
    cpack_add_component(lib
        DISPLAY_NAME "Shared Library"
        DESCRIPTION "Dynamic library for Rack-SDK"
        GROUP "Rack-SDK"
        DEPENDS core
    )
    cpack_add_component(runtimes
        DISPLAY_NAME "Shared Library Dependencies"
        DESCRIPTION "Dynamic library Dependencies for Rack-SDK"
        GROUP "Rack-SDK"
        DEPENDS lib
    )
    # cpack_add_component(rack-sdk)
endif()

unset(__RACK_SDK_HELPERS_FILE)
