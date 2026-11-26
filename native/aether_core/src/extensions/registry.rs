use std::collections::HashMap;
use std::sync::RwLock;
use std::time::{Duration, Instant};
use crate::extensions::models::{
    CatalogCategory, ProviderManifest, StreamResolutionRequest, StreamSource,
};
use crate::models::MultimediaItem;
use crate::resolver::StreamResolver;

/// How long native extraction results stay cached. Repeat playback of the
/// same title within the TTL is instant (no network round-trips).
const NATIVE_CACHE_TTL: Duration = Duration::from_secs(300);

pub struct ProviderRegistry {
    manifests: RwLock<HashMap<String, ProviderManifest>>,
    resolver: StreamResolver,
    /// Custom stream candidates set by extensions (real resolution path)
    candidates: RwLock<HashMap<String, Vec<StreamSource>>>,
    /// Cached results of native HLS extraction, keyed by request shape
    native_cache: RwLock<HashMap<String, (Instant, Vec<StreamSource>)>>,
    /// Home-screen shelves populated by the extension host
    catalogue: RwLock<Vec<CatalogCategory>>,
}

impl Default for ProviderRegistry {
    fn default() -> Self {
        Self::new()
    }
}

impl ProviderRegistry {
    pub fn new() -> Self {
        Self {
            manifests: RwLock::new(HashMap::new()),
            resolver: StreamResolver::new(),
            candidates: RwLock::new(HashMap::new()),
            native_cache: RwLock::new(HashMap::new()),
            catalogue: RwLock::new(Vec::new()),
        }
    }

    /// Registers a new Aether Native Extension manifest.
    pub fn register(&self, manifest: ProviderManifest) {
        if let Ok(mut lock) = self.manifests.write() {
            lock.insert(manifest.id.clone(), manifest);
        }
    }

    /// Returns all registered provider manifests.
    pub fn list(&self) -> Vec<ProviderManifest> {
        if let Ok(lock) = self.manifests.read() {
            lock.values().cloned().collect()
        } else {
            Vec::new()
        }
    }

    /// Returns stream candidates from registered providers for a given target
    /// without probing/resolving them. Callers should use the resolver to
    /// pick the best one.
    ///
    /// Resolution order:
    /// 1. Concrete candidates registered by an extension (returned as-is).
    /// 2. Native HLS extraction in the Rust engine (real .m3u8 links from
    ///    VidZee / VidRock / VidSpark / VixSrc / VidApi), cached for the TTL.
    /// 3. Empty — no fake placeholder URLs, so the resolver falls through to
    ///    other providers instead of handing the player a dead link.
    pub fn get_stream_candidates(&self, req: &StreamResolutionRequest) -> Vec<StreamSource> {
        if let Some(real) = self
            .candidates
            .read()
            .ok()
            .and_then(|lock| lock.get(&req.title).cloned())
            .filter(|v| !v.is_empty())
        {
            return real;
        }

        self.native_candidates(req)
    }

    /// Native HLS extraction with a TTL cache so repeat playback is instant.
    fn native_candidates(&self, req: &StreamResolutionRequest) -> Vec<StreamSource> {
        let key = native_cache_key(req);
        if let Some((at, streams)) = self
            .native_cache
            .read()
            .ok()
            .and_then(|lock| lock.get(&key).cloned())
        {
            if at.elapsed() < NATIVE_CACHE_TTL {
                return streams;
            }
        }

        let streams = crate::extensions::extractors::extract_all_streams(req);
        if let Ok(mut lock) = self.native_cache.write() {
            lock.insert(key, (Instant::now(), streams.clone()));
        }
        streams
    }

    /// Resolves the best stream for a given target: probes all candidates in
    /// parallel (HLS via HTTP probe, torrent via torrserver) and returns the
    /// fastest healthy one plus fallbacks.
    ///
    /// Candidates come from registered extensions (future: QuickJS host).
    /// When no extension has provided candidates yet, falls back to the
    /// built-in provider list so the system still produces a working stream
    /// URL for compatibility.
    pub fn resolve_best_stream(
        &self,
        req: &StreamResolutionRequest,
        token: Option<String>,
    ) -> crate::resolver::ResolvedStream {
        let candidates = self.get_stream_candidates(req);
        self.resolver.resolve(candidates, token)
    }

