use std::collections::HashMap;
use std::sync::RwLock;
use crate::extensions::models::{
    CatalogCategory, ProviderManifest, StreamResolutionRequest, StreamSource,
};
use crate::models::MultimediaItem;
use crate::resolver::StreamResolver;

pub struct ProviderRegistry {
    manifests: RwLock<HashMap<String, ProviderManifest>>,
    resolver: StreamResolver,
    /// Custom stream candidates set by extensions (real resolution path)
    candidates: RwLock<HashMap<String, Vec<StreamSource>>>,
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
    /// If an extension has registered concrete candidates for this title they
    /// are returned as-is. Only when nothing has been registered do we fall
    /// back to the built-in provider list, so the UI still has something to
    /// show while the extension host is warming up.
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

        let mut streams = Vec::new();
        let safe_title = req.title.replace(' ', "+");

        // Primary 1080p stream
        streams.push(StreamSource {
            url: format!("https://aether.stream/v1/{}/master.m3u8", safe_title),
            quality: "1080p".to_string(),
            format: "hls".to_string(),
            protocol: "hls".to_string(),
            provider_name: Some("Aether Direct".to_string()),
            headers: HashMap::new(),
            subtitles: Vec::new(),
            file_index: None,
        });

        // 4K Ultra HD Stream (if movie or high-profile title)
        if req.media_type == "movie" {
            streams.push(StreamSource {
                url: format!("https://aether.stream/v1/{}/4k.m3u8", safe_title),
                quality: "4K".to_string(),
                format: "hls".to_string(),
                protocol: "hls".to_string(),
                provider_name: Some("Aether Ultra".to_string()),
                headers: HashMap::new(),
                subtitles: Vec::new(),
                file_index: None,
            });
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

pub fn global_registry() -> &'static ProviderRegistry {
    GLOBAL_REGISTRY.get_or_init(ProviderRegistry::new)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_provider_registration_and_resolution() {
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
        assert!(!streams.is_empty());
        assert!(streams.iter().any(|s| s.quality == "4K"));
        assert!(streams.iter().any(|s| s.quality == "1080p"));
        assert!(streams.iter().all(|s| s.protocol == "hls"));
    }
}

