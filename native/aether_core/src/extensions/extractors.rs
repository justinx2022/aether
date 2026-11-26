//! Native HLS link extractors.
//!
//! Ports the high-speed HLS extractors from Justin's Catalogue (plugin.js)
//! into the Rust engine so real .m3u8 links are produced natively, without
//! waiting for the QuickJS extension host. All providers are queried in
//! parallel on a shared, pooled HTTP client; results are de-duplicated and
//! ranked (fast multi-CDN HLS first, legacy fallbacks last).

use std::sync::OnceLock;
use std::time::Duration;

use aes_gcm::aead::{Aead, KeyInit, Payload};
use aes_gcm::{Aes256Gcm, Key, Nonce};
use base64::prelude::*;
use regex::Regex;

use crate::extensions::host_api::AetherParser;
use crate::extensions::models::{StreamResolutionRequest, StreamSource};

const USER_AGENT: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";
const VIDROCK_KEY_HEX: &str =
    "7f3e9c2a8b5d1f4e6a9c3b7d2e5f8a1c4b6d9e2f5a8c1b4d7e9f2a5c8b1d4e7f";
const VIDSPARK_PLAYER_KEY: &str =
    "3a67e8866ae1d2bb9e81fe7f73315a56eb3bdf5e3e755c7554c8be6910aa6b13";

/// Shared pooled HTTP client: one connection pool for every extractor,
/// aggressive timeouts so a dead provider can never stall playback.
fn http_client() -> &'static reqwest::blocking::Client {
    static CLIENT: OnceLock<reqwest::blocking::Client> = OnceLock::new();
    CLIENT.get_or_init(|| {
        reqwest::blocking::Client::builder()
            .user_agent(USER_AGENT)
            .connect_timeout(Duration::from_secs(3))
            .timeout(Duration::from_secs(6))
            .redirect(reqwest::redirect::Policy::limited(4))
            .pool_max_idle_per_host(8)
            .tcp_nodelay(true)
            .build()
            .unwrap_or_else(|_| reqwest::blocking::Client::new())
    })
}

fn get_json(url: &str, headers: &[(&str, &str)]) -> Option<serde_json::Value> {
    let mut req = http_client().get(url).header("Accept", "application/json, text/plain, */*");
    for (k, v) in headers {
        req = req.header(*k, *v);
    }
    let resp = req.send().ok()?;
    if !resp.status().is_success() {
        return None;
    }
    resp.json::<serde_json::Value>().ok()
}

fn get_text(url: &str, headers: &[(&str, &str)]) -> Option<String> {
    let mut req = http_client().get(url);
    for (k, v) in headers {
        req = req.header(*k, *v);
    }
    let resp = req.send().ok()?;
    if !resp.status().is_success() {
        return None;
    }
    resp.text().ok()
}

/// `movie/{tmdb}` or `tv/{tmdb}/{season}/{episode}` path fragment shared by
/// VidZee, VidRock and VidSpark.
fn media_path(req: &StreamResolutionRequest) -> Option<String> {
    let tmdb = req.tmdb_id?;
    Some(match req.media_type.as_str() {
        "movie" => format!("movie/{tmdb}"),
        _ => format!(
            "tv/{tmdb}/{}/{}",
            req.season.unwrap_or(1),
            req.episode.unwrap_or(1)
        ),
    })
}

fn is_media_url(url: &str) -> bool {
    url.starts_with("http")
}

fn is_hls_url(url: &str) -> bool {
    !url.contains(".mp4") && !url.contains(".mkv")
}

fn parse_quality(url: &str) -> String {
    static RE: OnceLock<Regex> = OnceLock::new();
    let re = RE.get_or_init(|| Regex::new(r"(2160|1080|720|480|360)").unwrap());
    re.captures(url)
        .and_then(|c| c.get(1))
        .map(|m| format!("{}p", m.as_str()))
        .unwrap_or_else(|| "Auto".to_string())
}

fn quality_weight(quality: &str) -> u32 {
    quality
        .trim_end_matches('p')
        .parse::<u32>()
        .unwrap_or(0)
}

