// C ABI over the oii interpreter for the paradise app. One engine at a time
// from Dart's point of view, but the handles are independent so a second one
// costs nothing.
//
// Values cross the border as JSON strings: oii derives serde on Value and the
// doc folds to a plain object, so every entry point takes and returns UTF-8.
// A host call is the one place where bytes go the other way. Dart registers
// one callback pointer per engine, Rust invokes it with (name, args json) and
// blocks on a reply written back through oii_bridge_host_reply. The blocking
// side is the eval thread, never the Dart UI thread, so the round trip cannot
// deadlock the app.

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};
use std::sync::mpsc;
use std::sync::Mutex;

use oii::{EvalOptions, Value};

/// One engine: parsed source kept for reuse, host functions by name.
pub struct Engine {
    /// The most recently parsed document. oii docs are cheap, caching one
    /// saves nothing for the app; the field exists so eval can take the doc
    /// the caller actually parsed last, which is what a plugin run wants.
    doc: oii::Doc,
    opts: EvalOptions,
    /// Set while an eval is on the stack. The host callback fires on the same
    /// thread, so a channel plus a mutex-protected slot is enough.
    host: std::collections::HashSet<String>,
}

pub struct HostCall {
    pub name: String,
    pub args_json: String,
    pub reply: mpsc::SyncSender<String>,
}

/// Global pending host call. One at a time by construction: evals run
/// sequentially on the engine, Dart answers before starting the next.
static PENDING: Mutex<Option<HostCall>> = Mutex::new(None);

// ---------------------------------------------------------------- helpers

fn str_in<'a>(p: *const c_char) -> &'a str {
    if p.is_null() {
        return "";
    }
    // borrows the caller's buffer, which outlives the call by the C contract
    let cstr = unsafe { CStr::from_ptr(p) };
    cstr.to_str().unwrap_or("")
}

fn str_out(s: String) -> *mut c_char {
    match CString::new(s) {
        Ok(c) => c.into_raw(),
        Err(_) => CString::default().into_raw(),
    }
}

fn json_value(text: &str) -> Value {
    // null stays null, a bare object folds into a map, everything else is the
    // json scalar it claims to be
    match serde_json::from_str::<serde_json::Value>(text) {
        Ok(v) => json_to_value(&v),
        Err(_) => Value::Null,
    }
}

fn json_to_value(v: &serde_json::Value) -> Value {
    match v {
        serde_json::Value::Null => Value::Null,
        serde_json::Value::Bool(b) => Value::Bool(*b),
        serde_json::Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                Value::Int(i)
            } else {
                Value::Float(n.as_f64().unwrap_or(0.0))
            }
        }
        serde_json::Value::String(s) => Value::Str(s.clone()),
        serde_json::Value::Array(xs) => Value::Array(xs.iter().map(json_to_value).collect()),
        serde_json::Value::Object(m) => Value::Map(
            m.iter()
                .map(|(k, v)| (k.clone(), json_to_value(v)))
                .collect(),
        ),
    }
}

fn value_to_json(v: &Value) -> String {
    fn walk(v: &Value) -> serde_json::Value {
        match v {
            Value::Bare(s) | Value::Str(s) | Value::RawStr(s) => {
                serde_json::Value::String(s.clone())
            }
            Value::Int(i) => serde_json::json!(i),
            Value::Float(f) => serde_json::json!(f),
            Value::Bool(b) => serde_json::json!(b),
            Value::Null => serde_json::Value::Null,
            Value::Array(xs) => serde_json::Value::Array(xs.iter().map(walk).collect()),
            Value::Map(m) => serde_json::Value::Object(
                m.iter()
                    .map(|(k, v)| (k.clone(), walk(v)))
                    .collect::<serde_json::Map<String, serde_json::Value>>(),
            ),
            // a func has no json form, same as the cli dump
            Value::Func(_) => serde_json::Value::Null,
            Value::Typed { value, .. } => walk(value),
            Value::Disabled(v) => walk(v),
        }
    }
    serde_json::to_string(&walk(v)).unwrap_or_else(|_| "null".into())
}

// ---------------------------------------------------------------- lifecycle

/// Creates an engine. Returns an opaque handle, 0 on OOM.
#[no_mangle]
pub extern "C" fn oii_bridge_engine_new() -> *mut Engine {
    Box::into_raw(Box::new(Engine {
        doc: oii::Doc::default(),
        opts: EvalOptions::default(),
        host: Default::default(),
    }))
}

