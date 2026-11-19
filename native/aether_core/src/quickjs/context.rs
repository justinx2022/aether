//! Safe Rust wrapper around QuickJS-NG runtime and context.

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};

use super::ffi::*;

pub struct QuickJSRuntime {
    rt: *mut JSRuntime,
}

impl QuickJSRuntime {
    pub fn new() -> Self {
        let rt = unsafe { JS_NewRuntime() };
        unsafe { JS_SetGCThreshold(rt, (usize::MAX / 2)) }; // Effectively disable GC for now
        Self { rt }
    }

    pub fn set_memory_limit(&self, limit: usize) {
        unsafe { JS_SetMemoryLimit(self.rt, limit) };
    }

    pub fn create_context(&self) -> QuickJSContext {
        let ctx = unsafe { JS_NewContext(self.rt) };
        QuickJSContext { ctx, rt: self.rt }
    }
}

impl Drop for QuickJSRuntime {
    fn drop(&mut self) {
        unsafe { JS_FreeRuntime(self.rt) }
    }
}

unsafe impl Send for QuickJSRuntime {}
unsafe impl Sync for QuickJSRuntime {}

pub struct QuickJSContext {
    ctx: *mut JSContext,
    rt: *mut JSRuntime,
}

impl QuickJSContext {
    /// Evaluate JavaScript code and return the result as a JSON string.
    pub fn eval(&self, code: &str) -> Result<String, String> {
        self.eval_with_filename(code, "<string>")
    }

    /// Evaluate JavaScript code and return the result as a string.
    pub fn eval_to_string(&self, code: &str) -> Result<String, String> {
        let result = self.eval(code)?;
        Ok(result)
    }

    /// Evaluate JavaScript code and return the raw result.
    pub fn eval_raw(&self, code: &str) -> Result<JSValue, String> {
        let c_code = CString::new(code).map_err(|e| format!("NUL byte in code: {}", e))?;
        let filename = CString::new("<extension>").unwrap();

        let result = unsafe {
            JS_Eval(
                self.ctx,
                c_code.as_ptr(),
                c_code.as_bytes().len(),
                filename.as_ptr(),
                0, // No flags
            )
        };

        if unsafe { JS_IsNull(result) } != 0 {
            return Err("JS returned null".to_string());
        }

        // Convert result to string
        let str_ptr = unsafe { JS_ToString(self.ctx, result) };
        if str_ptr.is_null() {
            return Err("Failed to convert JS value to string".to_string());
        }
        let result_str = unsafe {
            let s = CStr::from_ptr(str_ptr).to_string_lossy().into_owned();
            JS_FreeCString(self.ctx, str_ptr);
            s
        };

        Ok(result_str)
    }

    fn eval_with_filename(&self, code: &str, filename: &str) -> Result<String, String> {
        let c_code = CString::new(code).map_err(|e| format!("NUL byte in code: {}", e))?;
        let c_filename = CString::new(filename).unwrap();

        let result = unsafe {
            JS_Eval(
                self.ctx,
                c_code.as_ptr(),
                c_code.as_bytes().len(),
                c_filename.as_ptr(),
                0, // JS_EFLAG_NONE
            )
        };

        // Convert result to string via JS_ToString (not JS_ToCString, which
        // allocates, making ownership clearer).
        if unsafe { JS_IsNull(result) } != 0 {
            return Ok("null".to_string());
        }

        let str_value = unsafe { JS_ToString(self.ctx, result) };
        let output = js_string(self.ctx, str_value)
            .unwrap_or_else(|| "undefined".to_string());
        Ok(output)
    }

    /// Register a Rust function as a global JS function.
    pub fn register_global_function(
        &self,
        name: &str,
        callback: extern "C" fn(c_int, *mut JSValue, *const c_char) -> JSValue,
        argc: c_int,
    ) -> Result<(), String> {
        // We'd need JS_NewCFunction which isn't exposed in our FFI.
        // For now, return an error suggesting JS_NewCFunction should be added.
        let _ = (name, callback, argc);
        Err("JS_NewCFunction not yet exposed in FFI. Please extend the FFI bindings.".to_string())
    }

    /// Get the global object.
    pub fn global_object(&self) -> JSValue {
        unsafe { JS_GetGlobalObject(self.ctx) }
    }

    /// Get a global property by name.
    pub fn get_global(&self, name: &str) -> Option<JSValue> {
        let c_name = CString::new(name).ok()?;
        let global = self.global_object();
        let val = unsafe { JS_GetPropertyStr(self.ctx, global, c_name.as_ptr()) };
        if unsafe { JS_IsUndefined(val) } != 0 {
            None
        } else {
            Some(val)
        }
    }
}

impl Drop for QuickJSContext {
    fn drop(&mut self) {
        unsafe { JS_FreeContext(self.ctx) }
    }
}

unsafe impl Send for QuickJSContext {}
unsafe impl Sync for QuickJSContext {}
