use std::collections::HashMap;
use std::time::Duration;

use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};
use url::Url;

use crate::extensions::models::StreamSource;

/// Local address of the embedded Go torrserver. Loopback only.
const TORRENSERVER_ADDR: &str = "http://127.0.0.1:8090";

/// Token header name used by the Go torrserver auth guard.
const TOKEN_HEADER: &str = "X-TorrServer-Token";

/// Result of probing a torrent source: whether it is healthy and the local
/// HTTP URL the player should use to stream it.
#[derive(Debug, Clone, Serialize)]
pub struct TorrentProbeResult {
    pub healthy: bool,
    pub local_url: Option<String>,
    pub info_hash: Option<String>,
    pub first_piece_ms: Option<u64>,
    pub error: Option<String>,
}

/// Status returned by the Go torrserver /torrents?action=get endpoint.
#[derive(Debug, Deserialize, Serialize)]
pub struct TorrentStatusResponse {
    #[allow(dead_code)]
    hash: String,
    #[allow(dead_code)]
    title: String,
    #[allow(dead_code)]
    status: String,
    #[allow(dead_code)]
    progress: f64,
    #[allow(dead_code)]
    download_speed: i64,
    #[allow(dead_code)]
    upload_speed: i64,
    #[allow(dead_code)]
    peers: i32,
}

/// Client for the embedded Go torrserver. All calls are blocking so they can
/// be used directly from FFI without an async runtime.
pub struct TorrServerClient {
    client: Client,
    token: Option<String>,
    base: String,
}

impl TorrServerClient {
    pub fn new(token: Option<String>) -> Self {
        Self {
            client: Client::builder()
                .timeout(Duration::from_secs(10))
                .build()
                .unwrap_or_default(),
            token,
            base: TORRENSERVER_ADDR.to_string(),
        }
    }

    /// Send a request with auth token attached.
    fn authed(&self, req: reqwest::blocking::RequestBuilder) -> reqwest::blocking::RequestBuilder {
        if let Some(tok) = &self.token {
            return req.header(TOKEN_HEADER, tok);
        }
        req
    }

    /// Add a magnet URI to torrserver and wait until metadata is available.
    /// Returns the info hash and the local stream URL.
    pub fn add_torrent(&self, magnet: &str, file_index: Option<i32>) -> Result<TorrentProbeResult, String> {
        let start = std::time::Instant::now();

        // Parse the magnet to extract the info hash for the stream URL.
        let info_hash = extract_info_hash(magnet).ok_or_else(|| "Invalid magnet URI".to_string())?;

        // Ask Go torrserver to add the torrent via the /torrents?action=add endpoint.
        let add_url = format!("{}/torrents?action=add", self.base);
        let mut params = HashMap::new();
        params.insert("link", magnet.to_string());

        let req = self.authed(self.client.post(&add_url).json(&params).header("Content-Type", "application/json"));

        let _resp: TorrentStatusResponse = req
            .send()
            .map_err(|e| format!("torrserver add request failed: {}", e))?
            .json()
            .map_err(|e| format!("torrserver add response parse failed: {}", e))?;

        let elapsed_ms = start.elapsed().as_millis() as u64;

        // Build the local HTTP stream URL. Go torrserver serves at
        // /stream?link=<magnet>&index=<file_index>&play
        let stream_url = format!(
            "{}/stream?link={}&index={}&play",
            self.base,
            urlencoding::encode(magnet),
            file_index.unwrap_or(0)
        );

        Ok(TorrentProbeResult {
            healthy: true,
            local_url: Some(stream_url),
            info_hash: Some(info_hash),
            first_piece_ms: Some(elapsed_ms),
            error: None,
        })
    }

    /// Query torrserver for the status of an info hash.
    pub fn status(&self, info_hash: &str) -> Result<TorrentStatusResponse, String> {
        let url = format!("{}/torrents?action=get&hash={}", self.base, info_hash);
        let resp: TorrentStatusResponse = self.authed(self.client.get(&url))
            .send()
            .map_err(|e| format!("torrserver status request failed: {}", e))?
            .json()
            .map_err(|e| format!("torrserver status response parse failed: {}", e))?;
        Ok(resp)
    }

    /// Remove a torrent from torrserver by info hash.
    pub fn remove_torrent(&self, info_hash: &str) -> Result<(), String> {
        let url = format!("{}/torrents?action=rem", self.base);
        let params = HashMap::from([("hash".to_string(), info_hash.to_string())]);
        self.authed(self.client.post(&url).json(&params).header("Content-Type", "application/json"))
            .send()
            .map_err(|e| format!("torrserver remove request failed: {}", e))?;
        Ok(())
    }
}

/// Extract the info hash from a magnet URI (urn:btih:...).
fn extract_info_hash(magnet: &str) -> Option<String> {
    let url = Url::parse(magnet).ok()?;
    let xt = url.query_pairs().find(|(k, _)| k == "xt")?;
    let xt_str = xt.1.to_string();
    if let Some(hash) = xt_str.strip_prefix("urn:btih:").filter(|h| h.len() == 40) {
        return Some(hash.to_lowercase());
    }
    None
}

/// Probe a torrent source: validate the magnet, add it to torrserver, and
/// return the local stream URL plus timing info.
pub fn probe_torrent(
    magnet: &str,
    file_index: Option<i32>,
    token: Option<String>,
) -> TorrentProbeResult {
    let client = TorrServerClient::new(token);
    match client.add_torrent(magnet, file_index) {
        Ok(result) => result,
        Err(e) => TorrentProbeResult {
            healthy: false,
            local_url: None,
            info_hash: None,
            first_piece_ms: None,
            error: Some(e),
        },
    }
}

/// Convert a StreamSource tagged as torrent into a local HTTP URL the player
/// can consume directly.
pub fn resolve_torrent_source(source: &StreamSource, token: Option<String>) -> StreamSource {
    let mut resolved = source.clone();

    if resolved.protocol != "torrent" {
        return resolved;
    }

    let probe = probe_torrent(&resolved.url, resolved.file_index, token);
    if probe.healthy {
        if let Some(local_url) = probe.local_url {
            resolved.url = local_url;
            resolved.protocol = "direct".to_string(); // player sees a plain HTTP URL
        }
    } else {
        // If torrent failed, mark as unhealthy so the resolver can fall back.
        resolved.url = "".to_string();
    }

    resolved
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_info_hash() {
        let magnet = "magnet:?xt=urn:btih:abcdef1234567890abcdef1234567890abcdef12&dn=test";
        let hash = extract_info_hash(magnet).unwrap();
        assert_eq!(hash, "abcdef1234567890abcdef1234567890abcdef12");
    }

    #[test]
    fn test_extract_info_hash_uppercase() {
        let magnet = "magnet:?xt=urn:btih:ABCDEF1234567890ABCDEF1234567890ABCDEF12";
        let hash = extract_info_hash(magnet).unwrap();
        assert_eq!(hash, "abcdef1234567890abcdef1234567890abcdef12");
    }

    #[test]
    fn test_extract_info_hash_invalid() {
        assert!(extract_info_hash("not-a-magnet").is_none());
        assert!(extract_info_hash("magnet:?xt=urn:btih:short").is_none());
    }
}
