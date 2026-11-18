use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use crate::models::MultimediaItem;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProviderManifest {
    pub id: String,
    pub name: String,
    pub version: String,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub author: Option<String>,
    #[serde(default)]
    pub icon_url: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CatalogCategory {
    pub title: String,
    pub items: Vec<MultimediaItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubtitleTrack {
    pub url: String,
    pub language: String,
    #[serde(default = "default_sub_format")]
    pub format: String, // "vtt", "srt", "ass"
}

fn default_sub_format() -> String {
    "vtt".to_string()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StreamSource {
    pub url: String,
    #[serde(default = "default_quality")]
    pub quality: String, // "4K", "1080p", "720p", "Auto"
    #[serde(default = "default_stream_format")]
    pub format: String, // "hls", "mp4", "dash"
    #[serde(default)]
    pub provider_name: Option<String>,
    #[serde(default)]
    pub headers: HashMap<String, String>,
    #[serde(default)]
    pub subtitles: Vec<SubtitleTrack>,
}

fn default_quality() -> String {
    "Auto".to_string()
}

fn default_stream_format() -> String {
    "hls".to_string()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StreamResolutionRequest {
    pub title: String,
    pub media_type: String, // "movie", "series", "anime"
    #[serde(default)]
    pub season: Option<i32>,
    #[serde(default)]
    pub episode: Option<i32>,
    #[serde(default)]
    pub year: Option<i32>,
    #[serde(default)]
    pub imdb_id: Option<String>,
    #[serde(default)]
    pub tmdb_id: Option<i64>,
}
