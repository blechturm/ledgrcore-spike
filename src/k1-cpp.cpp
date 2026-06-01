#include <cpp11.hpp>
#include <algorithm>
#include <deque>
#include <string>
#include <vector>

using namespace cpp11::literals;

namespace {

constexpr int K1_REBALANCE_INTERVAL = 5;
constexpr double K1_LOT_EMPTY_EPS = 2.2204460492503131e-16;
constexpr double K1_SHORT_GUARD_EPS = 1.4901161193847656e-08;

struct Lot {
  double quantity;
  double cost_basis;
};

struct EventBuffer {
  std::vector<int> pulse_idx;
  std::vector<int> instrument_idx;
  std::vector<double> quantity;
  std::vector<double> price;
  std::vector<double> cash_delta;
  std::vector<double> position_delta;
  std::vector<double> realized_pnl;
  std::vector<double> cost_basis_after;
  std::vector<int> side_code;

  explicit EventBuffer(size_t capacity) {
    pulse_idx.reserve(capacity);
    instrument_idx.reserve(capacity);
    quantity.reserve(capacity);
    price.reserve(capacity);
    cash_delta.reserve(capacity);
    position_delta.reserve(capacity);
    realized_pnl.reserve(capacity);
    cost_basis_after.reserve(capacity);
    side_code.reserve(capacity);
  }
};

struct FillResult {
  double realized_pnl;
  double cost_basis_after;
};

int active_count(int n_inst) {
  switch (n_inst) {
  case 50:
    return 14;
  case 100:
    return 27;
  case 1000:
    return 259;
  default:
    cpp11::stop("unsupported K1 fixture instrument count");
  }
}

size_t event_capacity(int n_inst, int n_pulses) {
  int active = active_count(n_inst);
  int n_rebalances = ((n_pulses - 1) / K1_REBALANCE_INTERVAL) + 1;
  return static_cast<size_t>(active + (n_rebalances - 1) * active * 2);
}

std::vector<double> static_targets(int pulse_idx,
                                   const double* prices,
                                   const std::vector<double>& positions,
                                   double initial_cash) {
  int n_inst = static_cast<int>(positions.size());
  int active = active_count(n_inst);

  if ((pulse_idx - 1) % K1_REBALANCE_INTERVAL != 0) {
    return positions;
  }

  int rebalance_idx = (pulse_idx - 1) / K1_REBALANCE_INTERVAL;
  int start = rebalance_idx % 2 == 0 ? 0 : active;
  double target_notional = initial_cash / active;
  std::vector<double> targets(n_inst, 0.0);

  for (int i = start; i < start + active; ++i) {
    targets[i] = target_notional / prices[i];
  }

  return targets;
}

FillResult apply_fill(std::deque<Lot>& lot, double quantity, double price) {
  double realized_pnl = 0.0;

  if (quantity > 0.0) {
    lot.push_back({quantity, price});
  } else if (quantity < 0.0) {
    double remaining = -quantity;
    while (remaining > 0.0 && !lot.empty()) {
      double take = std::min(remaining, lot.front().quantity);
      realized_pnl += take * (price - lot.front().cost_basis);
      lot.front().quantity -= take;
      remaining -= take;

      if (lot.front().quantity <= K1_LOT_EMPTY_EPS) {
        lot.pop_front();
      }
    }

    if (remaining > K1_SHORT_GUARD_EPS) {
      cpp11::stop("K1 C++ reference does not support short lot creation");
    }
  }

  double cost_basis_after = 0.0;
  if (!lot.empty()) {
    double numerator = 0.0;
    double denominator = 0.0;
    for (const auto& open_lot : lot) {
      numerator += open_lot.quantity * open_lot.cost_basis;
      denominator += open_lot.quantity;
    }
    cost_basis_after = numerator / denominator;
  }

  return {realized_pnl, cost_basis_after};
}

void push_event(EventBuffer& buffer,
                int pulse_idx,
                int instrument_idx,
                double quantity,
                double price,
                double cash_delta,
                double realized_pnl,
                double cost_basis_after,
                int side_code) {
  buffer.pulse_idx.push_back(pulse_idx);
  buffer.instrument_idx.push_back(instrument_idx);
  buffer.quantity.push_back(quantity);
  buffer.price.push_back(price);
  buffer.cash_delta.push_back(cash_delta);
  buffer.position_delta.push_back(quantity);
  buffer.realized_pnl.push_back(realized_pnl);
  buffer.cost_basis_after.push_back(cost_basis_after);
  buffer.side_code.push_back(side_code);
}

cpp11::writable::data_frame event_frame(const EventBuffer& buffer) {
  return cpp11::writable::data_frame({
      "pulse_idx"_nm = buffer.pulse_idx,
      "instrument_idx"_nm = buffer.instrument_idx,
      "quantity"_nm = buffer.quantity,
      "price"_nm = buffer.price,
      "cash_delta"_nm = buffer.cash_delta,
      "position_delta"_nm = buffer.position_delta,
      "realized_pnl"_nm = buffer.realized_pnl,
      "cost_basis_after"_nm = buffer.cost_basis_after,
      "side_code"_nm = buffer.side_code,
  });
}

cpp11::writable::list fold_impl(cpp11::doubles_matrix<> bars,
                                double initial_cash,
                                cpp11::function strategy_callback,
                                cpp11::function output_handler,
                                cpp11::sexp output_acc,
                                bool strategy_is_r,
                                bool output_is_r) {
  int n_inst = static_cast<int>(bars.nrow());
  int n_pulses = static_cast<int>(bars.ncol());
  size_t capacity = event_capacity(n_inst, n_pulses);

  double cash = initial_cash;
  std::vector<double> positions(n_inst, 0.0);
  std::vector<std::deque<Lot>> lots(n_inst);
  std::vector<double> equity(n_pulses, 0.0);
  EventBuffer event_buffer(capacity);

  for (int t = 0; t < n_pulses; ++t) {
    std::vector<double> prices(n_inst);
    for (int i = 0; i < n_inst; ++i) {
      prices[i] = bars(i, t);
    }
    const double* prices_ptr = prices.data();
    double pulse_cash = cash;
    std::vector<double> targets;

    if (strategy_is_r) {
      cpp11::writable::list ctx({
          "pulse_idx"_nm = t + 1,
          "prices"_nm = prices,
          "cash"_nm = pulse_cash,
          "positions"_nm = positions,
          "rebalance_due"_nm = t % K1_REBALANCE_INTERVAL == 0,
          "scale"_nm = std::to_string(n_inst),
          "initial_cash"_nm = initial_cash,
      });
      cpp11::doubles callback_targets(strategy_callback(ctx));
      targets.assign(callback_targets.begin(), callback_targets.end());
    } else {
      targets = static_targets(t + 1, prices_ptr, positions, initial_cash);
    }

    for (int i = 0; i < n_inst; ++i) {
      double quantity = targets[i] - positions[i];
      if (quantity == 0.0) {
        continue;
      }

      double price = prices[i];
      double cash_delta = -quantity * price;
      int side_code = quantity > 0.0 ? 1 : -1;
      FillResult fill = apply_fill(lots[i], quantity, price);

      cash += cash_delta;
      positions[i] += quantity;

      if (output_is_r) {
        cpp11::writable::list event({
            "pulse_idx"_nm = t + 1,
            "instrument_idx"_nm = i + 1,
            "quantity"_nm = quantity,
            "price"_nm = price,
            "cash_delta"_nm = cash_delta,
            "position_delta"_nm = quantity,
            "realized_pnl"_nm = fill.realized_pnl,
            "cost_basis_after"_nm = fill.cost_basis_after,
            "side_code"_nm = side_code,
        });
        output_handler(output_acc, event);
      } else {
        push_event(event_buffer,
                   t + 1,
                   i + 1,
                   quantity,
                   price,
                   cash_delta,
                   fill.realized_pnl,
                   fill.cost_basis_after,
                   side_code);
      }
    }

    double value = cash;
    for (int i = 0; i < n_inst; ++i) {
      value += positions[i] * prices[i];
    }
    equity[t] = value;
  }

  if (output_is_r) {
    return cpp11::writable::list({"equity"_nm = equity, "events"_nm = R_NilValue});
  }

  return cpp11::writable::list(
      {"equity"_nm = equity, "events"_nm = event_frame(event_buffer)});
}

} // namespace

