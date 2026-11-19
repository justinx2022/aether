//! Standalone service mode: runs `aether_core` as a standalone binary with an
//! HTTP/JSON API instead of being called via FFI from Flutter.
//!
//! This module is behind the `service` feature flag and provides a minimal
//! JSON-over-HTTP API that mirrors the FFI surface. It lets any frontend
//! (Compose Multiplatform, Tauri, web, CLI, ...) call `aether_core` without
//! linking against the shared library.

pub mod server {
    use std::sync::Arc;

    use axum::{
        extract::{Query, State},
        http::StatusCode,
        response::{IntoResponse, Json},
        routing::{get, post},
        Router,
    };
    use serde_json::json;
    use tower_http::cors::CorsLayer;

    use crate::extensions::models::{
        CatalogCategory, ProviderManifest, StreamResolutionRequest, StreamSource,
    };
    use crate::extensions::global_registry;
    use crate::resolver::StreamResolver;
    use crate::torrent::{probe_torrent, TorrServerClient};

    struct ServiceState {
        resolver: StreamResolver,
    }

    /// Start the standalone service on the given port. Blocks until the server
    /// stops.
    pub async fn start_service(port: u16) -> Result<(), std::io::Error> {
        let state = Arc::new(ServiceState {
            resolver: StreamResolver::new(),
        });

        let app = Router::new()
            // Health / metadata
            .route("/health", get(get_health))
            .route("/version", get(get_version))
            // Catalogue (populated by the extension host)
            .route("/catalogue/home", get(get_catalogue_home))
            .route("/catalogue/set", post(post_catalogue_set))
            .route("/catalogue/providers", get(get_providers))
            .route("/catalogue/search", post(post_catalogue_search))
            .route("/providers/register", post(post_provider_register))
            // Search / discovery primitives
            .route("/search/fuzzy", post(post_fuzzy_search))
            .route("/discovery/filter", post(post_filter_and_sort))
            // Crypto
            .route("/crypto/sha256", post(post_crypto_sha256))
            // Stream resolver
            .route("/stream/resolve", post(post_resolve_streams))
            .route("/stream/resolve/title", post(post_resolve_title))
            .route("/stream/candidates", post(post_stream_candidates))
            // Torrent control
            .route("/torrent/add", post(post_torrent_add))
            .route("/torrent/status", get(get_torrent_status))
            .route("/torrent/remove", post(post_torrent_remove))
            // Local frontends run in a browser sandbox (Wasm) and need CORS.
            // The listener is loopback-only, so a permissive policy is safe.
            .layer(CorsLayer::permissive())
            .with_state(state);

        let listener = tokio::net::TcpListener::bind(("127.0.0.1", port)).await?;
        println!("Aether Core service listening on http://127.0.0.1:{}", port);
        axum::serve(listener, app).await?;
        Ok(())
    }

    // === Health / metadata ===

    async fn get_health() -> impl IntoResponse {
        Json(json!({ "status": "ok", "version": env!("CARGO_PKG_VERSION") }))
    }

    async fn get_version() -> impl IntoResponse {
        Json(json!({
            "version": env!("CARGO_PKG_VERSION"),
            "protocol_version": 1,
        }))
    }

    // === Catalogue ===

    #[derive(serde::Deserialize)]
    struct CatalogueSetRequest {
        categories: Vec<CatalogCategory>,
    }

    async fn post_catalogue_set(
        Json(req): Json<CatalogueSetRequest>,
    ) -> impl IntoResponse {
        let registry = global_registry();
        registry.set_catalogue(req.categories);
        Json(json!({ "ok": true, "categories": registry.home_categories().len() }))
    }

    async fn get_catalogue_home() -> impl IntoResponse {
        Json(global_registry().home_categories())
    }

    async fn get_providers() -> impl IntoResponse {
        Json(global_registry().list())
    }

    #[derive(serde::Deserialize)]
    struct CatalogueSearchRequest {
        query: String,
        #[serde(default = "default_min_score")]
        min_score: i32,
    }

    fn default_min_score() -> i32 {
        60
    }

