use crate::models::{FilterCriteria, MultimediaItem};
use rayon::prelude::*;

pub struct DiscoveryEngine;

impl DiscoveryEngine {
    pub fn filter_and_sort(items: &[MultimediaItem], filter: &FilterCriteria) -> Vec<MultimediaItem> {
        let mut filtered: Vec<MultimediaItem> = items
            .par_iter()
            .filter(|item| {
                // 1. Media Type Filter
                if filter.media_type != "all" {
                    let target_type = filter.media_type.to_lowercase();
                    let item_type = item.media_type.to_lowercase();
                    if target_type == "movie" && item_type != "movie" {
                        return false;
                    }
                    if target_type == "series" && item_type != "series" && item_type != "tv" {
                        return false;
                    }
                    if target_type == "anime" && item_type != "anime" {
                        return false;
                    }
                }

                // 2. Genre Filter
                if let Some(ref selected_genre) = filter.genre {
                    let g_lower = selected_genre.to_lowercase();
                    let has_genre = item.genres.iter().any(|g| g.to_lowercase().contains(&g_lower));
                    let has_desc = item
                        .description
                        .as_ref()
                        .map(|d| d.to_lowercase().contains(&g_lower))
                        .unwrap_or(false);

                    if !has_genre && !has_desc {
                        return false;
                    }
                }

                // 3. Country Filter
                if let Some(ref selected_country) = filter.country {
                    if let Some(ref item_country) = item.country {
                        if !item_country.eq_ignore_ascii_case(selected_country) {
                            return false;
                        }
                    } else {
                        return false;
                    }
                }

                // 4. Year Filter
                if let Some(selected_year) = filter.year {
                    let year_str = selected_year.to_string();
                    let date_match = item
                        .release_date
                        .as_ref()
                        .map(|d| d.contains(&year_str))
                        .unwrap_or(false);
                    if !date_match {
                        return false;
                    }
                }

                // 5. Minimum Rating Filter
                if let Some(min_rating) = filter.min_rating {
                    if item.vote_average < min_rating {
                        return false;
                    }
                }

                true
            })
            .cloned()
            .collect();

        // Sort items
        match filter.sort_by.to_lowercase().as_str() {
            "rating" => {
                filtered.sort_by(|a, b| {
                    b.vote_average
                        .partial_cmp(&a.vote_average)
                        .unwrap_or(std::cmp::Ordering::Equal)
                });
            }
            "newest" => {
                filtered.sort_by(|a, b| {
                    let date_a = a.release_date.as_deref().unwrap_or("");
                    let date_b = b.release_date.as_deref().unwrap_or("");
                    date_b.cmp(date_a)
                });
            }
            "title" => {
                filtered.sort_by(|a, b| {
                    a.title.to_lowercase().cmp(&b.title.to_lowercase())
                });
            }
            "popularity" | _ => {
                filtered.sort_by(|a, b| b.vote_count.cmp(&a.vote_count));
            }
        }

        filtered
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_filter_by_type_and_sort() {
        let items = vec![
            MultimediaItem {
                id: "1".into(),
                title: "Dark Knight".into(),
                description: None,
                poster_path: None,
                backdrop_path: None,
                release_date: Some("2008-07-18".into()),
                vote_average: 9.0,
                vote_count: 30000,
                media_type: "movie".into(),
                genres: vec!["Action".into(), "Crime".into()],
                country: Some("US".into()),
            },
            MultimediaItem {
                id: "2".into(),
                title: "Breaking Bad".into(),
                description: None,
                poster_path: None,
                backdrop_path: None,
                release_date: Some("2008-01-20".into()),
                vote_average: 9.5,
                vote_count: 25000,
                media_type: "series".into(),
                genres: vec!["Drama".into(), "Crime".into()],
                country: Some("US".into()),
            },
        ];

        let filter_movie = FilterCriteria {
            media_type: "movie".into(),
            genre: None,
            country: None,
            year: None,
            sort_by: "rating".into(),
            min_rating: None,
        };

        let res = DiscoveryEngine::filter_and_sort(&items, &filter_movie);
        assert_eq!(res.len(), 1);
        assert_eq!(res[0].title, "Dark Knight");
    }
}
