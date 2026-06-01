test_that("K1 Rust extendr variants match the R reference on the small fixture", {
  skip_if_not(
    ledgrcorespike:::.k1_rust_available(),
    "Rust extendr DLL is not built; run cargo +stable-gnu build in src-rust"
  )

  bars <- ledgrcorespike:::k1_make_fixture_bars("small")

  cases <- list(
    strat_R_handler_R = list(
      r = k1_r_fold_strat_R_handler_R,
      rust = k1_rust_fold_strat_R_handler_R
    ),
    strat_R_handler_inline = list(
      r = k1_r_fold_strat_R_handler_inline,
      rust = k1_rust_fold_strat_R_handler_inline
    ),
    strat_static_handler_R = list(
      r = k1_r_fold_strat_static_handler_R,
      rust = k1_rust_fold_strat_static_handler_R
    ),
    strat_static_handler_inline = list(
      r = k1_r_fold_strat_static_handler_inline,
      rust = k1_rust_fold_strat_static_handler_inline
    )
  )

  for (name in names(cases)) {
    r_result <- cases[[name]]$r(bars)
    rust_result <- cases[[name]]$rust(bars)

    expect_equal(
      rust_result$equity,
      r_result$equity,
      tolerance = 1e-8,
      info = paste("Rust equity parity for", name)
    )
    expect_identical(
      rust_result$events,
      r_result$events,
      info = paste("Rust event parity for", name)
    )
  }
})