/// Lower rank = better. Mirrors the JS plugin ordering:
/// 0 VidZee/VidRock multi-CDN, 1 VidSpark, 2 VixSrc, 3 VidApi.
fn provider_rank(name: &str) -> u8 {
    if name.starts_with("VidZee") || name.starts_with("VidRock") {
        0
    } else if name.starts_with("VidSpark") {
        1
    } else if name.starts_with("VixSrc") {
        2
    } else if name.starts_with("VidApi") {
        3
    } else {
        4
    }
}

// ---------------------------------------------------------------------------
// 1. VidZee multi-server HLS (Vercetti / NGCloud / Tik CDNs)
// ---------------------------------------------------------------------------

fn extract_vidzee_server(req: &StreamResolutionRequest, server: &str) -> Vec<StreamSource> {
    let Some(path) = media_path(req) else {
        return Vec::new();
    };
    let url = format!(
        "https://core.vidzee.wtf/streams/{path}?s={}",
        urlencoding::encode(server)
    );
    let headers = [
        ("Referer", "https://player.vidzee.wtf/"),
        ("Origin", "https://player.vidzee.wtf"),
    ];
    let Some(stream_url) = get_json(&url, &headers)
        .and_then(|j| j.get("url").and_then(|u| u.as_str()).map(str::to_string))
        .filter(|u| is_media_url(u))
    else {
        return Vec::new();
    };

    let label = server.trim_start_matches("v6:");
    let hls = is_hls_url(&stream_url);
    vec![StreamSource {
        url: stream_url,
        quality: "1080p".to_string(),
        format: if hls { "hls" } else { "mp4" }.to_string(),
        protocol: if hls { "hls" } else { "direct" }.to_string(),
        provider_name: Some(format!("VidZee {label}")),
        headers: headers
            .iter()
            .map(|(k, v)| (k.to_string(), v.to_string()))
            .chain(std::iter::once((
                "User-Agent".to_string(),
                USER_AGENT.to_string(),
            )))
            .collect(),
        subtitles: Vec::new(),
        file_index: None,
    }]
}

// ---------------------------------------------------------------------------
// 2. VidRock multi-CDN HLS (AES-256-GCM encrypted URLs)
// ---------------------------------------------------------------------------

/// Decrypts a VidRock AES-256-GCM encrypted stream URL.
/// Payload layout: base64url(raw) where raw = 12-byte IV || ciphertext || tag.
pub fn decrypt_vidrock_url(enc: &str) -> Option<String> {
    let mut b64 = enc.replace('-', "+").replace('_', "/");
    while b64.len() % 4 != 0 {
        b64.push('=');
    }
    let raw = BASE64_STANDARD.decode(b64.as_bytes()).ok()?;
    if raw.len() < 28 {
        return None;
    }
    let (iv, ct) = raw.split_at(12);

    let key_bytes = decode_hex(VIDROCK_KEY_HEX)?;
    let key = Key::<Aes256Gcm>::from_slice(&key_bytes);
    let cipher = Aes256Gcm::new(key);
    let nonce = Nonce::from_slice(iv); // 12 bytes
    let plain = cipher
        .decrypt(nonce, Payload { msg: ct, aad: &[] })
        .ok()?;
    let plain = String::from_utf8(plain).ok()?;
    plain.starts_with("http").then_some(plain)
}

fn decode_hex(s: &str) -> Option<Vec<u8>> {
    if s.len() % 2 != 0 {
        return None;
    }
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16).ok())
        .collect()
}

