//! Standalone Aether Core service binary.
//! Run with: `aether-core [port]` (default port: 8765)

use aether_core::service::server;

fn main() {
    let port: u16 = std::env::args()
        .nth(1)
        .and_then(|p| p.parse().ok())
        .unwrap_or(8765);

    let rt = tokio::runtime::Runtime::new().expect("Failed to create tokio runtime");

    rt.block_on(async {
        if let Err(e) = server::start_service(port).await {
            eprintln!("Failed to start Aether Core service: {}", e);
            std::process::exit(1);
        }
    });
}
