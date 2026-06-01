use extendr_api::prelude::*;

const K1_REBALANCE_INTERVAL: usize = 5;
const K1_LOT_EMPTY_EPS: f64 = 2.2204460492503131e-16;
const K1_SHORT_GUARD_EPS: f64 = 1.4901161193847656e-08;

#[derive(Clone)]
struct Lot {
    quantity: f64,
    cost_basis: f64,
}

struct EventBuffer {
    pulse_idx: Vec<i32>,
    instrument_idx: Vec<i32>,
    quantity: Vec<f64>,
    price: Vec<f64>,
    cash_delta: Vec<f64>,
    position_delta: Vec<f64>,
    realized_pnl: Vec<f64>,
    cost_basis_after: Vec<f64>,
    side_code: Vec<i32>,
}

struct Event {
    pulse_idx: i32,
    instrument_idx: i32,
    quantity: f64,
    price: f64,
    cash_delta: f64,
    position_delta: f64,
    realized_pnl: f64,
    cost_basis_after: f64,
    side_code: i32,
}

enum StrategyBoundary {
    R(Function),
    Static,
}

enum OutputBoundary {
    R { handler: Function, acc: Robj },
    Inline,
}

impl EventBuffer {
    fn with_capacity(capacity: usize) -> Self {
        Self {
            pulse_idx: Vec::with_capacity(capacity),
            instrument_idx: Vec::with_capacity(capacity),
            quantity: Vec::with_capacity(capacity),
            price: Vec::with_capacity(capacity),
            cash_delta: Vec::with_capacity(capacity),
            position_delta: Vec::with_capacity(capacity),
            realized_pnl: Vec::with_capacity(capacity),
            cost_basis_after: Vec::with_capacity(capacity),
            side_code: Vec::with_capacity(capacity),
        }
    }

    fn push(&mut self, event: &Event) {
        self.pulse_idx.push(event.pulse_idx);
        self.instrument_idx.push(event.instrument_idx);
        self.quantity.push(event.quantity);
        self.price.push(event.price);
        self.cash_delta.push(event.cash_delta);
        self.position_delta.push(event.position_delta);
        self.realized_pnl.push(event.realized_pnl);
        self.cost_basis_after.push(event.cost_basis_after);
        self.side_code.push(event.side_code);
    }

    fn into_robj(self) -> Robj {
        list!(
            pulse_idx = self.pulse_idx,
            instrument_idx = self.instrument_idx,
            quantity = self.quantity,
            price = self.price,
            cash_delta = self.cash_delta,
            position_delta = self.position_delta,
            realized_pnl = self.realized_pnl,
            cost_basis_after = self.cost_basis_after,
            side_code = self.side_code
        )
        .into()
    }
}

#[extendr]
fn ledgrcore_spike_rust_hello() -> &'static str {
    "rust toolchain alive"
}

#[extendr]
fn k1_rust_fold_strat_r_handler_r(
    bars: Robj,
    initial_cash: f64,
    strategy_callback: Function,
    output_handler: Function,
    output_acc: Robj,
) -> Result<Robj> {
    k1_rust_fold_impl(
        bars,
        initial_cash,
        StrategyBoundary::R(strategy_callback),
        OutputBoundary::R {
            handler: output_handler,
            acc: output_acc,
        },
    )
}

#[extendr]
fn k1_rust_fold_strat_r_handler_inline(
    bars: Robj,
    initial_cash: f64,
    strategy_callback: Function,
) -> Result<Robj> {
    k1_rust_fold_impl(
        bars,
        initial_cash,
        StrategyBoundary::R(strategy_callback),
        OutputBoundary::Inline,
    )
}

#[extendr]
fn k1_rust_fold_strat_static_handler_r(
    bars: Robj,
    initial_cash: f64,
    output_handler: Function,
    output_acc: Robj,
) -> Result<Robj> {
    k1_rust_fold_impl(
        bars,
        initial_cash,
        StrategyBoundary::Static,
        OutputBoundary::R {
            handler: output_handler,
            acc: output_acc,
        },
    )
}

#[extendr]
fn k1_rust_fold_strat_static_handler_inline(bars: Robj, initial_cash: f64) -> Result<Robj> {
    k1_rust_fold_impl(
        bars,
        initial_cash,
        StrategyBoundary::Static,
        OutputBoundary::Inline,
    )
}