fn extract_vidrock(req: &StreamResolutionRequest) -> Vec<StreamSource> {
    let Some(path) = media_path(req) else {
        return Vec::new();
    };
    let url = format!("https://vidrock.net/api/{path}");
    let headers = [
        ("Referer", "https://vidrock.net/"),
        ("Origin", "https://vidrock.net"),
    ];
    let Some(json) = get_json(&url, &headers) else {
        return Vec::new();
    };

    let mut out = Vec::new();
    for server in ["Nova", "Atlas", "Astra", "Lyra", "Elara"] {
        let Some(enc) = json
            .get(server)
            .and_then(|s| s.get("url"))
            .and_then(|u| u.as_str())
        else {
            continue;
        };
        let Some(plain) = decrypt_vidrock_url(enc).filter(|p| p.contains(".m3u8")) else {
            continue;
        };
        out.push(StreamSource {
            url: plain,
            quality: "1080p".to_string(),
            format: "hls".to_string(),
            protocol: "hls".to_string(),
            provider_name: Some(format!("VidRock {server}")),
            headers: [
                ("User-Agent", USER_AGENT),
                ("Referer", "https://vidrock.net/"),
                ("Origin", "https://vidrock.net"),
            ]
            .iter()
            .map(|(k, v)| (k.to_string(), v.to_string()))
            .collect(),
            subtitles: Vec::new(),
            file_index: None,
        });
    }
    out
}

// ---------------------------------------------------------------------------
// 3. VidSpark (Vidora Cloudflare Workers CDN)
// ---------------------------------------------------------------------------

fn extract_vidspark(req: &StreamResolutionRequest) -> Vec<StreamSource> {
    let Some(path) = media_path(req) else {
        return Vec::new();
    };
    let url = format!("https://vidspark.to/api/vidora/v1/{path}");
    let headers = [
        ("Referer", "https://vidspark.to/"),
        ("x-player-key", VIDSPARK_PLAYER_KEY),
    ];
    let Some(json) = get_json(&url, &headers) else {
        return Vec::new();
    };

    let Some(sources) = json.get("sources").and_then(|s| s.as_array()) else {
        return Vec::new();
    };
    sources
        .iter()
        .filter_map(|s| s.get("url").and_then(|u| u.as_str()))
        .filter(|u| is_media_url(u))
        .map(|u| StreamSource {
            url: u.to_string(),
            quality: "1080p".to_string(),
            format: "hls".to_string(),
            protocol: "hls".to_string(),
            provider_name: Some("VidSpark Cloudflare".to_string()),
            headers: [
                ("User-Agent", USER_AGENT),
                ("Referer", "https://vidspark.to/"),
            ]
            .iter()
            .map(|(k, v)| (k.to_string(), v.to_string()))
            .collect(),
            subtitles: Vec::new(),
            file_index: None,
        })
        .collect()
}

// ---------------------------------------------------------------------------
// 4. VixSrc multi-audio master HLS
// ---------------------------------------------------------------------------

