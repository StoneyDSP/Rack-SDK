# VCVRack (unofficial CMake targets)

Unofficial CMake targets and API for [VCV Rack 2 SDK](https://vcvrack.com/manual/PluginDevelopmentTutorial).

Created by [StoneyDSP](https://github.com/StoneyDSP) (no affiliation with VCV Rack or its' creators).

- [What is this?](#what-is-this)
- [How does this work?](#how-does-this-work)
- [How can I use it?](#how-can-i-use-it)
- [Why?](#why)

## What is this?

This is an empty project containing primarily a `CMakeLists.txt` file and some license information.

The `CMakeLists.txt` file is designed to find a local copy of the Rack SDK using the variable named `RACK_DIR`; once found, the `CMakeLists.txt` file instructs CMake how to arrange the SDK files into logical CMake-style "targets".

Developers who are building plugins (suites of "modules") for VCV Rack 2 may use these "targets" in their own CMake projects, by using `find_package(rack-sdk)`, followed by `target_link_libraries(yourTarget PRIVATE unofficial-vcvrack::rack-sdk::lib)`, and such forth, in their project's `CMakeLists.txt` file.

This provides a way of setting up the C++ toolchain - the compiler, linker, and other tools - in a CMake project to create library files (and test executables) which are compatible with the VCV Rack 2 runtime (the Rack executable).

Additionally, developers who acquire Rack-SDK using these CMake targets will be able to use a custom, lightweight CMake API to easily build a VCV Rack plugin and scale it up with modules. Here's an example project's `CMakeLists.txt` file:

```cmake
cmake_minimum_required(VERSION 3.14...3.31 FATAL_ERROR)

project(MyPlugin)

find_package(rack-sdk 2.5.2 REQUIRED COMPONENTS dep core lib CONFIG)

vcvrack_add_plugin(
    SLUG "MySlug"
    BRAND "MyBrand"
    HEADERS "include/plugin.hpp"
    SOURCES "src/plugin.cpp"
)

set(MYPLUGIN_MODULES)
list(APPEND MYPLUGIN_MODULES
    LFO
    VCO
    VCF
    VCA
)
foreach(MODULE IN LISTS MYPLUGIN_MODULES)

    vcvrack_add_module(${MODULE}
        SLUG "MySlug"
        BRAND "MyBrand"
        SOURCES "src/${MODULE}.cpp"
    )

endforeach()
```

...and that's it!

## How does this work?

This CMake project expects that you have an unmodified copy of the correct Rack 2 SDK on your filesystem (for now...), and for the correct platform. The location of this Rack SDK copy is passed in to CMake when configuring the VCVRack project (`-DRACK_DIR="path/to/unzipped/Rack-SDK"`), and in return, CMake will generate three targets for linkage:

- `unofficial-vcvrack::rack-sdk::dep` - the header file contents of `<RACK_SDK>/dep/include`
- `unofficial-vcvrack::rack-sdk::core` - the header file contents of `<RACK_SDK>/include`
- `unofficial-vcvrack::rack-sdk::lib` - the `libRack.{so,dylib,dll,dll.a}` library file

All three targets are passed to CMake's "install" routine, which makes them relocatable within the context of the CMake buildsystem. This allows CMake to relocate and/or make copies of the SDK files, and do whatever it likes to do with them, without causing any breakages.

## How can I use it?

Download [VCV Rack](https://vcvrack.com/Rack) and the Rack SDK ([Windows x64](https://vcvrack.com/downloads/Rack-SDK-latest-win-x64.zip) / [Mac x64+ARM64](https://vcvrack.com/downloads/Rack-SDK-latest-mac-x64+arm64.zip) / [Linux x64](https://vcvrack.com/downloads/Rack-SDK-latest-lin-x64.zip)). Install VCV Rack, and unzip the SDK to any location on your local filesystem.

Clone this project and move into the VCVRack SDK directory:

```shell
git clone git@github.com:StoneyDSP/StoneyVCV.git && cd StoneyVCV/dep/VCVRack/Rack-SDK
```

Configure CMake with a source directory (`-S`), a build directory (`-B`), and the `RACK_DIR` variable (`-DRACK_DIR=`).

```shell
cmake                                     \
  -S .                                    \
  -B ./build                              \
  -DRACK_DIR="path/to/unzipped/Rack-SDK"
```

Once configuration is complete, use the `--install` command on the build output directory, optionally with the `--prefix` arg to specify where the files should be "installed" to (here, just to `./install` in the current working directory):

```shell
cmake --install ./build --prefix ./install
```

## Why?

The above allows us to "acquire" the VCVRack SDK files as if it were a "package" dependency in another project (i.e., in a VCV Rack plugin project) via [vcpkg package manager for C and C++](https://github.com/microsoft/vcpkg).

To facilitate the above, [a vcpkg portfile can simply download the SDK zip file, unzip it, and pass along the unzipped output directory as `RACK_DIR`](https://github.com/StoneyDSP/Rack-SDK/blob/production/share/vcpkg/ports/rack/2.5.2/portfile.cmake) when configuring this as a CMake package dependency...

## Additional Functionality

Rack-SDK for CMake packs some interesting features into its' design, including some well - thought-out and thoroughly tested build system features.

To streamline much of these many options and configurations, we have provided some additional functionality which will brings a lot more control over the build (and deloyment, and debugging, and tests...) under smaller "macro"-like functions, with the use of tools such as CMake Presets and Makefile commands.

These additional functions provide a wide coverage of the full feature set, usually in just a single command line argument each.

### CMake Presets

The following CMake Presets are available for easy access to various configurations:

```txt
x64-windows-debug
x64-windows-release
x64-windows-debug-verbose
x64-windows-release-verbose
```
```txt
x64-linux-debug
x64-linux-release
x64-linux-debug-verbose
x64-linux-release-verbose
```
```txt
x64-osx-debug
x64-osx-release
x64-osx-debug-verbose
x64-osx-release-verbose
```

```txt
arm64-osx-debug
arm64-osx-release
arm64-osx-debug-verbose
arm64-osx-release-verbose
```

To use a CMake Preset, you can just pass the `--preset=` arg to CMake (no other args required):

```shell
cmake --preset x64-windows-release
```

*The above command will configure the CMake project for Windows 64-bit in Release mode using the same settings that the Rack-SDK itself implements, respectively*

### Makefile commands

As a further helper, we have also organized our `Makefile` to *automatically detect* a relevant CMake Preset - if not manually chosen - and run CMake for us, using an *even simpler* command, which works on *all* platforms:

```shell
make configure
```

*The above command will configure the plugin for the host machine's platform; the CPU and OS are detected by the Rack-SDK itself, while the common environment variables `VERBOSE` and `DEBUG` may also be set or unset, to further adapt the behaviour of `make configure` according to your current environment.*

Further CMake actions and workflows can be triggered via `make` in a similarly environment-sensitive manner:

```shell
make reconfigure
```

*Clears the current CMake cache file (not dir!) and runs the configure step again*

```shell
make build
```

*Builds all currently-enabled CMake targets (none currently)*


```shell
make test
```

*Runs CTest on the build output directory, executing any tests it finds (none currently)*


```shell
make package
```

*Creates a local directory (`./install`) containing a distributable package, unarchived*

### *NOTE*

The files under `share/` and `include/` are not actually in use; those are just reference material, and a helper to silence some warnings from vcpkg, respectively. Everything of interest is in either the `CMakeLists.txt`, `vcpkg.json`, or elsewhere...

## Further Reading

- [CMake Importing and Exporting Guide](https://cmake.org/cmake/help/latest/guide/importing-exporting/index.html)
- [VCV Rack - Installing and Running](https://vcvrack.com/manual/Installing)
- [VCV Rack - Getting Started](https://vcvrack.com/manual/GettingStarted)
- [VCV Rack - Plugin Development Tutorial](https://vcvrack.com/manual/PluginDevelopmentTutorial)
- [VCV Rack - Plugin Guide](https://vcvrack.com/manual/PluginGuide)