/// Drops an engine. Passing null or an unknown pointer is a no-op by contract
/// with the Dart side, which only ever hands back what this returned.
#[no_mangle]
pub extern "C" fn oii_bridge_engine_free(engine: *mut Engine) {
    if !engine.is_null() {
        unsafe { drop(Box::from_raw(engine)) };
    }
}

/// Registers or removes a host function name. Args must exist before a script
/// can call them; nothing here validates the script side.
#[no_mangle]
pub extern "C" fn oii_bridge_engine_host_register(engine: *mut Engine, name: *const c_char) {
    if engine.is_null() {
        return;
    }
    let e = unsafe { &mut *engine };
    let name = str_in(name).to_string();
    if name.is_empty() {
        return;
    }
    e.host.insert(name);
}

#[no_mangle]
pub extern "C" fn oii_bridge_engine_host_unregister(engine: *mut Engine, name: *const c_char) {
    if engine.is_null() {
        return;
    }
    let e = unsafe { &mut *engine };
    e.host.remove(str_in(name));
}

/// Step and depth limits, as one pair. 0 keeps the current value.
#[no_mangle]
pub extern "C" fn oii_bridge_engine_limits(engine: *mut Engine, max_steps: u64, max_depth: u32) {
    if engine.is_null() {
        return;
    }
    let e = unsafe { &mut *engine };
    if max_steps > 0 {
        e.opts.max_steps = max_steps;
    }
    if max_depth > 0 {
        e.opts.max_depth = max_depth;
    }
}

// ---------------------------------------------------------------- parse

/// Parses source into the engine. The returned json is
/// `{"ok":true,"diagnostics":[...]}` with the diagnostics rendered in en.
/// On error the engine keeps its previous doc, so a bad plugin file cannot
/// take down an engine that already runs another.
#[no_mangle]
pub extern "C" fn oii_bridge_parse(engine: *mut Engine, source: *const c_char) -> *mut c_char {
    if engine.is_null() {
        return str_out(r#"{"ok":false,"error":"no engine"}"#.into());
    }
    let e = unsafe { &mut *engine };
    let src = str_in(source);
    let mut opts = oii::ParseOptions::default();
    opts.lang = oii::Lang::En;
    let out = oii::parse_with(src, &opts);
    let diags: Vec<String> = out
        .diagnostics
        .iter()
        .map(|d| oii::diag::render_diag(src, d))
        .collect();
    let ok = !out.has_errors();
    if ok {
        if let Some(doc) = out.doc {
            e.doc = doc;
        }
    }
    str_out(
        serde_json::json!({ "ok": ok, "diagnostics": diags }).to_string(),
    )
}

/// Describes source without an engine. Stateless, safe to call from any
/// thread: parses, then folds the `plugin` top node (if any) into
/// `{"ok":true,"plugin":{...},"tools":[...],"resources":[...],"funcs":[...]}`.
/// Diagnostics ride along rendered. Nothing is executed, so listing a package
/// costs one parse.
///
/// A manifest is a `plugin [ ... ]` node holding package attributes, `tool`
/// children and `resource` children:
///
/// ```oii
/// plugin [
///   id: "para.demo"
///   name: "Demo"
///   main: "main.oii"
///   tool audit [ file: "skills/check.oii", entry: check, param q [ type: string ] ]
///   resource logo [ file: "res/logo.svg" ]
/// ]
/// ```
///
/// Child nodes fold by name rather than into a fixed shape, so a manifest can
/// grow fields without this function changing. Types are json schema names
/// because they go straight into the model's tool schema.
#[no_mangle]
pub extern "C" fn oii_bridge_describe(source: *const c_char) -> *mut c_char {
    let src = str_in(source);
    let mut opts = oii::ParseOptions::default();
    opts.lang = oii::Lang::En;
    let out = oii::parse_with(src, &opts);
    let diags: Vec<String> = out
        .diagnostics
        .iter()
        .map(|d| oii::diag::render_diag(src, d))
        .collect();
    let ok = !out.has_errors();
    let (plugin, tools, resources, funcs) = match out.doc {
        Some(doc) => {
            let node = doc.node("plugin");
            let plugin = node.map(fold_attrs);
            let tools: Vec<serde_json::Value> = node
                .map(|n| {
                    n.children
                        .iter()
                        .filter(|c| c.enabled && c.name == "tool")
                        .map(fold_tool)
                        .collect()
                })
                .unwrap_or_default();
            let resources: Vec<serde_json::Value> = node
                .map(|n| {
                    n.children
                        .iter()
                        .filter(|c| c.enabled && c.name == "resource")
                        .map(fold_resource)
                        .collect()
                })
                .unwrap_or_default();
            let funcs: Vec<serde_json::Value> = doc.funcs.iter().map(fold_func).collect();
            (plugin, tools, resources, funcs)
        }
        None => (None, Vec::new(), Vec::new(), Vec::new()),
    };
    str_out(
        serde_json::json!({
            "ok": ok,
            "diagnostics": diags,
            "plugin": plugin,
            "tools": tools,
            "resources": resources,
            "funcs": funcs,
        })
        .to_string(),
    )
}

/// A node's enabled attributes as a json object. Children are left out: the
/// caller knows which ones it wants, and folding them here would collide when
/// two children share a name.
fn fold_attrs(n: &oii::Node) -> serde_json::Value {
    let mut m = serde_json::Map::new();
    for a in &n.attributes {
        if a.enabled {
            let text = value_to_json(&a.value);
            m.insert(
                a.key.clone(),
                serde_json::from_str(&text).unwrap_or(serde_json::Value::Null),
            );
        }
    }
    serde_json::Value::Object(m)
}

/// json schema type for an oii value. Manifests may say `int` or `float` in
/// prose, but what crosses the border has to be a name the model already knows.
fn schema_type(v: &Value) -> &'static str {
    match v {
        Value::Int(_) => "integer",
        Value::Float(_) => "number",
        Value::Bool(_) => "boolean",
        Value::Array(_) => "array",
        _ => "string",
    }
}