fn extract_vixsrc(req: &StreamResolutionRequest) -> Vec<StreamSource> {
    let domain = "https://vixsrc.to";
    let mut ids: Vec<String> = Vec::new();
    if let Some(tmdb) = req.tmdb_id {
        ids.push(tmdb.to_string());
    }
    if let Some(imdb) = &req.imdb_id {
        if !ids.iter().any(|i| i == imdb) {
            ids.push(imdb.clone());
        }
    }
    if ids.is_empty() {
        return Vec::new();
    }

    for id in ids {
        let api_path = match req.media_type.as_str() {
            "movie" => format!("/api/movie/{id}"),
            _ => format!(
                "/api/tv/{id}/{}/{}",
                req.season.unwrap_or(1),
                req.episode.unwrap_or(1)
            ),
        };
        let Some(json) = get_json(&format!("{domain}{api_path}"), &[("Referer", domain), ("Origin", domain)])
        else {
            continue;
        };
        let Some(src) = json.get("src").and_then(|s| s.as_str()) else {
            continue;
        };
        let embed_url = if src.starts_with("http") {
            src.to_string()
        } else {
            format!("{domain}{src}")
        };
        let Some(html) = get_text(&embed_url, &[("Referer", domain)]) else {
            continue;
        };

        let token = AetherParser::extract_first(&html, r#"token["']\s*:\s*["']([^"']+)"#)
            .or_else(|| AetherParser::extract_first(&html, r#"token\s*=\s*["']([^"']+)"#));
        let expires = AetherParser::extract_first(&html, r#"expires["']\s*:\s*["']([^"']+)"#)
            .or_else(|| AetherParser::extract_first(&html, r#"expires\s*=\s*["']([^"']+)"#));
        let playlist = AetherParser::extract_first(&html, r#"url\s*:\s*["']([^"']+)"#)
            .or_else(|| AetherParser::extract_first(&html, r#"source\s*:\s*["']([^"']+)"#));

        if let (Some(token), Some(expires), Some(playlist)) = (token, expires, playlist) {
            let sep = if playlist.contains('?') { '&' } else { '?' };
            let master = format!("{playlist}{sep}token={token}&expires={expires}&h=1");
            return vec![StreamSource {
                url: master,
                quality: "1080p".to_string(),
                format: "hls".to_string(),
                protocol: "hls".to_string(),
                provider_name: Some("VixSrc Multi-Audio".to_string()),
                headers: [
                    ("User-Agent", USER_AGENT),
                    ("Referer", embed_url.as_str()),
                    ("Origin", domain),
                ]
                .iter()
                .map(|(k, v)| (k.to_string(), v.to_string()))
                .collect(),
                subtitles: Vec::new(),
                file_index: None,
            }];
        }
    }
    Vec::new()
}

// ---------------------------------------------------------------------------
// 5. VidApi legacy fallback
// ---------------------------------------------------------------------------

fn extract_vidapi(req: &StreamResolutionRequest) -> Vec<StreamSource> {
    let mut id_param = req
        .tmdb_id
        .map(|t| t.to_string())
        .or_else(|| req.imdb_id.clone());
    if let Some(imdb) = &req.imdb_id {
        if id_param.is_none() {
            id_param = Some(format!("imdb={imdb}"));
        }
    }
    let Some(id_param) = id_param else {
        return Vec::new();
    };

    let media = if req.media_type == "movie" { "movie" } else { "tv" };
    let tv_query = if req.media_type == "movie" {
        String::new()
    } else {
        format!(
            "&season={}&episode={}",
            req.season.unwrap_or(1),
            req.episode.unwrap_or(1)
        )
    };
    let url = format!(
        "https://streamdata.vaplayer.ru/api.php?{id_param}&type={media}{tv_query}"
    );
    let headers = [
        ("Referer", "https://brightpathsignals.com/"),
        ("Origin", "https://brightpathsignals.com"),
    ];
    let Some(json) = get_json(&url, &headers) else {
        return Vec::new();
    };

    let status_ok = json
        .get("status_code")
        .map(|s| s == &serde_json::json!(200) || s.as_str() == Some("200"))
        .unwrap_or(false);
    if !status_ok {
        return Vec::new();
    }
    let Some(list) = json
        .pointer("/data/stream_urls")
        .map(|v| match v {
            serde_json::Value::Array(a) => a.clone(),
            serde_json::Value::Object(o) => o.values().cloned().collect(),
            _ => Vec::new(),
        })
    else {
        return Vec::new();
    };

    list.iter()
        .filter_map(|v| v.as_str())
        .filter(|u| u.contains(".m3u8") || u.contains(".mp4"))
        .map(|u| {
            let hls = is_hls_url(u);
            StreamSource {
                url: u.to_string(),
                quality: parse_quality(u),
                format: if hls { "hls" } else { "mp4" }.to_string(),
                protocol: if hls { "hls" } else { "direct" }.to_string(),
                provider_name: Some("VidApi Server".to_string()),
                headers: [("User-Agent", USER_AGENT)]
                    .iter()
                    .map(|(k, v)| (k.to_string(), v.to_string()))
                    .collect(),
                subtitles: Vec::new(),
                file_index: None,
            }
        })
        .collect()
}

// ---------------------------------------------------------------------------
// Parallel orchestration
// ---------------------------------------------------------------------------

/// Runs every native extractor in parallel and returns de-duplicated,
/// ranked HLS/direct links. Never panics; a failing provider simply
/// contributes nothing.
pub fn extract_all_streams(req: &StreamResolutionRequest) -> Vec<StreamSource> {
    let vidzee_servers: &[&str] = if req.media_type == "movie" {
        &["peak", "dcloud", "tik"]
    } else {
        &["dcloud", "tik", "v6:English"]
    };

    let mut results: Vec<Vec<StreamSource>> = std::thread::scope(|scope| {
        let mut handles = Vec::new();
        for server in vidzee_servers {
            handles.push(scope.spawn(move || extract_vidzee_server(req, server)));
        }
        handles.push(scope.spawn(|| extract_vidrock(req)));
        handles.push(scope.spawn(|| extract_vidspark(req)));
        handles.push(scope.spawn(|| extract_vixsrc(req)));
        handles.push(scope.spawn(|| extract_vidapi(req)));

        handles
            .into_iter()
            .filter_map(|h| h.join().ok())
            .collect::<Vec<_>>()
    });

    let mut streams = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for batch in results.drain(..) {
        for stream in batch {
            if seen.insert(stream.url.clone()) {
                streams.push(stream);
            }
        }
    }

    // Fast multi-CDN HLS first, then quality descending within a rank.
    streams.sort_by(|a, b| {
        let ra = provider_rank(a.provider_name.as_deref().unwrap_or(""));
        let rb = provider_rank(b.provider_name.as_deref().unwrap_or(""));
        ra.cmp(&rb)
            .then(quality_weight(&b.quality).cmp(&quality_weight(&a.quality)))
    });
    streams
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_vidrock_decrypt_roundtrip() {
        use aes_gcm::aead::Aead;
        let key_bytes = decode_hex(VIDROCK_KEY_HEX).unwrap();
        let key = Key::<Aes256Gcm>::from_slice(&key_bytes);
        let cipher = Aes256Gcm::new(key);
        let iv = [7u8; 12];
        let plain = "https://vercetti.org/stream/master.m3u8";
        let ct = cipher
            .encrypt(Nonce::from_slice(&iv), plain.as_bytes())
            .unwrap();

        // raw = iv || ciphertext||tag, base64url-encoded like VidRock does
        let mut raw = iv.to_vec();
        raw.extend_from_slice(&ct);
        let enc = BASE64_URL_SAFE_NO_PAD.encode(raw);

        let decrypted = decrypt_vidrock_url(&enc).unwrap();
        assert_eq!(decrypted, plain);
    }

    #[test]
    fn test_decrypt_rejects_garbage() {
        assert!(decrypt_vidrock_url("not-valid-base64!!!").is_none());
        assert!(decrypt_vidrock_url("c2hvcnQ=").is_none()); // too short
    }

    #[test]
    fn test_rank_ordering() {
        let streams = vec![
            StreamSource {
                url: "https://x/vidapi.m3u8".to_string(),
                quality: "1080p".to_string(),
                format: "hls".to_string(),
                protocol: "hls".to_string(),
                provider_name: Some("VidApi Server".to_string()),
                headers: Default::default(),
                subtitles: Vec::new(),
                file_index: None,
            },
            StreamSource {
                url: "https://x/vidzee.m3u8".to_string(),
                quality: "1080p".to_string(),
                format: "hls".to_string(),
                protocol: "hls".to_string(),
                provider_name: Some("VidZee peak".to_string()),
                headers: Default::default(),
                subtitles: Vec::new(),
                file_index: None,
            },
        ];
        // Simulate the sort used by extract_all_streams without network.
        let mut streams = streams;
        streams.sort_by(|a, b| {
            let ra = provider_rank(a.provider_name.as_deref().unwrap_or(""));
            let rb = provider_rank(b.provider_name.as_deref().unwrap_or(""));
            ra.cmp(&rb)
                .then(quality_weight(&b.quality).cmp(&quality_weight(&a.quality)))
        });
        assert_eq!(streams[0].provider_name.as_deref(), Some("VidZee peak"));
        assert_eq!(provider_rank("VidSpark Cloudflare"), 1);
        assert_eq!(provider_rank("VixSrc Multi-Audio"), 2);
        assert_eq!(provider_rank("VidApi Server"), 3);
    }

    #[test]
    fn test_parse_quality() {
        assert_eq!(parse_quality("https://cdn/x/1080/index.m3u8"), "1080p");
        assert_eq!(parse_quality("https://cdn/x/2160/index.m3u8"), "2160p");
        assert_eq!(parse_quality("https://cdn/x/index.m3u8"), "Auto");
    }
}