    async fn post_catalogue_search(
        Json(req): Json<CatalogueSearchRequest>,
    ) -> impl IntoResponse {
        let items = global_registry().all_items();
        let results =
            crate::search::FuzzySearchEngine::search_parallel(&items, &req.query, req.min_score);
        Json(results)
    }

    async fn post_provider_register(
        Json(manifest): Json<ProviderManifest>,
    ) -> impl IntoResponse {
        global_registry().register(manifest);
        Json(json!({ "ok": true }))
    }

    // === Search / discovery primitives ===

    #[derive(serde::Deserialize)]
    struct FuzzySearchRequest {
        query: String,
        items: Vec<crate::models::MultimediaItem>,
        #[serde(default)]
        min_score: i32,
    }

    async fn post_fuzzy_search(
        Json(req): Json<FuzzySearchRequest>,
    ) -> impl IntoResponse {
        let results = crate::search::FuzzySearchEngine::search_parallel(
            &req.items,
            &req.query,
            req.min_score,
        );
        Json(results)
    }

    #[derive(serde::Deserialize)]
    struct FilterAndSortRequest {
        items: Vec<crate::models::MultimediaItem>,
        filter: crate::models::FilterCriteria,
    }

    async fn post_filter_and_sort(
        Json(req): Json<FilterAndSortRequest>,
    ) -> impl IntoResponse {
        let results =
            crate::discovery::DiscoveryEngine::filter_and_sort(&req.items, &req.filter);
        Json(results)
    }

    // === Crypto ===

    async fn post_crypto_sha256(Json(input): Json<String>) -> impl IntoResponse {
        Json(crate::extensions::AetherCrypto::sha256(input.as_bytes()))
    }

    // === Stream resolver ===

    #[derive(serde::Deserialize)]
    struct ResolveStreamsRequest {
        candidates: Vec<StreamSource>,
        #[serde(default)]
        token: Option<String>,
    }

    async fn post_resolve_streams(
        State(state): State<Arc<ServiceState>>,
        Json(req): Json<ResolveStreamsRequest>,
    ) -> impl IntoResponse {
        Json(state.resolver.resolve(req.candidates, req.token))
    }

    /// Resolve by title: lets the extension host supply real candidates and
    /// then probes them. Falls back to the built-in providers when the host
    /// has not registered anything for this title yet.
    async fn post_resolve_title(
        State(state): State<Arc<ServiceState>>,
        Json(req): Json<StreamResolutionRequest>,
    ) -> impl IntoResponse {
        let candidates = global_registry().get_stream_candidates(&req);
        Json(state.resolver.resolve(candidates, None))
    }

    async fn post_stream_candidates(
        Json(req): Json<StreamResolutionRequest>,
    ) -> impl IntoResponse {
        Json(global_registry().get_stream_candidates(&req))
    }

    // === Torrent control ===

    #[derive(serde::Deserialize)]
    struct TorrentAddRequest {
        magnet: String,
        #[serde(default)]
        file_index: Option<i32>,
    }

    async fn post_torrent_add(Json(req): Json<TorrentAddRequest>) -> impl IntoResponse {
        let result = probe_torrent(&req.magnet, req.file_index, None);
        Json(result)
    }

    #[derive(serde::Deserialize)]
    struct TorrentStatusRequest {
        hash: String,
    }

    async fn get_torrent_status(
        Query(req): Query<TorrentStatusRequest>,
    ) -> impl IntoResponse {
        let client = TorrServerClient::new(None);
        match client.status(&req.hash) {
            Ok(status) => (StatusCode::OK, Json(status)).into_response(),
            Err(_) => (
                StatusCode::NOT_FOUND,
                Json(json!({ "ok": false, "error": "torrent not found" })),
            )
                .into_response(),
        }
    }

    #[derive(serde::Deserialize)]
    struct TorrentRemoveRequest {
        hash: String,
    }

    async fn post_torrent_remove(
        Json(req): Json<TorrentRemoveRequest>,
    ) -> impl IntoResponse {
        let client = TorrServerClient::new(None);
        match client.remove_torrent(&req.hash) {
            Ok(()) => Json(json!({ "ok": true })),
            Err(e) => Json(json!({ "ok": false, "error": e.to_string() })),
        }
    }
}