/// Maps the oii type annotations a manifest may use onto schema names. Unknown
/// names fall through as a string, which every endpoint accepts.
fn normalize_type(raw: &str) -> String {
    match raw.trim().to_ascii_lowercase().as_str() {
        "int" | "integer" | "i64" => "integer".into(),
        "float" | "number" | "f64" | "double" => "number".into(),
        "bool" | "boolean" => "boolean".into(),
        "array" | "list" => "array".into(),
        "string" | "str" => "string".into(),
        _ => "string".into(),
    }
}

/// The identifier a manifest child carries. `tool audit [ .. ]` passes `audit`
/// as an arg, which reads better than repeating it as an attribute, so the arg
/// wins; `param name: "audit"` is accepted for manifests that prefer it.
fn node_name(n: &oii::Node) -> String {
    if let Some(first) = n.args.first() {
        let text = value_to_json(first);
        if let Some(s) = serde_json::from_str::<serde_json::Value>(&text)
            .ok()
            .and_then(|v| v.as_str().map(str::to_string))
        {
            if !s.is_empty() {
                return s;
            }
        }
    }
    let attrs = fold_attrs(n);
    if let Some(s) = attrs["name"].as_str() {
        if !s.is_empty() {
            return s.to_string();
        }
    }
    n.name.clone()
}

fn fold_param(n: &oii::Node) -> serde_json::Value {
    let attrs = fold_attrs(n);
    let name = node_name(n);
    let declared = attrs["type"].as_str().map(normalize_type);
    serde_json::json!({
        "name": name,
        "type": declared.unwrap_or_else(|| "string".into()),
        "desc": attrs["desc"].as_str().unwrap_or_default(),
        "optional": attrs.get("default").is_some() || attrs["optional"].as_bool() == Some(true),
        "default": attrs.get("default").cloned().unwrap_or(serde_json::Value::Null),
    })
}

fn fold_tool(n: &oii::Node) -> serde_json::Value {
    let attrs = fold_attrs(n);
    let name = node_name(n);
    let file = attrs["file"].as_str().unwrap_or_default().to_string();
    let entry = attrs["entry"].as_str().unwrap_or_default().to_string();
    serde_json::json!({
        "name": name,
        "file": file,
        // no `entry` means the func named after the file, which is what a
        // single script per tool package writes anyway
        "entry": if entry.is_empty() { default_entry(&file, &name) } else { entry },
        "desc": attrs["desc"].as_str().unwrap_or_default(),
        "enabled": attrs["default"].as_bool().unwrap_or(true),
        "params": n.children.iter().filter(|c| c.enabled && c.name == "param").map(fold_param).collect::<Vec<_>>(),
    })
}

/// `skills/check.oii` -> `check`. Falls back to the tool name for a manifest
/// that names its entry file something else.
fn default_entry(file: &str, tool_name: &str) -> String {
    let stem = file.rsplit('/').next().unwrap_or(file);
    let stem = stem.strip_suffix(".oii").unwrap_or(stem);
    if stem.is_empty() { tool_name.to_string() } else { stem.to_string() }
}

