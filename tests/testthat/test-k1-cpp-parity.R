test_that("K1 C++ cpp11 variants match the R reference on the small fixture", {
  bars <- ledgrcorespike:::k1_make_fixture_bars("small")

  cases <- list(
    strat_R_handler_R = list(
      r = k1_r_fold_strat_R_handler_R,
      cpp = k1_cpp_fold_strat_R_handler_R
    ),
    strat_R_handler_inline = list(
      r = k1_r_fold_strat_R_handler_inline,
      cpp = k1_cpp_fold_strat_R_handler_inline
    ),
    strat_static_handler_R = list(
      r = k1_r_fold_strat_static_handler_R,
      cpp = k1_cpp_fold_strat_static_handler_R
    ),
    strat_static_handler_inline = list(
      r = k1_r_fold_strat_static_handler_inline,
      cpp = k1_cpp_fold_strat_static_handler_inline
    )
  )

  for (name in names(cases)) {
    r_result <- cases[[name]]$r(bars)
    cpp_result <- cases[[name]]$cpp(bars)

    expect_equal(
      cpp_result$equity,
      r_result$equity,
      tolerance = 1e-8,
      info = paste("C++ equity parity for", name)
    )
    expect_identical(
      cpp_result$events,
      r_result$events,
      info = paste("C++ event parity for", name)
    )
  }
})

test_that("K1 C++ cpp11 variants match Rust extendr on the small fixture", {
  skip_if_not(
    ledgrcorespike:::.k1_rust_available(),
    "Rust extendr DLL is not built; run cargo +stable-gnu build --release in src-rust"
  )

  bars <- ledgrcorespike:::k1_make_fixture_bars("small")

  cases <- list(
    strat_R_handler_R = list(
      cpp = k1_cpp_fold_strat_R_handler_R,
      rust = k1_rust_fold_strat_R_handler_R
    ),
    strat_R_handler_inline = list(
      cpp = k1_cpp_fold_strat_R_handler_inline,
      rust = k1_rust_fold_strat_R_handler_inline
    ),
    strat_static_handler_R = list(
      cpp = k1_cpp_fold_strat_static_handler_R,
      rust = k1_rust_fold_strat_static_handler_R
    ),
    strat_static_handler_inline = list(
      cpp = k1_cpp_fold_strat_static_handler_inline,
      rust = k1_rust_fold_strat_static_handler_inline
    )
  )

  for (name in names(cases)) {
    cpp_result <- cases[[name]]$cpp(bars)
    rust_result <- cases[[name]]$rust(bars)

    expect_equal(
      cpp_result$equity,
      rust_result$equity,
      tolerance = 1e-8,
      info = paste("C++/Rust equity parity for", name)
    )
    expect_identical(
      cpp_result$events,
      rust_result$events,
      info = paste("C++/Rust event parity for", name)
    )
  }
})
