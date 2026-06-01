test_that("cpp11 hello-world stub is callable", {
  expect_identical(ledgrcore_spike_cpp_hello(), "cpp toolchain alive")
})