fn fold_resource(n: &oii::Node) -> serde_json::Value {
    let attrs = fold_attrs(n);
    serde_json::json!({
        "key": node_name(n),
        "file": attrs["file"].as_str().unwrap_or_default(),
        "mime": attrs["mime"].as_str().unwrap_or_default(),
    })
}

/// A func becomes a tool of its own when it carries a desc, so a single file
/// package needs no manifest beyond the `plugin` node. Params come from the
/// signature; the type is inferred from the default value where there is one
/// and is a string otherwise.
fn fold_func(f: &oii::Func) -> serde_json::Value {
    serde_json::json!({
        "name": f.name,
        "desc": f.desc,
        "params": f.params.iter().map(|p| serde_json::json!({
            "name": p.name,
            "type": p.default.as_ref().map(schema_type).unwrap_or("string"),
            "optional": p.default.is_some(),
            "default": p.default.as_ref().map(|v| value_to_json_wrapped(v)).unwrap_or(serde_json::Value::Null),
        })).collect::<Vec<_>>(),
    })
}

// ---------------------------------------------------------------- eval

/// Calls `name` in the engine's current doc. `args_json` is a json array.
/// Returns `{"ok":true,"value":...,"output":[...],"steps":n}` or
/// `{"ok":false,"error":"[E123] ..."}`.
#[no_mangle]
pub extern "C" fn oii_bridge_eval(
    engine: *mut Engine,
    name: *const c_char,
    args_json: *const c_char,
) -> *mut c_char {
    if engine.is_null() {
        return str_out(r#"{"ok":false,"error":"no engine"}"#.into());
    }
    let e = unsafe { &mut *engine };
    let fname = str_in(name).to_string();
    let args: Vec<Value> = match serde_json::from_str::<serde_json::Value>(str_in(args_json)) {
        Ok(serde_json::Value::Array(xs)) => xs.iter().map(json_to_value).collect(),
        _ => Vec::new(),
    };
    let result = {
        let mut host = |hname: &str, hargs: &[Value]| -> Option<Result<Value, oii::EvalError>> {
            if !e.host.contains(hname) {
                return None;
            }
            let args_json = serde_json::to_string(
                &hargs.iter().map(|v| {
                    let text = value_to_json(v);
                    serde_json::from_str::<serde_json::Value>(&text).unwrap_or(serde_json::Value::Null)
                }).collect::<Vec<_>>(),
            )
            .unwrap_or_else(|_| "[]".into());
            let (tx, rx) = mpsc::sync_channel::<String>(1);
            {
                let mut slot = PENDING.lock().ok()?;
                if slot.is_some() {
                    return Some(Err(oii::EvalError {
                        code: "E199",
                        message: "a host call is already in flight".into(),
                    }));
                }
                *slot = Some(HostCall {
                    name: hname.to_string(),
                    args_json: args_json.clone(),
                    reply: tx,
                });
            }
            oii_bridge_host_callback(str_out(hname.to_string()), str_out(args_json));
            // Dart answered through oii_bridge_host_reply, or the call died
            match rx.recv() {
                Ok(json) => Some(Ok(json_value(&json))),
                Err(_) => Some(Err(oii::EvalError {
                    code: "E199",
                    message: "host call dropped".into(),
                })),
            }
        };
        oii::eval_call_host(&e.doc, &fname, &args, &e.opts, &mut host)
    };
    str_out(match result {
        Ok(out) => serde_json::json!({
            "ok": true,
            "value": value_to_json_wrapped(&out.value),
            "output": out.output,
            "steps": out.steps,
        })
        .to_string(),
        Err(e) => serde_json::json!({ "ok": false, "error": e.to_string() }).to_string(),
    })
}

fn value_to_json_wrapped(v: &Value) -> serde_json::Value {
    let text = value_to_json(v);
    serde_json::from_str(&text).unwrap_or(serde_json::Value::Null)
}

// ---------------------------------------------------------------- host reply

/// Dart's side of the round trip. Returns the pending call as
/// `{"name":"...","args":[...]}` or "null" when nothing waits.
#[no_mangle]
pub extern "C" fn oii_bridge_host_pending() -> *mut c_char {
    let slot = match PENDING.lock() {
        Ok(s) => s,
        Err(_) => return str_out("null".into()),
    };
    match slot.as_ref() {
        Some(call) => str_out(
            serde_json::json!({ "name": call.name, "args": call.args_json }).to_string(),
        ),
        None => str_out("null".into()),
    }
}

/// Hands the result json back to the blocked eval. False when no call waits.
#[no_mangle]
pub extern "C" fn oii_bridge_host_reply(result_json: *const c_char) -> c_int {
    let payload = str_in(result_json).to_string();
    let mut slot = match PENDING.lock() {
        Ok(s) => s,
        Err(_) => return 0,
    };
    match slot.take() {
        Some(call) => {
            let _ = call.reply.send(payload);
            1
        }
        None => 0,
    }
}

/// Installed by Dart at startup: reads the pending call and answers it.
/// Kept as a function pointer rather than a hard link so the bridge stays
/// loadable from any isolate setup Dart grows into.
static mut HOST_CALLBACK: Option<extern "C" fn(*const c_char, *const c_char)> = None;

#[no_mangle]
pub extern "C" fn oii_bridge_host_set_callback(
    cb: Option<extern "C" fn(*const c_char, *const c_char)>,
) {
    unsafe {
        HOST_CALLBACK = cb;
    }
}

fn oii_bridge_host_callback(name: *const c_char, args_json: *const c_char) {
    let cb = unsafe { HOST_CALLBACK };
    if let Some(cb) = cb {
        cb(name, args_json);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::sync::Arc;

    fn take(ptr: *mut c_char) -> String {
        unsafe { CString::from_raw(ptr) }.into_string().unwrap()
    }

    extern "C" fn fake_dart(name: *const c_char, args: *const c_char) {
        // the real callback runs on the dart isolate; here we read the
        // pending call and answer it synchronously, the same handshake.
        // int 21 rides as the json number 21, a bare oii word would ride
        // as a string; either way the reply is what the script sees
        let n = take(name as *mut c_char);
        let a = take(args as *mut c_char);
        assert_eq!(n, "double");
        let parsed: serde_json::Value = serde_json::from_str(&a).unwrap();
        assert_eq!(parsed, serde_json::json!([21]));
        let pending = take(oii_bridge_host_pending());
        assert!(pending.contains("double"));
        oii_bridge_host_reply(CString::new("42").unwrap().as_ptr());
        FLAG.store(true, Ordering::SeqCst);
    }

    static FLAG: AtomicBool = AtomicBool::new(false);

    #[test]
    fn host_round_trip() {
        oii_bridge_host_set_callback(Some(fake_dart));
        let e = oii_bridge_engine_new();
        let src = CString::new("fun main() [ return double(21) ]").unwrap();
        let out = take(oii_bridge_parse(e, src.as_ptr()));
        assert!(out.contains("\"ok\":true"), "parse: {out}");

        // register the host name, then the call reaches dart
        let hname = CString::new("double").unwrap();
        oii_bridge_engine_host_register(e, hname.as_ptr());
        let name = CString::new("main").unwrap();
        let args = CString::new("[]").unwrap();
        let out = take(oii_bridge_eval(e, name.as_ptr(), args.as_ptr()));
        assert!(out.contains("\"ok\":true"), "eval: {out}");
        assert!(out.contains("42"), "eval: {out}");
        assert!(FLAG.load(Ordering::SeqCst));
        oii_bridge_engine_free(e);
    }

    #[test]
    fn parse_error_reports_and_keeps_doc() {
        let e = oii_bridge_engine_new();
        let good = CString::new("fun main() [ return 1 ]").unwrap();
        let out = take(oii_bridge_parse(e, good.as_ptr()));
        assert!(out.contains("\"ok\":true"), "{out}");

        let bad = CString::new("fun main() [ let ]").unwrap();
        let out = take(oii_bridge_parse(e, bad.as_ptr()));
        assert!(out.contains("\"ok\":false"), "{out}");

        // the engine still runs the doc from before the bad parse
        let name = CString::new("main").unwrap();
        let args = CString::new("[]").unwrap();
        let out = take(oii_bridge_eval(e, name.as_ptr(), args.as_ptr()));
        assert!(out.contains("\"value\":1"), "{out}");
        oii_bridge_engine_free(e);
    }

    #[test]
    fn describe_folds_plugin_node_and_funcs() {
        let src = CString::new("plugin [\n  name: \"demo\"\n  desc: \"does things\"\n  entry: main\n]\nfun main() [\n  desc: \"runs it\"\n  return 1\n]\nfun helper() [ return 2 ]").unwrap();
        let out = take(oii_bridge_describe(src.as_ptr()));
        let v: serde_json::Value = serde_json::from_str(&out).unwrap();
        assert_eq!(v["ok"], true);
        assert_eq!(v["plugin"]["name"], "demo");
        assert_eq!(v["plugin"]["entry"], "main");
        let names: Vec<&str> = v["funcs"].as_array().unwrap().iter().map(|f| f["name"].as_str().unwrap()).collect();
        assert!(names.contains(&"main") && names.contains(&"helper"));
        let main = v["funcs"].as_array().unwrap().iter().find(|f| f["name"] == "main").unwrap();
        assert_eq!(main["desc"], "runs it");
        // no tool nodes, so nothing is exposed beyond the funcs
        assert!(v["tools"].as_array().unwrap().is_empty());
    }

    #[test]
    fn describe_folds_tool_and_resource_nodes() {
        let src = CString::new(concat!(
            "plugin [\n",
            "  id: \"para.demo\"\n",
            "  name: \"Demo\"\n",
            "  main: \"main.oii\"\n",
            "  tool audit [\n",
            "    file: \"skills/check.oii\"\n",
            "    entry: check\n",
            "    desc: \"Audit skills.\"\n",
            "    param query [ type: string, desc: \"Filter.\" ]\n",
            "    param limit [ type: int, default: 10 ]\n",
            "  ]\n",
            "  tool fetch [ file: \"skills/fetch.oii\", desc: \"Fetch.\" ]\n",
            "  /-tool off [ file: \"x.oii\" ]\n",
            "  resource logo [ file: \"res/logo.svg\", mime: \"image/svg+xml\" ]\n",
            "]\n"
        ))
        .unwrap();
        let out = take(oii_bridge_describe(src.as_ptr()));
        let v: serde_json::Value = serde_json::from_str(&out).unwrap();
        assert_eq!(v["ok"], true, "{v}");
        assert_eq!(v["plugin"]["id"], "para.demo");
        assert_eq!(v["plugin"]["main"], "main.oii");
        let tools = v["tools"].as_array().unwrap();
        // the slashdash node is skipped, so two tools reach the host
        assert_eq!(tools.len(), 2, "{v}");

        let audit = &tools[0];
        assert_eq!(audit["name"], "audit");
        assert_eq!(audit["file"], "skills/check.oii");
        assert_eq!(audit["entry"], "check");
        assert_eq!(audit["desc"], "Audit skills.");
        let params = audit["params"].as_array().unwrap();
        assert_eq!(params[0]["name"], "query");
        assert_eq!(params[0]["type"], "string");
        assert_eq!(params[0]["optional"], false);
        // `int` is manifest prose, the border speaks json schema
        assert_eq!(params[1]["type"], "integer");
        assert_eq!(params[1]["optional"], true);
        assert_eq!(params[1]["default"], 10);

        // no entry means the func named after the file stem
        assert_eq!(tools[1]["entry"], "fetch");
        assert_eq!(tools[1]["enabled"], true);

        let res = v["resources"].as_array().unwrap();
        assert_eq!(res[0]["key"], "logo");
        assert_eq!(res[0]["file"], "res/logo.svg");
        assert_eq!(res[0]["mime"], "image/svg+xml");
    }

    #[test]
    fn describe_infers_func_param_types_from_defaults() {
        let src = CString::new("fun run(a, b: 3, c: \"x\", d: true, e: [1 2]) [ return a ]").unwrap();
        let out = take(oii_bridge_describe(src.as_ptr()));
        let v: serde_json::Value = serde_json::from_str(&out).unwrap();
        let params = v["funcs"][0]["params"].as_array().unwrap();
        assert_eq!(params[0]["type"], "string");
        assert_eq!(params[0]["optional"], false);
        assert_eq!(params[1]["type"], "integer");
        assert_eq!(params[2]["type"], "string");
        assert_eq!(params[3]["type"], "boolean");
        assert_eq!(params[4]["type"], "array");
        assert_eq!(params[1]["optional"], true);
    }

    #[test]
    fn unknown_name_errors_cleanly() {
        let e = oii_bridge_engine_new();
        let src = CString::new("fun main() [ return nosuch() ]").unwrap();
        take(oii_bridge_parse(e, src.as_ptr()));
        let name = CString::new("main").unwrap();
        let args = CString::new("[]").unwrap();
        let out = take(oii_bridge_eval(e, name.as_ptr(), args.as_ptr()));
        assert!(out.contains("E100"), "{out}");
        oii_bridge_engine_free(e);
    }
}