    /// Set custom stream candidates from a registered extension or provider.
    /// This is the path for real (non-mock) stream resolution.
    pub fn set_stream_candidates(
        &self,
        key: &str,
        candidates: Vec<StreamSource>,
    ) {
        if let Ok(mut lock) = self.candidates.write() {
            lock.insert(key.to_string(), candidates);
        }
    }

    /// Get stream candidates that have been explicitly set.
    pub fn get_custom_stream_candidates(&self) -> Vec<(String, Vec<StreamSource>)> {
        if let Ok(lock) = self.candidates.read() {
            lock.iter().map(|(k, v)| (k.clone(), v.clone())).collect()
        } else {
            Vec::new()
        }
    }

    /// Replace the home-screen catalogue with shelves produced by extensions.
    pub fn set_catalogue(&self, categories: Vec<CatalogCategory>) {
        if let Ok(mut lock) = self.catalogue.write() {
            *lock = categories;
        }
    }

    /// Home-screen shelves, in display order.
    pub fn home_categories(&self) -> Vec<CatalogCategory> {
        self.catalogue
            .read()
            .map(|lock| lock.clone())
            .unwrap_or_default()
    }

    /// Every item currently known to the catalogue, de-duplicated by id.
    pub fn all_items(&self) -> Vec<MultimediaItem> {
        let categories = self.home_categories();
        let mut seen = std::collections::HashSet::new();
        let mut items = Vec::new();
        for category in categories {
            for item in category.items {
                if seen.insert(item.id.clone()) {
                    items.push(item);
                }
            }
        }
        items
    }
}

static GLOBAL_REGISTRY: std::sync::OnceLock<ProviderRegistry> = std::sync::OnceLock::new();

/// Stable cache key for a resolution request.
fn native_cache_key(req: &StreamResolutionRequest) -> String {
    format!(
        "{}|{}|{}|{}|{}|{}",
        req.title.trim().to_lowercase(),
        req.media_type,
        req.season.unwrap_or(0),
        req.episode.unwrap_or(0),
        req.tmdb_id.unwrap_or(0),
        req.imdb_id.as_deref().unwrap_or("")
    )
}

pub fn global_registry() -> &'static ProviderRegistry {
    GLOBAL_REGISTRY.get_or_init(ProviderRegistry::new)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_provider_registration() {
        let registry = ProviderRegistry::new();
        let manifest = ProviderManifest {
            id: "aether.cinema".to_string(),
            name: "Aether Cinema".to_string(),
            version: "1.0.0".to_string(),
            description: Some("Native Ultra-HD Cinema Stream Engine".to_string()),
            author: Some("Aether Project".to_string()),
            icon_url: None,
        };

        registry.register(manifest);
        let list = registry.list();
        assert_eq!(list.len(), 1);
        assert_eq!(list[0].id, "aether.cinema");
    }

    #[test]
    fn test_custom_candidates_take_priority_over_native() {
        let registry = ProviderRegistry::new();
        let custom = vec![StreamSource {
            url: "https://custom.example/master.m3u8".to_string(),
            quality: "1080p".to_string(),
            format: "hls".to_string(),
            protocol: "hls".to_string(),
            provider_name: Some("Custom".to_string()),
            headers: HashMap::new(),
            subtitles: Vec::new(),
            file_index: None,
        }];
        registry.set_stream_candidates("Inception", custom.clone());

        let req = StreamResolutionRequest {
            title: "Inception".to_string(),
            media_type: "movie".to_string(),
            season: None,
            episode: None,
            year: Some(2010),
            imdb_id: Some("tt1375666".to_string()),
            tmdb_id: Some(27205),
        };
        let streams = registry.get_stream_candidates(&req);
        assert_eq!(streams.len(), 1);
        assert_eq!(streams[0].url, "https://custom.example/master.m3u8");
    }

    #[test]
    fn test_native_cache_key_stable() {
        let a = StreamResolutionRequest {
            title: "Inception".to_string(),
            media_type: "movie".to_string(),
            season: None,
            episode: None,
            year: Some(2010),
            imdb_id: Some("tt1375666".to_string()),
            tmdb_id: Some(27205),
        };
        let mut b = a.clone();
        b.year = None;
        assert_eq!(native_cache_key(&a), native_cache_key(&b));
        b.tmdb_id = Some(999);
        assert_ne!(native_cache_key(&a), native_cache_key(&b));
    }
}