fn k1_rust_fold_impl(
    bars: Robj,
    initial_cash: f64,
    strategy_boundary: StrategyBoundary,
    output_boundary: OutputBoundary,
) -> Result<Robj> {
    let dims: Vec<i32> = bars
        .dim()
        .ok_or_else(|| Error::Other("bars must have matrix dimensions".to_string()))?
        .iter()
        .map(|x| x.inner())
        .collect();
    if dims.len() != 2 {
        return Err(Error::Other("bars must be a two-dimensional matrix".to_string()));
    }

    let n_inst = dims[0] as usize;
    let n_pulses = dims[1] as usize;
    let bars_slice = bars
        .as_real_slice()
        .ok_or_else(|| Error::Other("bars must be a numeric matrix".to_string()))?;
    let capacity = k1_event_capacity(n_inst, n_pulses)?;

    let mut cash = initial_cash;
    let mut positions = vec![0.0_f64; n_inst];
    let mut lots = vec![Vec::<Lot>::new(); n_inst];
    let mut equity = vec![0.0_f64; n_pulses];
    let mut event_buffer = EventBuffer::with_capacity(capacity);

    for t in 0..n_pulses {
        let prices = column_prices(bars_slice, n_inst, t);
        let pulse_cash = cash;
        let pulse_positions = positions.clone();

        let targets = match &strategy_boundary {
            StrategyBoundary::R(callback) => {
                let ctx = list!(
                    pulse_idx = (t + 1) as i32,
                    prices = prices.clone(),
                    cash = pulse_cash,
                    positions = pulse_positions.clone(),
                    rebalance_due = t % K1_REBALANCE_INTERVAL == 0,
                    scale = n_inst.to_string(),
                    initial_cash = initial_cash
                );
                callback
                    .call(pairlist!(ctx = ctx))?
                    .as_real_vector()
                    .ok_or_else(|| {
                        Error::Other("R strategy callback must return a numeric vector".to_string())
                    })?
            }
            StrategyBoundary::Static => {
                k1_static_targets(t + 1, &prices, &pulse_positions, initial_cash)?
            }
        };

        for i in 0..n_inst {
            let quantity = targets[i] - positions[i];
            if quantity == 0.0 {
                continue;
            }

            let price = prices[i];
            let cash_delta = -quantity * price;
            let side_code = if quantity > 0.0 { 1 } else { -1 };
            let (realized_pnl, cost_basis_after) =
                k1_lot_apply_fill(&mut lots[i], quantity, price)?;

            cash += cash_delta;
            positions[i] += quantity;

            let event = Event {
                pulse_idx: (t + 1) as i32,
                instrument_idx: (i + 1) as i32,
                quantity,
                price,
                cash_delta,
                position_delta: quantity,
                realized_pnl,
                cost_basis_after,
                side_code,
            };

            match &output_boundary {
                OutputBoundary::R { handler, acc } => {
                    let event_list = list!(
                        pulse_idx = event.pulse_idx,
                        instrument_idx = event.instrument_idx,
                        quantity = event.quantity,
                        price = event.price,
                        cash_delta = event.cash_delta,
                        position_delta = event.position_delta,
                        realized_pnl = event.realized_pnl,
                        cost_basis_after = event.cost_basis_after,
                        side_code = event.side_code
                    );
                    handler.call(pairlist!(acc = acc.clone(), event = event_list))?;
                }
                OutputBoundary::Inline => event_buffer.push(&event),
            }
        }

        let mut value = cash;
        for i in 0..n_inst {
            value += positions[i] * prices[i];
        }
        equity[t] = value;
    }

    let events = match output_boundary {
        OutputBoundary::R { .. } => r!(NULL),
        OutputBoundary::Inline => event_buffer.into_robj(),
    };

    Ok(list!(equity = equity, events = events).into())
}

fn column_prices(bars: &[f64], n_inst: usize, t: usize) -> Vec<f64> {
    let start = t * n_inst;
    bars[start..start + n_inst].to_vec()
}

fn k1_active_count(n_inst: usize) -> Result<usize> {
    match n_inst {
        50 => Ok(14),
        100 => Ok(27),
        1000 => Ok(259),
        _ => Err(Error::Other(format!(
            "unsupported K1 fixture instrument count: {}",
            n_inst
        ))),
    }
}

fn k1_event_capacity(n_inst: usize, n_pulses: usize) -> Result<usize> {
    let active_count = k1_active_count(n_inst)?;
    let n_rebalances = ((n_pulses - 1) / K1_REBALANCE_INTERVAL) + 1;
    Ok(active_count + (n_rebalances - 1) * active_count * 2)
}

fn k1_static_targets(
    pulse_idx: usize,
    prices: &[f64],
    positions: &[f64],
    initial_cash: f64,
) -> Result<Vec<f64>> {
    let n_inst = prices.len();
    let active_count = k1_active_count(n_inst)?;

    if (pulse_idx - 1) % K1_REBALANCE_INTERVAL != 0 {
        return Ok(positions.to_vec());
    }

    let rebalance_idx = (pulse_idx - 1) / K1_REBALANCE_INTERVAL;
    let start = if rebalance_idx % 2 == 0 {
        0
    } else {
        active_count
    };
    let target_notional = initial_cash / active_count as f64;
    let mut targets = vec![0.0_f64; n_inst];

    for i in start..start + active_count {
        targets[i] = target_notional / prices[i];
    }

    Ok(targets)
}

fn k1_lot_apply_fill(lot: &mut Vec<Lot>, quantity: f64, price: f64) -> Result<(f64, f64)> {
    let mut realized_pnl = 0.0_f64;

    if quantity > 0.0 {
        lot.push(Lot {
            quantity,
            cost_basis: price,
        });
    } else if quantity < 0.0 {
        let mut remaining = -quantity;
        while remaining > 0.0 && !lot.is_empty() {
            let take = remaining.min(lot[0].quantity);
            realized_pnl += take * (price - lot[0].cost_basis);
            lot[0].quantity -= take;
            remaining -= take;

            if lot[0].quantity <= K1_LOT_EMPTY_EPS {
                lot.remove(0);
            }
        }

        if remaining > K1_SHORT_GUARD_EPS {
            return Err(Error::Other(
                "K1 Rust reference does not support short lot creation".to_string(),
            ));
        }
    }

    let cost_basis_after = if lot.is_empty() {
        0.0
    } else {
        let mut numerator = 0.0_f64;
        let mut denominator = 0.0_f64;
        for open_lot in lot.iter() {
            numerator += open_lot.quantity * open_lot.cost_basis;
            denominator += open_lot.quantity;
        }
        numerator / denominator
    };

    Ok((realized_pnl, cost_basis_after))
}

extendr_module! {
    mod ledgrcorespike_rust;
    fn ledgrcore_spike_rust_hello;
    fn k1_rust_fold_strat_r_handler_r;
    fn k1_rust_fold_strat_r_handler_inline;
    fn k1_rust_fold_strat_static_handler_r;
    fn k1_rust_fold_strat_static_handler_inline;
}
