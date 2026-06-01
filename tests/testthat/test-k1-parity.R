test_that("K1 R reference variants agree on the small fixture", {
  bars <- ledgrcorespike:::k1_make_fixture_bars("small")

  results <- list(
    strat_R_handler_R = k1_r_fold_strat_R_handler_R(bars),
    strat_R_handler_inline = k1_r_fold_strat_R_handler_inline(bars),
    strat_static_handler_R = k1_r_fold_strat_static_handler_R(bars),
    strat_static_handler_inline = k1_r_fold_strat_static_handler_inline(bars)
  )

  reference <- results$strat_static_handler_inline

  for (name in names(results)) {
    expect_equal(
      results[[name]]$equity,
      reference$equity,
      tolerance = 1e-8,
      info = paste("equity parity for", name)
    )
    expect_identical(
      results[[name]]$events,
      reference$events,
      info = paste("event parity for", name)
    )
  }
})

test_that("K1 small fixture emits the spec-pinned fill count", {
  bars <- ledgrcorespike:::k1_make_fixture_bars("small")
  result <- k1_r_fold_strat_static_handler_inline(bars)

  expect_length(result$equity, 1260L)
  expect_equal(nrow(result$events), 7042L)
})

test_that("K1 event stream exposes the spec-pinned data-frame surface", {
  bars <- ledgrcorespike:::k1_make_fixture_bars("small")
  events <- k1_r_fold_strat_static_handler_inline(bars)$events

  expect_s3_class(events, "data.frame")
  expect_identical(
    names(events),
    c(
      "pulse_idx",
      "instrument_idx",
      "quantity",
      "price",
      "cash_delta",
      "position_delta",
      "realized_pnl",
      "cost_basis_after",
      "side_code"
    )
  )
  expect_type(events$pulse_idx, "integer")
  expect_type(events$instrument_idx, "integer")
  expect_type(events$quantity, "double")
  expect_type(events$price, "double")
  expect_type(events$cash_delta, "double")
  expect_type(events$position_delta, "double")
  expect_type(events$realized_pnl, "double")
  expect_type(events$cost_basis_after, "double")
  expect_type(events$side_code, "integer")
})
