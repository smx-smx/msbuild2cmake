# msbuild2cmake
Template to use CMake in complex MSBuild flows without writing custom MSBuild tasks

It can be used to effectively work around MSBuild limitations or weaknesses, like weak tracking of files generated dynamically at build time.
It can also be used to express dependencies between MSBuild and external projects, or vice versa.

Part of this module is a modified fork of https://github.com/microsoft/GraphEngine/blob/ec3588389a5f5edc034d91a020d6f19c52381d2b/cmake/FindDotnet.cmake

## Architecture

### BuildTargets.csproj
`BuildTargets.csproj` is a dummy C# project holding all CMake build targets.

For every CMake target you want to call, there must be a corresponding MSBuild target defined in `BuildTargets.csproj`

Example:
```xml
  <Target Name="sample_cmake_target">
    <Exec Command="cmake $(CMakeArguments) -DTARGET=sample_cmake_target -P $(InvokeCMake)" />
  </Target>
```

### invoke.cmake
When a MSBuild/CMake target is invoked, `invoke.cmake` is called with CMake program mode (`-P`)
This means `invoke.cmake` cannot define targets, but it runs in CMake and has access to all its variables.

The purpose of this script is to convert variables passed by MSBuild into a CMake invocation.

These are the variables passed by `BuildTargets.csproj`

| MSBuild variable | CMake variable   | Action                     |
|------------------|------------------|----------------------------|
| $(Configuration) | CMAKE_BUILD_TYPE | Passed to `CMakeLists.txt` |
| $(Platform)      | MSBUILD_PLATFORM | Passed to `CMakeLists.txt` |

Let's look at `invoke.cmake` itself

```cmake
invoke_cmake(
	BUILD_DIR ${CMAKE_BINARY_DIR}/build/${TARGET}
	DIRECTORY ${MSBUILD_SLN_DIR}
	TARGET ${TARGET}
	PASS_VARIABLES
		CMAKE_BUILD_TYPE
	EXTRA_ARGUMENTS
		-DMSBUILD_PLATFORM=${MSBUILD_ACTUAL_PLATFORM}
		-DTARGET=${TARGET}
)
```

This is equivalent to doing `cmake <sourceDir>` and `cmake --build <buildDir> --target=foo` yourself


### CMakeLists.txt
CMakeLists.txt receives the MSBuild target as `TARGET`, which is fundamentally a `build action`.
Instead of generating all the possible targets for all possible actions, we can make them conditional.

```cmake
if("${TARGET}" STREQUAL "sample_cmake_target")
	# we must create a target that matches the ${TARGET} name
	add_custom_target(sample_cmake_target)

	add_custom_target(sample_dependency
		COMMENT "doing something"
		COMMAND ${CMAKE_COMMAND} -E echo "Hello World, in ${TARGET}"
	)
	add_dependencies(sample_cmake_target sample_dependency)
elseif(NOT "${TARGET}" STREQUAL "")
	message(FATAL_ERROR "Unknown target ${TARGET}")
endif()
```

**NOTE:** `invoke.cmake` expects that CMakeLists.txt will create a target with the name specified by `TARGET`
In other words, if `TARGET` is `sample_cmake_target`, `CMakeLists.txt` must create a custom target called `sample_cmake_target`

## CMake intra-TARGET dependencies
What if we're running in TARGET `bar`, and we want to depend on `foo` in the same CMakeLists.txt?

```cmake
function(add_buildtarget_invocation)
	cmake_parse_arguments(invoke "" "TARGET_NAME;OUT_TARGET_NAME" "" ${ARGN})
	add_custom_target(${invoke_OUT_TARGET_NAME}
		COMMAND
			${DOTNET_EXE} msbuild
			-p:Platform=${MSBUILD_PLATFORM}
			-p:Configuration=${CMAKE_BUILD_TYPE}
			-v:m -m
			-t:${invoke_TARGET_NAME}
			${TOP}/BuildTargets/BuildTargets.csproj
	)
endfunction()

if("${TARGET}" STREQUAL "foo")
  add_custom_target(foo)
elseif("${TARGET}" STREQUAL "bar")
  add_buildtarget_invocation(TARGET_NAME "foo" OUT_TARGET_NAME "invoke_foo")
  add_custom_target(bar)
  add_dependencies(bar invoke_foo)
elseif(NOT "${TARGET}" STREQUAL "")
	message(FATAL_ERROR "Unknown target ${TARGET}")
endif()
```

## MSBuild dependency on CMake targets
What if we're building a MSBuild project, and we have a pre-build dependency on a CMake target called `foo`?

```xml
  <Target Name="GenerateCsFiles" BeforeTargets="CoreCompile">
    <MSBuild Projects="$(ProjectDir)..\BuildTargets\BuildTargets.csproj"
             Properties="Configuration=$(Configuration);Platform=$(Platform)"
             Targets="foo" />
  </Target>
```

Of course, `foo` must be 
- defined in `BuildTargets.csproj`
- handled by checking `TARGET` in CMakeLists.txt
- must be a target created by the invocation of `add_custom_target`

## Command line invocation
`dotnet msbuild` is the entry point, for example as following

```
dotnet msbuild /p:Configuration=Debug /p:Platform=AnyCPU ./BuildTargets/BuildTargets.csproj -v:m -m -t:my_cmake_target
```
