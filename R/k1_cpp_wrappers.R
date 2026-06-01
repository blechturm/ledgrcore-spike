# Public wrappers for the K1 C++ cpp11 spike implementation.

k1_cpp_fold_strat_R_handler_R <- function(bars, initial_cash = 1e6) {
  acc <- new.env(parent = emptyenv())
  acc$n <- 0L
  acc$buffer <- k1_event_empty(k1_event_capacity(nrow(bars), ncol(bars)))
  result <- .Call(
    `_ledgrcorespike_k1_cpp_fold_strat_R_handler_R`,
    bars,
    initial_cash,
    k1_r_strategy_callback,
    k1_output_handler,
    acc
  )
  result$events <- k1_event_frame(acc$buffer, acc$n)
  result
}

k1_cpp_fold_strat_R_handler_inline <- function(bars, initial_cash = 1e6) {
  .Call(
    `_ledgrcorespike_k1_cpp_fold_strat_R_handler_inline`,
    bars,
    initial_cash,
    k1_r_strategy_callback
  )
}

k1_cpp_fold_strat_static_handler_R <- function(bars, initial_cash = 1e6) {
  acc <- new.env(parent = emptyenv())
  acc$n <- 0L
  acc$buffer <- k1_event_empty(k1_event_capacity(nrow(bars), ncol(bars)))
  result <- .Call(
    `_ledgrcorespike_k1_cpp_fold_strat_static_handler_R`,
    bars,
    initial_cash,
    k1_output_handler,
    acc
  )
  result$events <- k1_event_frame(acc$buffer, acc$n)
  result
}

k1_cpp_fold_strat_static_handler_inline <- function(bars, initial_cash = 1e6) {
  .Call(`_ledgrcorespike_k1_cpp_fold_strat_static_handler_inline`, bars, initial_cash)
}
