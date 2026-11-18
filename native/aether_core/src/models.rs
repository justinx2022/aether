use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MultimediaItem {
    pub id: String,
    pub title: String,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub poster_path: Option<String>,
    #[serde(default)]
    pub backdrop_path: Option<String>,
    #[serde(default)]
    pub release_date: Option<String>,
    #[serde(default)]
    pub vote_average: f64,
    #[serde(default)]
    pub vote_count: i64,
    #[serde(default)]
    pub media_type: String, // "movie", "series", "anime"
    #[serde(default)]
    pub genres: Vec<String>,
    #[serde(default)]
    pub country: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FilterCriteria {
    #[serde(default = "default_media_type")]
    pub media_type: String, // "all", "movie", "series", "anime"
    #[serde(default)]
    pub genre: Option<String>,
    #[serde(default)]
    pub country: Option<String>,
    #[serde(default)]
    pub year: Option<i32>,
    #[serde(default = "default_sort_by")]
    pub sort_by: String, // "popularity", "rating", "newest", "title"
    #[serde(default)]
    pub min_rating: Option<f64>,
}

fn default_media_type() -> String {
    "all".to_string()
}

fn default_sort_by() -> String {
    "popularity".to_string()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SearchMatchResult {
    pub item: MultimediaItem,
    pub score: i32,
}
