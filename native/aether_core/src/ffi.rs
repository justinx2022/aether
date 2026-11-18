use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic::catch_unwind;

use crate::discovery::DiscoveryEngine;
use crate::models::{FilterCriteria, MultimediaItem};
use crate::search::FuzzySearchEngine;

/// Returns the Aether Core engine version as a C-string.
/// The caller must free the string using [aether_string_free].
#[no_mangle]
pub extern "C" fn aether_core_version() -> *mut c_char {
    let version = CString::new("0.1.0").unwrap_or_default();
    version.into_raw()
}

/// Computes typo-tolerant fuzzy matching across an array of items in JSON format.
/// Returns a JSON-serialized array of [SearchMatchResult].
/// The caller must free the returned string using [aether_string_free].
#[no_mangle]
pub extern "C" fn aether_fuzzy_search(
    query_ptr: *const c_char,
    items_json_ptr: *const c_char,
    min_score: i32,
) -> *mut c_char {
    let result = catch_unwind(|| {
        if query_ptr.is_null() || items_json_ptr.is_null() {
            return CString::new("[]").unwrap().into_raw();
        }

        let query = unsafe {
            match CStr::from_ptr(query_ptr).to_str() {
                Ok(s) => s,
                Err(_) => return CString::new("[]").unwrap().into_raw(),
            }
        };

        let items_str = unsafe {
            match CStr::from_ptr(items_json_ptr).to_str() {
                Ok(s) => s,
                Err(_) => return CString::new("[]").unwrap().into_raw(),
            }
        };

        let items: Vec<MultimediaItem> = match serde_json::from_str(items_str) {
            Ok(list) => list,
            Err(_) => return CString::new("[]").unwrap().into_raw(),
        };

        let matches = FuzzySearchEngine::search_parallel(&items, query, min_score);
        let out_json = serde_json::to_string(&matches).unwrap_or_else(|_| "[]".to_string());
        CString::new(out_json).unwrap_or_default().into_raw()
    });

    match result {
        Ok(ptr) => ptr,
        Err(_) => CString::new("[]").unwrap_or_default().into_raw(),
    }
}

/// Filters and sorts a collection of items according to criteria in JSON format.
/// Returns a JSON-serialized array of [MultimediaItem].
/// The caller must free the returned string using [aether_string_free].
#[no_mangle]
pub extern "C" fn aether_filter_and_sort(
    items_json_ptr: *const c_char,
    filter_json_ptr: *const c_char,
) -> *mut c_char {
    let result = catch_unwind(|| {
        if items_json_ptr.is_null() || filter_json_ptr.is_null() {
            return CString::new("[]").unwrap().into_raw();
        }

        let items_str = unsafe {
            match CStr::from_ptr(items_json_ptr).to_str() {
                Ok(s) => s,
                Err(_) => return CString::new("[]").unwrap().into_raw(),
            }
        };

        let filter_str = unsafe {
            match CStr::from_ptr(filter_json_ptr).to_str() {
                Ok(s) => s,
                Err(_) => return CString::new("[]").unwrap().into_raw(),
            }
        };

        let items: Vec<MultimediaItem> = match serde_json::from_str(items_str) {
            Ok(list) => list,
            Err(_) => return CString::new("[]").unwrap().into_raw(),
        };

        let filter: FilterCriteria = match serde_json::from_str(filter_str) {
            Ok(f) => f,
            Err(_) => return CString::new("[]").unwrap().into_raw(),
        };

        let filtered = DiscoveryEngine::filter_and_sort(&items, &filter);
        let out_json = serde_json::to_string(&filtered).unwrap_or_else(|_| "[]".to_string());
        CString::new(out_json).unwrap_or_default().into_raw()
    });

    match result {
        Ok(ptr) => ptr,
        Err(_) => CString::new("[]").unwrap_or_default().into_raw(),
    }
}

/// Frees a C-string allocated by this library.
#[no_mangle]
pub extern "C" fn aether_string_free(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}
