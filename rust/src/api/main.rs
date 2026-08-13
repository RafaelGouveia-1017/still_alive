use crate::api::data::logging::init_rust_logging;
use flutter_rust_bridge::frb;

/// `#[frb(init)]` causes this to run as part of `RustLib.init()`.
#[frb(init)]
pub fn init_app() {
    init_rust_logging();
}

pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}
