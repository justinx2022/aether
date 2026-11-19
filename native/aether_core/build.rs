//! Build script for aether_core.
//!
//! When the `service` feature is enabled, compiles the vendored QuickJS-NG C
//! source (from `packages/flutter_js_ng/cxx/quickjs/`) into a static library
//! that the Rust QuickJS module links against.

use std::env;
use std::path::PathBuf;

fn main() {
    // Re-run when build.rs or Cargo.toml changes
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=Cargo.toml");

    // Compile QuickJS when the quickjs feature is enabled.
    let quickjs_enabled = env::var("CARGO_FEATURE_QUICKJS").is_ok();
    if !quickjs_enabled {
        return;
    }

    let crate_root = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    // Crate is at: <workspace>/aether/native/aether_core
    // Packages is at: <workspace>/aether/packages
    let workspace_root = crate_root
        .parent()       // native
        .and_then(|p| p.parent())  // aether
        .expect("workspace root (aether)");
    let quickjs_dir = workspace_root
        .join("packages")
        .join("flutter_js_ng")
        .join("cxx")
        .join("quickjs");

    if !quickjs_dir.exists() {
        panic!(
            "QuickJS source directory not found: {}. \
             Please clone quickjs-ng or check the path is correct.",
            quickjs_dir.display()
        );
    }

    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let lib_dir = out_dir.join("quickjs");
    std::fs::create_dir_all(&lib_dir).expect("create out dir");

    // QuickJS C files to compile (matching CI build_quickjs_ng.yml):
    // No CONFIG_BIGNUM, no cutils/libbf, dtoa.c took over.
    let c_files = ["dtoa", "libregexp", "libunicode", "quickjs"];

    let mut cc = cc::Build::new();
    cc.include(&quickjs_dir);
    cc.opt_level(1);
    cc.std("gnu17");
    cc.flag("-funsigned-char");
    cc.flag("-Wno-unused-but-set-variable");
    cc.define("CONFIG_VERSION", Some("2024-01-01"));
    cc.define("QUICKJS", None);
    cc.define("_GNU_SOURCE", None);

    for name in &c_files {
        let path = quickjs_dir.join(format!("{}.c", name));
        if !path.exists() {
            panic!("QuickJS source file not found: {}", path.display());
        }
        cc.file(&path);
    }

    cc.compile("quickjs_ng");

    // Tell cargo where to find the library
    println!("cargo:rustc-link-search=native={}", lib_dir.display());
    println!("cargo:rustc-link-lib=static=quickjs_ng");

    // On Linux, need additional system libraries
    #[cfg(target_os = "linux")]
    {
        println!("cargo:rustc-link-lib=m");
        println!("cargo:rustc-link-lib=dl");
        println!("cargo:rustc-link-lib=pthread");
    }
}
