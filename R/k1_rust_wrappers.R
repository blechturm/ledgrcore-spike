# Development wrappers for the K1 Rust extendr spike library.

.k1_repo_root <- function(start = getwd()) {
  path <- normalizePath(start, winslash = "/", mustWork = TRUE)
  repeat {
    if (file.exists(file.path(path, "src-rust", "Cargo.toml"))) {
      return(path)
    }
    parent <- dirname(path)
    if (identical(parent, path)) {
      stop("could not locate ledgrcore-spike repository root", call. = FALSE)
    }
    path <- parent
  }
}

.k1_rust_dll_path <- function() {
  root <- .k1_repo_root()
  candidates <- c(
    file.path(
      root,
      "src-rust",
      "target",
      "release",
      "ledgrcorespike_rust.dll"
    ),
    file.path(
      root,
      "src-rust",
      "target",
      "debug",
      "ledgrcorespike_rust.dll"
    )
  )
  existing <- candidates[file.exists(candidates)]
  if (length(existing) > 0L) {
    return(existing[[1L]])
  }
  candidates[[1L]]
}

.k1_rust_available <- function() {
  path <- tryCatch(.k1_rust_dll_path(), error = function(e) NA_character_)
  isTRUE(!is.na(path) && file.exists(path))
}

.k1_load_rust_dll <- function() {
  dll <- getLoadedDLLs()[["ledgrcorespike_rust"]]
  if (!is.null(dll)) {
    return(invisible(dll))
  }

  path <- .k1_rust_dll_path()
  if (!file.exists(path)) {
    stop(
      "Rust extendr DLL not found at ", path,
      ". Run `cargo +stable-gnu build --release` in `src-rust/` first.",
      call. = FALSE
    )
  }

  dyn.load(path)
  invisible(getLoadedDLLs()[["ledgrcorespike_rust"]])
}

.k1_rust_symbol <- function(name) {
  .k1_load_rust_dll()
  getNativeSymbolInfo(name, PACKAGE = "ledgrcorespike_rust")
}

.k1_rust_call <- function(name, ...) {
  do.call(.Call, c(list(.k1_rust_symbol(name)), list(...)))
}

.k1_rust_event_frame <- function(buffer) {
  data.frame(
    pulse_idx = as.integer(buffer$pulse_idx),
    instrument_idx = as.integer(buffer$instrument_idx),
    quantity = as.numeric(buffer$quantity),
    price = as.numeric(buffer$price),
    cash_delta = as.numeric(buffer$cash_delta),
    position_delta = as.numeric(buffer$position_delta),
    realized_pnl = as.numeric(buffer$realized_pnl),
    cost_basis_after = as.numeric(buffer$cost_basis_after),
    side_code = as.integer(buffer$side_code)
  )
}

.k1_rust_output_acc <- function(bars) {
  acc <- new.env(parent = emptyenv())
  acc$n <- 0L
  acc$buffer <- k1_event_empty(k1_event_capacity(nrow(bars), ncol(bars)))
  acc
}

k1_rust_fold_strat_R_handler_R <- function(bars, initial_cash = 1e6) {
  .k1_load_rust_dll()
  acc <- .k1_rust_output_acc(bars)
  result <- .k1_rust_call(
    "wrap__k1_rust_fold_strat_r_handler_r",
    bars,
    initial_cash,
    k1_r_strategy_callback,
    k1_output_handler,
    acc
  )
  result$events <- k1_event_frame(acc$buffer, acc$n)
  result
}

k1_rust_fold_strat_R_handler_inline <- function(bars, initial_cash = 1e6) {
  .k1_load_rust_dll()
  result <- .k1_rust_call(
    "wrap__k1_rust_fold_strat_r_handler_inline",
    bars,
    initial_cash,
    k1_r_strategy_callback
  )
  result$events <- .k1_rust_event_frame(result$events)
  result
}

k1_rust_fold_strat_static_handler_R <- function(bars, initial_cash = 1e6) {
  .k1_load_rust_dll()
  acc <- .k1_rust_output_acc(bars)
  result <- .k1_rust_call(
    "wrap__k1_rust_fold_strat_static_handler_r",
    bars,
    initial_cash,
    k1_output_handler,
    acc
  )
  result$events <- k1_event_frame(acc$buffer, acc$n)
  result
}

k1_rust_fold_strat_static_handler_inline <- function(bars, initial_cash = 1e6) {
  .k1_load_rust_dll()
  result <- .k1_rust_call(
    "wrap__k1_rust_fold_strat_static_handler_inline",
    bars,
    initial_cash
  )
  result$events <- .k1_rust_event_frame(result$events)
  result
}
