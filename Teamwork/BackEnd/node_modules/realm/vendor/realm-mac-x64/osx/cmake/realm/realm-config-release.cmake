#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "realm" for configuration "Release"
set_property(TARGET realm APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(realm PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_RELEASE "CXX"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/librealm.a"
  )

list(APPEND _IMPORT_CHECK_TARGETS realm )
list(APPEND _IMPORT_CHECK_FILES_FOR_realm "${_IMPORT_PREFIX}/lib/librealm.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
