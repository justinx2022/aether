//! Extension host: loads `.sky` extension bundles and evaluates them in a
//! QuickJS context.
//!
//! This provides the host API surface that extensions expect:
//! - `getHome(cb)` — gets home/browse content
//! - `search(query, cb)` — searches the catalogue
//! - `load(url, cb)` — loads details for a title
//! - `loadStreams(url, cb)` — resolves stream URLs for playback
//!
//! Extensions communicate via a JSON callback bridge (`http_get`, etc.).

use std::collections::HashMap;
use std::path::PathBuf;

use zip::ZipArchive;

use super::context::QuickJSContext;

/// Error type for extension loading
#[derive(Debug)]
pub enum ExtensionLoadError {
    ZipError(String),
    JsonError(String),
    IoError(std::io::Error),
}

impl std::fmt::Display for ExtensionLoadError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ExtensionLoadError::ZipError(e) => write!(f, "zip error: {}", e),
            ExtensionLoadError::JsonError(e) => write!(f, "json error: {}", e),
            ExtensionLoadError::IoError(e) => write!(f, "io error: {}", e),
        }
    }
}

impl std::error::Error for ExtensionLoadError {}

/// Loaded extension data
pub struct ExtensionBundle {
    pub package_name: String,
    pub name: String,
    pub version: String,
    pub plugin_js: String,
    pub plugin_json: String,
}

/// Reads a `.sky` file and extracts its plugin.js + plugin.json
pub fn read_sky_bundle(path: &PathBuf) -> Result<ExtensionBundle, ExtensionLoadError> {
    let file = std::fs::File::open(path).map_err(ExtensionLoadError::IoError)?;
    let mut zip = ZipArchive::new(file).map_err(|e| ExtensionLoadError::ZipError(e.to_string()))?;

    let plugin_js = read_zip_entry(&mut zip, "plugin.js")
        .map_err(ExtensionLoadError::IoError)?
        .ok_or_else(|| ExtensionLoadError::ZipError("plugin.js not found in .sky bundle".to_string()))?;

    let plugin_json = read_zip_entry(&mut zip, "plugin.json")
        .map_err(ExtensionLoadError::IoError)?
        .ok_or_else(|| ExtensionLoadError::ZipError("plugin.json not found in .sky bundle".to_string()))?;

    let manifest: serde_json::Value = serde_json::from_str(&plugin_json)
        .map_err(|e| ExtensionLoadError::JsonError(e.to_string()))?;

    Ok(ExtensionBundle {
        package_name: manifest["packageName"]
            .as_str()
            .unwrap_or("unknown")
            .to_string(),
        name: manifest["name"]
            .as_str()
            .unwrap_or("Unknown")
            .to_string(),
        version: manifest["version"].as_str().unwrap_or("0.0.0").to_string(),
        plugin_js,
        plugin_json,
    })
}

fn read_zip_entry(zip: &mut ZipArchive<std::fs::File>, name: &str) -> std::io::Result<Option<String>> {
    for i in 0..zip.len() {
        let mut file = zip.by_index(i)?;
        if file.name() == name {
            let mut content = String::new();
            std::io::Read::read_to_string(&mut file, &mut content)?;
            return Ok(Some(content));
        }
    }
    Ok(None)
}

/// Extension runner that evaluates extensions in a QuickJS context
pub struct ExtensionRunner {
    ctx: QuickJSContext,
    extensions: HashMap<String, ExtensionBundle>,
    extension_dirs: Vec<PathBuf>,
}

impl ExtensionRunner {
    pub fn new() -> Self {
        let rt = super::context::QuickJSRuntime::new();
        let ctx = rt.create_context();
        Self {
            ctx,
            extensions: HashMap::new(),
            extension_dirs: Vec::new(),
        }
    }

    /// Add a directory to search for `.sky` files
    pub fn add_extension_dir(&mut self, dir: PathBuf) {
        self.extension_dirs.push(dir);
    }

    /// Load all `.sky` extensions from registered directories
    pub fn load_all_extensions(&mut self) -> Result<Vec<String>, ExtensionLoadError> {
        let mut loaded = Vec::new();
        for dir in self.extension_dirs.clone() {
            if !dir.exists() {
                continue;
            }
            for entry in std::fs::read_dir(&dir).map_err(ExtensionLoadError::IoError)? {
                let entry = entry.map_err(ExtensionLoadError::IoError)?;
                let path = entry.path();
                if path.extension().and_then(|s| s.to_str()) == Some("sky") {
                    let bundle = read_sky_bundle(&path)?;
                    let name = bundle.package_name.clone();
                    self.extensions.insert(name.clone(), bundle);
                    loaded.push(name);
                }
            }
        }
        Ok(loaded)
    }

    /// Load a specific `.sky` bundle
    pub fn load_extension(&mut self, sky_path: &PathBuf) -> Result<String, ExtensionLoadError> {
        let bundle = read_sky_bundle(sky_path)?;
        let name = bundle.package_name.clone();
        self.extensions.insert(name.clone(), bundle);
        Ok(name)
    }

    /// Get all loaded extensions
    pub fn get_extensions(&self) -> &HashMap<String, ExtensionBundle> {
        &self.extensions
    }

    /// Evaluate the JS code of a loaded extension
    pub fn evaluate_extension(&self, package_name: &str) -> Result<(), ExtensionLoadError> {
        let bundle = self.extensions
            .get(package_name)
            .ok_or_else(|| ExtensionLoadError::JsonError("extension not found".to_string()))?;

        // The extension code expects to find the PluginModule global or similar.
        // In Aether's .sky format, plugin.js is a IIFE that returns/sets up
        // module-level exports.
        let result = self.ctx.eval(&bundle.plugin_js)?;
        if !result.is_empty() {
            return Ok(());
        }
        Err(ExtensionLoadError::JsonError("extension returned empty".to_string()))
    }

    /// Call a function on the extension's JS global scope
    pub fn call_extension_function(&self, function_name: &str) -> Result<String, ExtensionLoadError> {
        let result = self.ctx.eval(&format!("(typeof {} !== 'undefined' ? {}() : null)", function_name, function_name))?;
        Ok(result)
    }
}

impl Default for ExtensionRunner {
    fn default() -> Self {
        Self::new()
    }
}
