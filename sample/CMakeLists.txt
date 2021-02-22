cmake_minimum_required ( VERSION 3.10 FATAL_ERROR )
list(INSERT CMAKE_MODULE_PATH 0 "${CMAKE_CURRENT_LIST_DIR}/../cmake")
find_package(Dotnet 2.0 REQUIRED)

project(sample NONE)

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
