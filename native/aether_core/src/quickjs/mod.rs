//! QuickJS-NG engine wrapper — executes JavaScript from `.sky` extension
//! bundles without going through Flutter.
//!
//! This module is behind the `service` feature flag and provides:
//! 1. Raw FFI bindings to QuickJS-NG (`ffi`)
//! 2. A safe Rust wrapper around them (`context`)
//! 3. Extension loading and eval helpers (`extension_host`)

#[cfg(feature = "service")]
pub mod ffi;
#[cfg(feature = "service")]
pub mod context;
#[cfg(feature = "service")]
pub mod extension_host;

#[cfg(feature = "service")]
pub use context::{QuickJSContext, QuickJSRuntime};
#[cfg(feature = "service")]
pub use extension_host::{ExtensionLoadError, ExtensionRunner};