[[cpp11::register]]
cpp11::writable::list k1_cpp_fold_strat_R_handler_R(cpp11::doubles_matrix<> bars,
                                                    double initial_cash,
                                                    cpp11::function strategy_callback,
                                                    cpp11::function output_handler,
                                                    cpp11::sexp output_acc) {
  return fold_impl(
      bars, initial_cash, strategy_callback, output_handler, output_acc, true, true);
}

[[cpp11::register]]
cpp11::writable::list k1_cpp_fold_strat_R_handler_inline(
    cpp11::doubles_matrix<> bars,
    double initial_cash,
    cpp11::function strategy_callback) {
  return fold_impl(bars,
                   initial_cash,
                   strategy_callback,
                   R_NilValue,
                   R_NilValue,
                   true,
                   false);
}

[[cpp11::register]]
cpp11::writable::list k1_cpp_fold_strat_static_handler_R(
    cpp11::doubles_matrix<> bars,
    double initial_cash,
    cpp11::function output_handler,
    cpp11::sexp output_acc) {
  return fold_impl(bars,
                   initial_cash,
                   R_NilValue,
                   output_handler,
                   output_acc,
                   false,
                   true);
}

[[cpp11::register]]
cpp11::writable::list k1_cpp_fold_strat_static_handler_inline(
    cpp11::doubles_matrix<> bars,
    double initial_cash) {
  return fold_impl(
      bars, initial_cash, R_NilValue, R_NilValue, R_NilValue, false, false);
}
