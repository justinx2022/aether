//! Raw FFI bindings to the QuickJS-NG C API (`quickjs.h`).
//!
//! Declared manually (not via bindgen) so we can link against the vendored
//! QuickJS-NG source without extra build complexity.

#![allow(non_camel_case_types)]
#![allow(dead_code)]
#![allow(non_upper_case_globals)]

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_void};

pub enum JSRuntime {}
pub enum JSContext {}
pub enum JSValue {}

pub type JSPropList = Vec<(String, String)>;

#[repr(C)]
#[derive(Clone, Copy)]
pub enum JSType {
    JS_TYPE_STRING = 2,
    JS_TYPE_OBJECT = 3,
    JS_TYPE_NULL = 5,
    JS_TYPE_UNDEFINED = 9,
}

// Link to the QuickJS-NG library (compiled via build.rs)
#[link(name = "quickjs_ng")]
extern "C" {
    // Runtime
    pub fn JS_NewRuntime() -> *mut JSRuntime;
    pub fn JS_FreeRuntime(rt: *mut JSRuntime);
    pub fn JS_SetMemoryLimit(rt: *mut JSRuntime, limit: usize);
    pub fn JS_SetGCThreshold(rt: *mut JSRuntime, threshold: usize);

    // Context
    pub fn JS_NewContext(rt: *mut JSRuntime) -> *mut JSContext;
    pub fn JS_FreeContext(ctx: *mut JSContext);
    pub fn JS_GetGlobalObject(ctx: *mut JSContext) -> JSValue;
    pub fn JS_GetPropertyStr(ctx: *mut JSContext, this_obj: JSValue, name: *const c_char) -> JSValue;
    pub fn JS_GetOwnPropertyNames(ctx: *mut JSContext, this_obj: JSValue) -> JSValue;
    pub fn JS_SetPropertyStr(ctx: *mut JSContext, obj: JSValue, name: *const c_char, val: JSValue) -> c_int;

    // Value manipulation
    pub fn JS_FreeValue(ctx: *mut JSContext, value: JSValue);
    pub fn JS_DupValue(ctx: *mut JSContext, value: JSValue) -> JSValue;
    pub fn JS_IsObject(ctx: *mut JSContext, value: JSValue) -> c_int;
    pub fn JS_IsArray(ctx: *mut JSContext, value: JSValue) -> c_int;
    pub fn JS_IsString(ctx: *mut JSContext, value: JSValue) -> c_int;
    pub fn JS_IsUndefined(value: JSValue) -> c_int;
    pub fn JS_IsNull(value: JSValue) -> c_int;
    pub fn JS_IsBool(value: JSValue) -> c_int;
    pub fn JS_IsNumber(value: JSValue) -> c_int;
    pub fn JS_ToCString(ctx: *mut JSContext, value: JSValue) -> *const c_char;
    pub fn JS_FreeCString(ctx: *mut JSContext, value: *const c_char);
    pub fn JS_ToBoolean(ctx: *mut JSContext, value: JSValue) -> c_int;

    // String conversion
    pub fn JS_GetString(ctx: *mut JSContext, value: JSValue) -> *mut c_char;

    // Function execution
    pub fn JS_Eval(ctx: *mut JSContext, input_buf: *const c_char, input_len: usize, filename: *const c_char, flags: c_int) -> JSValue;
    pub fn JS_Call(ctx: *mut JSContext, func_obj: JSValue, this_obj: JSValue, argc: c_int, argv: *mut JSValue) -> JSValue;
    pub fn JS_CallFunctionStr(ctx: *mut JSContext, func_obj: JSValue, this_obj: JSValue, args_buf: *const c_char, args_len: usize) -> JSValue;

    // Property iteration (for getting property names)
    pub fn JS_GetOwnPropertyNames_Length(ctx: *mut JSContext, obj: JSValue) -> JSValue;

    // JSON
    pub fn JS_ParseJSON(ctx: *mut JSContext, buf: *const c_char, len: usize, filename: *const c_char) -> JSValue;

    // ToString
    pub fn JS_ToString(ctx: *mut JSContext, value: JSValue) -> JSValue;
    pub fn JS_ToStringSz(ctx: *mut JSContext, str_: *const c_char) -> *mut c_char;

    // GC control
    pub fn JS_RunGC(rt: *mut JSRuntime);

    // Context creation flags
    pub const JS_EFLAG_NONE: c_int = 0;
}

// Define simple Rust-safe wrapper
pub fn js_string(ctx: *mut JSContext, value: JSValue) -> Option<String> {
    if value.is_null() {
        return None;
    }
    unsafe {
        let str_ptr = JS_ToCString(ctx, value);
        if str_ptr.is_null() {
            return None;
        }
        let result = CStr::from_ptr(str_ptr).to_string_lossy().into_owned();
        JS_FreeCString(ctx, str_ptr);
        Some(result)
    }
}

pub fn js_string_sz(ctx: *mut JSContext, value: JSValue) -> Option<String> {
    unsafe {
        let str_ptr = JS_ToStringSz(ctx, value);
        if str_ptr.is_null() {
            return None;
        }
        let result = CStr::from_ptr(str_ptr).to_string_lossy().into_owned();
        JS_FreeCString(ctx, str_ptr);
        Some(result)
    }
}

pub fn js_string_value(value: JSValue) -> Option<String> {
    if value.is_null() {
        return None;
    }
    // This is a raw value — we need a context to convert it.
    // Callers should use js_string() with a context.
    let _ = value;
    None
}

impl std::fmt::Debug for JSRuntime {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "JSRuntime(opaque)")
    }
}

impl std::fmt::Debug for JSContext {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "JSContext(opaque)")
    }
}

impl std::fmt::Debug for JSValue {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "JSValue(opaque)")
    }
}
