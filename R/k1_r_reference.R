# K1 measurement spike R reference implementation.

K1_REBALANCE_INTERVAL <- 5L
K1_LOT_EMPTY_EPS <- 2.2204460492503131e-16
K1_SHORT_GUARD_EPS <- 1.4901161193847656e-08

k1_make_fixture_bars <- function(scale = c("small", "large", "xlarge")) {
  scale <- match.arg(scale)
  n_inst <- switch(scale, small = 50L, large = 100L, xlarge = 1000L)
  n_pulses <- 1260L

  bars <- matrix(0, nrow = n_inst, ncol = n_pulses)
  for (t in seq_len(n_pulses)) {
    for (i in seq_len(n_inst)) {
      wave <- ((i * 7919L + t * 6311L) %% 10000L) / 100000.0
      bars[i, t] <- 100 + 0.01 * i + 0.001 * t + wave
    }
  }
  bars
}

k1_active_count <- function(n_inst) {
  switch(
    as.character(n_inst),
    "50" = 14L,
    "100" = 27L,
    "1000" = 259L,
    stop("unsupported K1 fixture instrument count: ", n_inst, call. = FALSE)
  )
}

k1_static_targets <- function(pulse_idx, prices, cash, positions, initial_cash) {
  n_inst <- length(prices)
  active_count <- k1_active_count(n_inst)

  if ((pulse_idx - 1L) %% K1_REBALANCE_INTERVAL != 0L) {
    return(positions)
  }

  rebalance_idx <- (pulse_idx - 1L) %/% K1_REBALANCE_INTERVAL
  start <- if (rebalance_idx %% 2L == 0L) {
    1L
  } else {
    active_count + 1L
  }
  active <- seq.int(start, start + active_count - 1L)
  target_notional <- initial_cash / active_count

  targets <- numeric(n_inst)
  targets[active] <- target_notional / prices[active]
  targets
}

k1_r_strategy_callback <- function(ctx) {
  k1_static_targets(
    pulse_idx = ctx$pulse_idx,
    prices = ctx$prices,
    cash = ctx$cash,
    positions = ctx$positions,
    initial_cash = ctx$initial_cash
  )
}

k1_lot_apply_fill <- function(lot, quantity, price) {
  realized_pnl <- 0
  cost_basis_after <- 0

  if (quantity > 0) {
    lot$quantity <- c(lot$quantity, quantity)
    lot$cost_basis <- c(lot$cost_basis, price)
  } else if (quantity < 0) {
    remaining <- -quantity
    while (remaining > 0 && length(lot$quantity) > 0) {
      take <- min(remaining, lot$quantity[1L])
      realized_pnl <- realized_pnl + take * (price - lot$cost_basis[1L])
      lot$quantity[1L] <- lot$quantity[1L] - take
      remaining <- remaining - take

      if (lot$quantity[1L] <= K1_LOT_EMPTY_EPS) {
        lot$quantity <- lot$quantity[-1L]
        lot$cost_basis <- lot$cost_basis[-1L]
      }
    }

    if (remaining > K1_SHORT_GUARD_EPS) {
      stop("K1 R reference does not support short lot creation", call. = FALSE)
    }
  }

  if (length(lot$quantity) > 0) {
    cost_basis_after <- sum(lot$quantity * lot$cost_basis) / sum(lot$quantity)
  }

  list(
    lot = lot,
    realized_pnl = realized_pnl,
    cost_basis_after = cost_basis_after
  )
}

k1_event_empty <- function(capacity = 0L) {
  list(
    pulse_idx = integer(capacity),
    instrument_idx = integer(capacity),
    quantity = numeric(capacity),
    price = numeric(capacity),
    cash_delta = numeric(capacity),
    position_delta = numeric(capacity),
    realized_pnl = numeric(capacity),
    cost_basis_after = numeric(capacity),
    side_code = integer(capacity)
  )
}

k1_event_frame <- function(buffer, n) {
  if (n == 0L) {
    return(data.frame(
      pulse_idx = integer(),
      instrument_idx = integer(),
      quantity = numeric(),
      price = numeric(),
      cash_delta = numeric(),
      position_delta = numeric(),
      realized_pnl = numeric(),
      cost_basis_after = numeric(),
      side_code = integer()
    ))
  }

  data.frame(
    pulse_idx = buffer$pulse_idx[seq_len(n)],
    instrument_idx = buffer$instrument_idx[seq_len(n)],
    quantity = buffer$quantity[seq_len(n)],
    price = buffer$price[seq_len(n)],
    cash_delta = buffer$cash_delta[seq_len(n)],
    position_delta = buffer$position_delta[seq_len(n)],
    realized_pnl = buffer$realized_pnl[seq_len(n)],
    cost_basis_after = buffer$cost_basis_after[seq_len(n)],
    side_code = buffer$side_code[seq_len(n)]
  )
}

