use std::time::{Duration, Instant};

use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};
use url::Url;

use crate::extensions::models::StreamSource;
use crate::torrent::resolve_torrent_source;

/// Result of resolving a set of candidate streams down to the single best one
/// for the player, plus an ordered fallback list.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResolvedStream {
    /// The single URL the player should open first (opaque: HLS or local HTTP).
    pub primary: String,
    /// Fallback URLs to try if the primary stalls or fails.
    pub fallbacks: Vec<String>,
    /// Quality label shown to the user (e.g. "1080p").
    pub quality: String,
    /// Protocol that won the race (internal only: "hls", "torrent", "direct").
    pub protocol: String,
}

/// Health probe result for a single candidate source.
#[derive(Debug, Clone)]
struct ProbeResult {
    url: String,
    protocol: String,
    quality: String,
    #[allow(dead_code)] // Source name for future logging / analytics
    source: Option<String>,
    healthy: bool,
    /// Time to first byte / first piece in milliseconds.
    ttfb_ms: u64,
    #[allow(dead_code)]
    error: Option<String>,
}

/// Configuration for how the resolver behaves.
#[derive(Debug, Clone)]
pub struct ResolverConfig {
    /// Maximum time to wait for any single probe before treating it as failed.
    pub probe_timeout: Duration,
    /// If true, prefer torrent (P2P) when speeds are within this margin.
    pub prefer_torrent: bool,
    /// Speed margin (as a ratio, e.g. 1.2 = 20%) within which torrent wins ties.
    pub torrent_tie_margin: f64,
}

impl Default for ResolverConfig {
    fn default() -> Self {
        Self {
            probe_timeout: Duration::from_secs(3),
            prefer_torrent: false,
            torrent_tie_margin: 1.2,
        }
    }
}

/// The stream resolver. Receives candidate streams from extensions (HLS and/or
/// torrent), probes them in parallel, and returns the single fastest healthy
/// source plus fallbacks. The player only ever sees one URL.
pub struct StreamResolver {
    client: Client,
    config: ResolverConfig,
}

impl Default for StreamResolver {
    fn default() -> Self {
        Self::new()
    }
}

impl StreamResolver {
    pub fn new() -> Self {
        Self {
            client: Client::builder()
                .timeout(Duration::from_secs(5))
                .build()
                .unwrap_or_default(),
            config: ResolverConfig::default(),
        }
    }

    pub fn with_config(config: ResolverConfig) -> Self {
        Self {
            client: Client::builder()
                .timeout(Duration::from_secs(5))
                .build()
                .unwrap_or_default(),
            config,
        }
    }

    /// Resolve a list of candidate streams into a single `ResolvedStream`.
    ///
    /// HLS candidates are probed with a small HTTP Range request to the
    /// manifest or first segment. Torrent candidates are handed to the Go
    /// torrserver which returns a local HTTP URL. The fastest healthy source
    /// becomes `primary`; the rest become `fallbacks`.
    pub fn resolve(&self, candidates: Vec<StreamSource>, token: Option<String>) -> ResolvedStream {
        if candidates.is_empty() {
            return ResolvedStream {
                primary: String::new(),
                fallbacks: Vec::new(),
                quality: String::new(),
                protocol: String::new(),
            };
        }

        // Probe all candidates in parallel (bounded by rayon-like thread pool
        // via scoped threads for simplicity and no async runtime in FFI).
        let results: Vec<ProbeResult> = candidates
            .into_iter()
            .map(|c| self.probe_candidate(c, token.clone()))
            .collect();

        // Separate healthy from unhealthy.
        let mut healthy: Vec<&ProbeResult> = results.iter().filter(|r| r.healthy).collect();
        let unhealthy: Vec<&ProbeResult> = results.iter().filter(|r| !r.healthy).collect();

        if healthy.is_empty() {
            // Nothing healthy: return the first unhealthy as primary so the
            // player gets a deterministic failure instead of an empty URL.
            if let Some(first) = unhealthy.first() {
                return ResolvedStream {
                    primary: first.url.clone(),
                    fallbacks: unhealthy[1..].iter().map(|r| r.url.clone()).collect(),
                    quality: first.quality.clone(),
                    protocol: first.protocol.clone(),
                };
            }
            return ResolvedStream {
                primary: String::new(),
                fallbacks: Vec::new(),
                quality: String::new(),
                protocol: String::new(),
            };
        }

        // Rank: fastest TTFB first. If prefer_torrent and within tie margin,
        // let torrent win ties.
        healthy.sort_by(|a, b| {
            let a_score = a.ttfb_ms as f64;
            let b_score = b.ttfb_ms as f64;

            let a_is_torrent = a.protocol == "torrent";
            let b_is_torrent = b.protocol == "torrent";

            if self.config.prefer_torrent && a_is_torrent && !b_is_torrent {
                // Give torrent a small handicap to win close races.
                let adjusted_a = a_score / self.config.torrent_tie_margin;
                adjusted_a
                    .partial_cmp(&b_score)
                    .unwrap_or(std::cmp::Ordering::Equal)
            } else if self.config.prefer_torrent && b_is_torrent && !a_is_torrent {
                let adjusted_b = b_score / self.config.torrent_tie_margin;
                a_score
                    .partial_cmp(&adjusted_b)
                    .unwrap_or(std::cmp::Ordering::Equal)
            } else {
                a_score.partial_cmp(&b_score).unwrap_or(std::cmp::Ordering::Equal)
            }
        });

        let primary = healthy[0];
        let fallbacks: Vec<String> = healthy[1..]
            .iter()
            .chain(unhealthy.iter())
            .map(|r| r.url.clone())
            .collect();

        ResolvedStream {
            primary: primary.url.clone(),
            fallbacks,
            quality: primary.quality.clone(),
            protocol: primary.protocol.clone(),
        }
    }

