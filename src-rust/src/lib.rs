use extendr_api::prelude::*;

#[extendr]
fn ledgrcore_spike_rust_hello() -> &'static str {
    "rust toolchain alive"
}

extendr_module! {
    mod ledgrcorespike_rust;
    fn ledgrcore_spike_rust_hello;
}
