#![allow(clippy::not_unsafe_ptr_arg_deref)]

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic::catch_unwind;

use crate::discovery::DiscoveryEngine;
use crate::extensions::models::StreamSource;
use crate::models::{FilterCriteria, MultimediaItem};
use crate::resolver::StreamResolver;
use crate::search::FuzzySearchEngine;
use crate::torrent::{probe_torrent, TorrServerClient};

/// Returns the Aether Core engine version as a C-string.
/// The caller must free the string using [aether_string_free].
#[unsafe(no_mangle)]
pub extern "C" fn aether_core_version() -> *mut c_char {
    let version = CString::new("0.1.0").unwrap_or_default();
    version.into_raw()
}

/// Computes typo-tolerant fuzzy matching across an array of items in JSON format.
/// Returns a JSON-serialized array of [SearchMatchResult].
/// The caller must free the returned string using [aether_string_free].
#[unsafe(no_mangle)]
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
#[unsafe(no_mangle)]
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

/// Hardware SHA-256 hash returned as hexadecimal string.
/// The caller must free with [aether_string_free].
#[unsafe(no_mangle)]
pub extern "C" fn aether_crypto_sha256(input_ptr: *const c_char) -> *mut c_char {
    let result = catch_unwind(|| {
        if input_ptr.is_null() {
            return CString::new("").unwrap().into_raw();
        }
        let input_str = unsafe {
            match CStr::from_ptr(input_ptr).to_str() {
                Ok(s) => s,
                Err(_) => return CString::new("").unwrap().into_raw(),
            }
        };
        let hash = crate::extensions::AetherCrypto::sha256(input_str.as_bytes());
        CString::new(hash).unwrap_or_default().into_raw()
    });

    match result {
        Ok(ptr) => ptr,
        Err(_) => CString::new("").unwrap_or_default().into_raw(),
    }
}

/// Registers an Aether Native Extension manifest JSON.
#[unsafe(no_mangle)]
pub extern "C" fn aether_provider_register(manifest_json_ptr: *const c_char) -> bool {
    let result = catch_unwind(|| {
        if manifest_json_ptr.is_null() {
            return false;
        }
        let json_str = unsafe {
            match CStr::from_ptr(manifest_json_ptr).to_str() {
                Ok(s) => s,
                Err(_) => return false,
            }
        };
        match serde_json::from_str::<crate::extensions::ProviderManifest>(json_str) {
            Ok(manifest) => {
                crate::extensions::global_registry().register(manifest);
                true
            }
            Err(_) => false,
        }
    });

    result.unwrap_or(false)
}

/// Resolves stream candidates for a [StreamResolutionRequest] JSON.
/// Returns a JSON-serialized array of [StreamSource].
/// Caller must free with [aether_string_free].
#[unsafe(no_mangle)]
pub extern "C" fn aether_provider_resolve_streams(req_json_ptr: *const c_char) -> *mut c_char {
    let result = catch_unwind(|| {
        if req_json_ptr.is_null() {
            return CString::new("[]").unwrap().into_raw();
        }
        let json_str = unsafe {
            match CStr::from_ptr(req_json_ptr).to_str() {
                Ok(s) => s,
                Err(_) => return CString::new("[]").unwrap().into_raw(),
            }
        };
        let req = match serde_json::from_str::<crate::extensions::StreamResolutionRequest>(json_str) {
            Ok(r) => r,
            Err(_) => return CString::new("[]").unwrap().into_raw(),
        };

        let streams = crate::extensions::global_registry().get_stream_candidates(&req);
        let out_json = serde_json::to_string(&streams).unwrap_or_else(|_| "[]".to_string());
        CString::new(out_json).unwrap_or_default().into_raw()
    });

    match result {
        Ok(ptr) => ptr,
        Err(_) => CString::new("[]").unwrap_or_default().into_raw(),
    }
}

/// Resolve a list of candidate streams (HLS + torrent) into the single best
/// one for the player, plus fallbacks. Input is JSON array of StreamSource;
/// output is JSON ResolvedStream.
#[unsafe(no_mangle)]
pub extern "C" fn aether_resolve_streams(
    candidates_json_ptr: *const c_char,
    token_json_ptr: *const c_char,
) -> *mut c_char {
    let result = catch_unwind(|| {
        if candidates_json_ptr.is_null() {
            return CString::new("{\"primary\":\"\",\"fallbacks\":[],\"quality\":\"\",\"protocol\":\"\"}")
                .unwrap()
                .into_raw();
        }

        let candidates_str = unsafe {
            match CStr::from_ptr(candidates_json_ptr).to_str() {
                Ok(s) => s,
                Err(_) => {
                    return CString::new("{\"primary\":\"\",\"fallbacks\":[],\"quality\":\"\",\"protocol\":\"\"}")
                        .unwrap()
                        .into_raw()
                }
            }
        };

        let token = if !token_json_ptr.is_null() {
            unsafe {
                match CStr::from_ptr(token_json_ptr).to_str() {
                    Ok(s) => Some(s.to_string()),
                    Err(_) => None,
                }
            }
        } else {
            None
        };

        let candidates: Vec<StreamSource> = match serde_json::from_str(candidates_str) {
            Ok(list) => list,
            Err(_) => {
                return CString::new("{\"primary\":\"\",\"fallbacks\":[],\"quality\":\"\",\"protocol\":\"\"}")
                    .unwrap()
                    .into_raw()
            }
        };

        let resolver = StreamResolver::new();
        let resolved = resolver.resolve(candidates, token);

        serde_json::to_string(&resolved)
            .map(|s| CString::new(s).unwrap().into_raw())
            .unwrap_or_else(|_| {
                CString::new("{\"primary\":\"\",\"fallbacks\":[],\"quality\":\"\",\"protocol\":\"\"}")
                    .unwrap()
                    .into_raw()
            })
    });

    match result {
        Ok(ptr) => ptr,
        Err(_) => CString::new("{\"primary\":\"\",\"fallbacks\":[],\"quality\":\"\",\"protocol\":\"\"}")
            .unwrap()
            .into_raw(),
    }
}