k1_output_handler <- function(acc, event) {
  acc$n <- acc$n + 1L
  idx <- acc$n
  acc$buffer$pulse_idx[idx] <- event$pulse_idx
  acc$buffer$instrument_idx[idx] <- event$instrument_idx
  acc$buffer$quantity[idx] <- event$quantity
  acc$buffer$price[idx] <- event$price
  acc$buffer$cash_delta[idx] <- event$cash_delta
  acc$buffer$position_delta[idx] <- event$position_delta
  acc$buffer$realized_pnl[idx] <- event$realized_pnl
  acc$buffer$cost_basis_after[idx] <- event$cost_basis_after
  acc$buffer$side_code[idx] <- event$side_code
  invisible(NULL)
}

k1_event_capacity <- function(n_inst, n_pulses) {
  active_count <- k1_active_count(n_inst)
  n_rebalances <- ((n_pulses - 1L) %/% K1_REBALANCE_INTERVAL) + 1L
  active_count + (n_rebalances - 1L) * active_count * 2L
}

k1_r_fold_impl <- function(bars,
                           initial_cash = 1e6,
                           strategy_boundary = c("R", "static"),
                           output_boundary = c("R", "inline")) {
  strategy_boundary <- match.arg(strategy_boundary)
  output_boundary <- match.arg(output_boundary)

  if (!is.matrix(bars) || !is.double(bars)) {
    stop("bars must be a numeric matrix", call. = FALSE)
  }

  n_inst <- nrow(bars)
  n_pulses <- ncol(bars)
  capacity <- k1_event_capacity(n_inst, n_pulses)

  cash <- initial_cash
  positions <- numeric(n_inst)
  lots <- replicate(
    n_inst,
    list(quantity = numeric(), cost_basis = numeric()),
    simplify = FALSE
  )
  equity <- numeric(n_pulses)

  if (output_boundary == "R") {
    output_acc <- new.env(parent = emptyenv())
    output_acc$n <- 0L
    output_acc$buffer <- k1_event_empty(capacity)
  } else {
    event_buffer <- k1_event_empty(capacity)
    n_events <- 0L
  }

  for (t in seq_len(n_pulses)) {
    prices <- bars[, t]
    pulse_cash <- cash
    pulse_positions <- positions

    targets <- if (strategy_boundary == "R") {
      k1_r_strategy_callback(list(
        pulse_idx = t,
        prices = prices,
        cash = pulse_cash,
        positions = pulse_positions,
        rebalance_due = (t - 1L) %% K1_REBALANCE_INTERVAL == 0L,
        scale = as.character(n_inst),
        initial_cash = initial_cash
      ))
    } else {
      k1_static_targets(t, prices, pulse_cash, pulse_positions, initial_cash)
    }

    deltas <- targets - positions
    fill_idx <- which(deltas != 0)

    for (i in fill_idx) {
      quantity <- deltas[i]
      price <- prices[i]
      cash_delta <- -quantity * price
      side_code <- if (quantity > 0) 1L else -1L

      lot_result <- k1_lot_apply_fill(lots[[i]], quantity, price)
      lots[[i]] <- lot_result$lot
      cash <- cash + cash_delta
      positions[i] <- positions[i] + quantity

      event <- list(
        pulse_idx = t,
        instrument_idx = i,
        quantity = quantity,
        price = price,
        cash_delta = cash_delta,
        position_delta = quantity,
        realized_pnl = lot_result$realized_pnl,
        cost_basis_after = lot_result$cost_basis_after,
        side_code = side_code
      )

      if (output_boundary == "R") {
        k1_output_handler(output_acc, event)
      } else {
        n_events <- n_events + 1L
        event_buffer$pulse_idx[n_events] <- event$pulse_idx
        event_buffer$instrument_idx[n_events] <- event$instrument_idx
        event_buffer$quantity[n_events] <- event$quantity
        event_buffer$price[n_events] <- event$price
        event_buffer$cash_delta[n_events] <- event$cash_delta
        event_buffer$position_delta[n_events] <- event$position_delta
        event_buffer$realized_pnl[n_events] <- event$realized_pnl
        event_buffer$cost_basis_after[n_events] <- event$cost_basis_after
        event_buffer$side_code[n_events] <- event$side_code
      }
    }

    value <- cash
    for (i in seq_len(n_inst)) {
      value <- value + positions[i] * prices[i]
    }
    equity[t] <- value
  }

  events <- if (output_boundary == "R") {
    k1_event_frame(output_acc$buffer, output_acc$n)
  } else {
    k1_event_frame(event_buffer, n_events)
  }

  list(equity = equity, events = events)
}

k1_r_fold_strat_R_handler_R <- function(bars, initial_cash = 1e6) {
  k1_r_fold_impl(bars, initial_cash, "R", "R")
}

k1_r_fold_strat_R_handler_inline <- function(bars, initial_cash = 1e6) {
  k1_r_fold_impl(bars, initial_cash, "R", "inline")
}

k1_r_fold_strat_static_handler_R <- function(bars, initial_cash = 1e6) {
  k1_r_fold_impl(bars, initial_cash, "static", "R")
}

k1_r_fold_strat_static_handler_inline <- function(bars, initial_cash = 1e6) {
  k1_r_fold_impl(bars, initial_cash, "static", "inline")
}