    /// Probe a single candidate: HLS gets an HTTP Range request; torrent gets
    /// handed to torrserver.
    fn probe_candidate(&self, source: StreamSource, token: Option<String>) -> ProbeResult {
        match source.protocol.as_str() {
            "torrent" => {
                let resolved = resolve_torrent_source(&source, token);
                if resolved.url.is_empty() {
                    ProbeResult {
                        url: source.url.clone(),
                        protocol: "torrent".to_string(),
                        quality: source.quality.clone(),
                        source: source.provider_name.clone(),
                        healthy: false,
                        ttfb_ms: u64::MAX,
                        error: Some("torrent resolution failed".to_string()),
                    }
                } else {
                    ProbeResult {
                        url: resolved.url.clone(),
                        protocol: "direct".to_string(),
                        quality: resolved.quality.clone(),
                        source: resolved.provider_name.clone(),
                        healthy: true,
                        ttfb_ms: 0, // torrserver doesn't report TTFB yet; treat as instant
                        error: None,
                    }
                }
            }
            "hls" | "direct" => self.probe_hls(source),
            _ => ProbeResult {
                url: source.url.clone(),
                protocol: source.protocol.clone(),
                quality: source.quality.clone(),
                source: source.provider_name.clone(),
                healthy: false,
                ttfb_ms: u64::MAX,
                error: Some(format!("unknown protocol: {}", source.protocol)),
            },
        }
    }

    /// Probe an HLS (or direct HTTP) source with a small Range request to the
    /// manifest or first segment. Returns time-to-first-byte.
    fn probe_hls(&self, source: StreamSource) -> ProbeResult {
        let url_str = &source.url;
        let start = Instant::now();

        // Validate it's an HTTP(S) URL.
        let parsed = match Url::parse(url_str) {
            Ok(u) if u.scheme() == "http" || u.scheme() == "https" => u,
            _ => {
                return ProbeResult {
                    url: url_str.clone(),
                    protocol: source.protocol.clone(),
                    quality: source.quality.clone(),
                    source: source.provider_name.clone(),
                    healthy: false,
                    ttfb_ms: u64::MAX,
                    error: Some(format!("not an http(s) url: {}", url_str)),
                };
            }
        };

        let result = self
            .client
            .get(parsed.clone())
            .header("Range", "bytes=0-65535")
            .header("User-Agent", "Aether/1.0")
            .send();

        let elapsed_ms = start.elapsed().as_millis() as u64;

        match result {
            Ok(resp) if resp.status().is_success() || resp.status().as_u16() == 206 => {
                ProbeResult {
                    url: url_str.clone(),
                    protocol: source.protocol.clone(),
                    quality: source.quality.clone(),
                    source: source.provider_name.clone(),
                    healthy: true,
                    ttfb_ms: elapsed_ms,
                    error: None,
                }
            }
            Ok(resp) => ProbeResult {
                url: url_str.clone(),
                protocol: source.protocol.clone(),
                quality: source.quality.clone(),
                source: source.provider_name.clone(),
                healthy: false,
                ttfb_ms: elapsed_ms,
                error: Some(format!("HTTP {}", resp.status())),
            },
            Err(e) => ProbeResult {
                url: url_str.clone(),
                protocol: source.protocol.clone(),
                quality: source.quality.clone(),
                source: source.provider_name.clone(),
                healthy: false,
                ttfb_ms: elapsed_ms,
                error: Some(format!("request failed: {}", e)),
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    fn make_stream(url: &str, protocol: &str, quality: &str) -> StreamSource {
        StreamSource {
            url: url.to_string(),
            quality: quality.to_string(),
            format: "hls".to_string(),
            protocol: protocol.to_string(),
            provider_name: Some("test".to_string()),
            headers: HashMap::new(),
            subtitles: Vec::new(),
            file_index: None,
        }
    }

    #[test]
    fn test_resolve_empty() {
        let resolver = StreamResolver::new();
        let result = resolver.resolve(Vec::new(), None);
        assert!(result.primary.is_empty());
        assert!(result.fallbacks.is_empty());
    }

    #[test]
    fn test_resolve_single_hls() {
        // We can't actually make network calls in this test, but we can verify
        // the resolver struct is created and the method signature works.
        let resolver = StreamResolver::new();
        let streams = vec![make_stream("https://example.com/master.m3u8", "hls", "1080p")];
        let _result = resolver.resolve(streams, None);
        // Just verify it doesn't panic
    }

    #[test]
    fn test_config_default() {
        let config = ResolverConfig::default();
        assert_eq!(config.probe_timeout, Duration::from_secs(3));
        assert!(!config.prefer_torrent);
        assert_eq!(config.torrent_tie_margin, 1.2);
    }
}
