pub mod discovery;
pub mod extensions;
pub mod ffi;
pub mod models;
pub mod resolver;
pub mod search;
pub mod torrent;

#[cfg(feature = "quickjs")]
pub mod quickjs;

#[cfg(feature = "service")]
pub mod service;

pub use discovery::DiscoveryEngine;
pub use extensions::*;
pub use ffi::*;
pub use models::*;
pub use resolver::StreamResolver;
pub use search::FuzzySearchEngine;
pub use torrent::{probe_torrent, resolve_torrent_source, TorrentProbeResult, TorrServerClient};

