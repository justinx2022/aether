use std::collections::HashMap;
use std::sync::RwLock;
use crate::extensions::models::{ProviderManifest, StreamResolutionRequest, StreamSource};

pub struct ProviderRegistry {
    manifests: RwLock<HashMap<String, ProviderManifest>>,
}

impl ProviderRegistry {
    pub fn new() -> Self {
        Self {
            manifests: RwLock::new(HashMap::new()),
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

    /// Resolves stream candidates across registered providers for a given target.
    pub fn resolve_streams_mock(&self, req: &StreamResolutionRequest) -> Vec<StreamSource> {
        let mut streams = Vec::new();
        let safe_title = req.title.replace(' ', "+");

        // Primary 1080p stream
        streams.push(StreamSource {
            url: format!("https://aether.stream/v1/{}/master.m3u8", safe_title),
            quality: "1080p".to_string(),
            format: "hls".to_string(),
            provider_name: Some("Aether Direct".to_string()),
            headers: HashMap::new(),
            subtitles: Vec::new(),
        });

        // 4K Ultra HD Stream (if movie or high-profile title)
        if req.media_type == "movie" {
            streams.push(StreamSource {
                url: format!("https://aether.stream/v1/{}/4k.m3u8", safe_title),
                quality: "4K".to_string(),
                format: "hls".to_string(),
                provider_name: Some("Aether Ultra".to_string()),
                headers: HashMap::new(),
                subtitles: Vec::new(),
            });
        }

        streams
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

        let streams = registry.resolve_streams_mock(&req);
        assert!(!streams.is_empty());
        assert!(streams.iter().any(|s| s.quality == "4K"));
        assert!(streams.iter().any(|s| s.quality == "1080p"));
    }
}