/// Add a torrent magnet to torrserver and return the local stream URL as JSON.
#[unsafe(no_mangle)]
pub extern "C" fn aether_torrent_add(
    magnet_json_ptr: *const c_char,
    file_index: i32,
    token_json_ptr: *const c_char,
) -> *mut c_char {
    let result = catch_unwind(|| {
        if magnet_json_ptr.is_null() {
            return CString::new("{\"healthy\":false,\"error\":\"null magnet\"}")
                .unwrap()
                .into_raw();
        }

        let magnet = unsafe {
            match CStr::from_ptr(magnet_json_ptr).to_str() {
                Ok(s) => s,
                Err(_) => {
                    return CString::new("{\"healthy\":false,\"error\":\"invalid utf8\"}")
                        .unwrap()
                        .into_raw()
                }
            }
        };

        let token = if !token_json_ptr.is_null() {
            unsafe {
                match CStr::from_ptr(token_json_ptr).to_str() {
                    Ok(s) => Some(s.to_string()),
                    Err(_) => None,
                }
            }
        } else {
            None
        };

        let probe = probe_torrent(magnet, Some(file_index), token);

        serde_json::to_string(&probe)
            .map(|s| CString::new(s).unwrap().into_raw())
            .unwrap_or_else(|_| {
                CString::new("{\"healthy\":false,\"error\":\"serialization failed\"}")
                    .unwrap()
                    .into_raw()
            })
    });

    match result {
        Ok(ptr) => ptr,
        Err(_) => CString::new("{\"healthy\":false,\"error\":\"panic\"}")
            .unwrap()
            .into_raw(),
    }
}

/// Query torrserver status for an info hash. Returns JSON status.
#[unsafe(no_mangle)]
pub extern "C" fn aether_torrent_status(info_hash_json_ptr: *const c_char) -> *mut c_char {
    let result = catch_unwind(|| {
        if info_hash_json_ptr.is_null() {
            return CString::new("{\"error\":\"null info_hash\"}")
                .unwrap()
                .into_raw();
        }

        let info_hash = unsafe {
            match CStr::from_ptr(info_hash_json_ptr).to_str() {
                Ok(s) => s,
                Err(_) => {
                    return CString::new("{\"error\":\"invalid utf8\"}")
                        .unwrap()
                        .into_raw()
                }
            }
        };

        let client = TorrServerClient::new(None);
        match client.status(info_hash) {
            Ok(status) => serde_json::to_string(&status)
                .map(|s| CString::new(s).unwrap().into_raw())
                .unwrap_or_else(|_| {
                    CString::new("{\"error\":\"serialization failed\"}")
                        .unwrap()
                        .into_raw()
                }),
            Err(e) => CString::new(format!("{{\"error\":\"{}\"}}", e))
                .unwrap()
                .into_raw(),
        }
    });

    match result {
        Ok(ptr) => ptr,
        Err(_) => CString::new("{\"error\":\"panic\"}").unwrap().into_raw(),
    }
}

/// Remove a torrent from torrserver by info hash. Returns JSON {ok: true/false}.
#[unsafe(no_mangle)]
pub extern "C" fn aether_torrent_remove(info_hash_json_ptr: *const c_char) -> *mut c_char {
    let result = catch_unwind(|| {
        if info_hash_json_ptr.is_null() {
            return CString::new("{\"ok\":false,\"error\":\"null info_hash\"}")
                .unwrap()
                .into_raw();
        }

        let info_hash = unsafe {
            match CStr::from_ptr(info_hash_json_ptr).to_str() {
                Ok(s) => s,
                Err(_) => {
                    return CString::new("{\"ok\":false,\"error\":\"invalid utf8\"}")
                        .unwrap()
                        .into_raw()
                }
            }
        };

        let client = TorrServerClient::new(None);
        match client.remove_torrent(info_hash) {
            Ok(()) => CString::new("{\"ok\":true}").unwrap().into_raw(),
            Err(e) => CString::new(format!("{{\"ok\":false,\"error\":\"{}\"}}", e))
                .unwrap()
                .into_raw(),
        }
    });

    match result {
        Ok(ptr) => ptr,
        Err(_) => CString::new("{\"ok\":false,\"error\":\"panic\"}").unwrap().into_raw(),
    }
}

/// Frees a C-string allocated by this library.
#[unsafe(no_mangle)]
pub extern "C" fn aether_string_free(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}
