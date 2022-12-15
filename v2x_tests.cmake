# Creating new target to call all the added tests
add_custom_target(all_v2x_tests ALL)

function(V2X_GENERIC_TEST)
  # ~~~
  # V2X_GENERIC_TEST(
  #   NAME name
  #   TYPE pb_type | model
  #   )
  # ~~~
  #
  # This function is used to create targets to perform a test on generic TYPE (pb_type or model).
  # There are some tests which require only pb_types XMLs to be checked and others who require only models XMLs to be checked.
  # Therefore, this function is used to generalize and perform the desired test.
  #
  # NAME name of the test.
  # TYPE type of test that has to be performed (model or pb_type generation).
  #
  # In addition it adds the newly created target to the `all_v2x_tests` dependencies. (all tests will be performed with `make all_v2x_tests`)
  #
  # Usage: v2x_generic_test(NAME <test_name> TYPE <model|pb_type>) (All fields are required)

  set(oneValueArgs NAME TYPE)
  cmake_parse_arguments(
    V2X_GENERIC_TEST
    "${options}"
    "${oneValueArgs}"
    "${multiValueArgs}"
    ${ARGN}
  )

  set(TYPE ${V2X_GENERIC_TEST_TYPE})
  set(NAME ${V2X_GENERIC_TEST_NAME})

  # pb_type checking
  set(GOLDEN_XML golden.${TYPE}.xml)
  add_file_target(FILE ${GOLDEN_XML} SCANNER_TYPE xml)
  xml_sort(NAME ${NAME}_${TYPE}_golden_sort FILE ${GOLDEN_XML} OUTPUT ${NAME}.${TYPE}.golden.xml)

  set(ACTUAL_XML ${NAME}.${TYPE}.xml)
  xml_sort(NAME ${NAME}_${TYPE}_actual_sort FILE ${ACTUAL_XML} OUTPUT ${NAME}.${TYPE}.actual.xml)

  diff(NAME ${NAME}_${TYPE}_diff GOLDEN ${NAME}.${TYPE}.golden.xml ACTUAL ${NAME}.${TYPE}.actual.xml)

  add_dependencies(all_v2x_tests ${NAME}_${TYPE}_diff)

  # update golden model/pb_type target
  add_custom_target(${NAME}_update_golden_${TYPE})
  add_custom_command(
    TARGET ${NAME}_update_golden_${TYPE}
    POST_BUILD
    COMMAND cp ${ACTUAL_XML} ${CMAKE_CURRENT_SOURCE_DIR}/golden.${TYPE}.xml
    )
endfunction(V2X_GENERIC_TEST)

function(V2X_TEST_MODEL)
  # ~~~
  # V2X_TEST_MODEL(
  #   NAME name
  #   TOP_MODULE name
  #   )
  # ~~~
  #
  # This function is to test only the model XML generation. It will call V2X_GENERIC_TEST with the field TYPE set to `model`.
  #
  # NAME name of the test.
  # TOP_MODULE name of the top verilog module that has to be tested.
  #
  # Usage: v2x_test_model(NAME <test_name> TOP_MODULE <top_module.v>) (All fields are required)

  set(oneValueArgs NAME TOP_MODULE)
  cmake_parse_arguments(
    V2X_TEST_MODEL
    "${options}"
    "${oneValueArgs}"
    "${multiValueArgs}"
    ${ARGN}
  )

  set(NAME ${V2X_TEST_MODEL_NAME})
  set(TOP_MODULE ${V2X_TEST_MODEL_TOP_MODULE})

  set(SRC ${NAME}.sim.v)
  v2x(NAME ${NAME} SRCS ${SRC} TOP_MODULE ${TOP_MODULE})

  v2x_generic_test(NAME ${NAME} TOP_MODULE ${TOP_MODULE} TYPE model)

  add_custom_target(${NAME}_diff ALL DEPENDS ${NAME}_model_diff)
endfunction(V2X_TEST_MODEL)

function(V2X_TEST_PB_TYPE)
  # ~~~
  # V2X_TEST_PB_TYPE(
  #   NAME name
  #   TOP_MODULE name
  #   )
  # ~~~
  #
  # This function is to test only the pb_type XML generation. It will call V2X_GENERIC_TEST with the field TYPE set to `pb_type`
  #
  # NAME name of the test.
  # TOP_MODULE name of the top verilog module that has to be tested.
  #
  # Usage: v2x_test_model(NAME <test_name> TOP_MODULE <top_module.v>) (All fields are required)

  set(oneValueArgs NAME TOP_MODULE)
  cmake_parse_arguments(
    V2X_TEST_PB_TYPE
    "${options}"
    "${oneValueArgs}"
    "${multiValueArgs}"
    ${ARGN}
  )

  set(NAME ${V2X_TEST_MODEL_NAME})
  set(TOP_MODULE ${V2X_TEST_MODEL_TOP_MODULE})

  set(SRC ${NAME}.sim.v)
  v2x(NAME ${NAME} SRCS ${SRC} TOP_MODULE ${TOP_MODULE})

  v2x_generic_test(NAME ${NAME} TOP_MODULE ${TOP_MODULE} TYPE pb_type)

  add_custom_target(${NAME}_diff ALL DEPENDS ${NAME}_pb_type_diff)
endfunction(V2X_TEST_PB_TYPE)

function(V2X_TEST_BOTH)
  # ~~~
  # V2X_TEST_BOTH(
  #   NAME name
  #   TOP_MODULE name
  #   )
  # ~~~
  #
  # This function is to test both the pb_type XML generation. It will call V2X_GENERIC_TEST multiple times first with the field TYPE set to `pb_type`
  # then with `model`
  #
  # NAME name of the test.
  # TOP_MODULE name of the top verilog module that has to be tested.
  #
  # Usage: v2x_test_model(NAME <test_name> TOP_MODULE <top_module.v>) (All fields are required)

  set(oneValueArgs NAME TOP_MODULE)
  cmake_parse_arguments(
    V2X_TEST_BOTH
    "${options}"
    "${oneValueArgs}"
    "${multiValueArgs}"
    ${ARGN}
  )

  set(NAME ${V2X_TEST_BOTH_NAME})
  set(TOP_MODULE ${V2X_TEST_BOTH_TOP_MODULE})

  set(SRC ${NAME}.sim.v)
  v2x(NAME ${NAME} SRCS ${SRC} TOP_MODULE ${TOP_MODULE})

  v2x_generic_test(NAME ${NAME} TOP_MODULE ${MODULE} TYPE pb_type)
  v2x_generic_test(NAME ${NAME} TOP_MODULE ${TOP_MODULE} TYPE model)
  vpr_test_pbtype(NAME ${NAME})

  add_custom_target(${NAME}_diff ALL DEPENDS ${NAME}_pb_type_diff ${NAME}_model_diff)
endfunction(V2X_TEST_BOTH)
