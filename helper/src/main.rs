//! voidlinectl - small, optional companion to the Voidline shell.
//!
//! It does two things the QML side should not do itself:
//!   * validated edits of ~/.config/voidline/config.json (known keys, typed values)
//!   * a `doctor` check that tells a new user what is missing
//! Everything else is forwarded to the running shell over Quickshell IPC.

use serde_json::{Map, Value};
use std::path::PathBuf;
use std::process::{exit, Command};
use std::{env, fs};

const STYLES: [&str; 3] = ["voidline", "windows", "macos"];
const PANELS: [&str; 2] = ["launcher", "quick"];

/// Known settings and how to parse them.
enum Kind {
    Bool,
    Int(i64, i64),
    Float(f64, f64),
    Text,
    OneOf(&'static [&'static str]),
    Color,
}

const KEYS: [(&str, Kind); 10] = [
    ("style", Kind::OneOf(&STYLES)),
    ("dark", Kind::Bool),
    ("accent", Kind::Color),
    ("wallpaper", Kind::Text),
    ("wallpaperColors", Kind::Bool),
    ("clock24h", Kind::Bool),
    ("reduceMotion", Kind::Bool),
    ("doNotDisturb", Kind::Bool),
    ("workspaceCount", Kind::Int(1, 20)),
    ("uiScale", Kind::Float(0.5, 1.5)),
];

fn usage() -> ! {
    eprintln!(
        "voidlinectl {}\n\n\
         usage:\n  \
         voidlinectl toggle <launcher|quick>\n  \
         voidlinectl close\n  \
         voidlinectl style <voidline|windows|macos|next>\n  \
         voidlinectl minimize | restore\n  \
         voidlinectl get [key]\n  \
         voidlinectl set <key> <value>\n  \
         voidlinectl doctor",
        env!("CARGO_PKG_VERSION")
    );
    exit(2)
}

fn fail(msg: &str) -> ! {
    eprintln!("voidlinectl: {msg}");
    exit(1)
}

fn ipc(args: &[&str]) -> ! {
    let status = Command::new("qs")
        .args(["-c", "voidline", "ipc", "call", "shell"])
        .args(args)
        .status()
        .unwrap_or_else(|_| fail("could not run `qs` (is quickshell installed?)"));
    exit(status.code().unwrap_or(1))
}

fn config_path() -> PathBuf {
    let base = env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .filter(|p| p.is_absolute())
        .or_else(|| env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")))
        .unwrap_or_else(|| fail("HOME is not set"));
    base.join("voidline").join("config.json")
}

fn load() -> Map<String, Value> {
    match fs::read_to_string(config_path()) {
        Ok(text) => match serde_json::from_str::<Value>(&text) {
            Ok(Value::Object(map)) => map,
            _ => fail("config.json is not a JSON object; fix or delete it"),
        },
        Err(_) => Map::new(),
    }
}

fn parse(key: &str, raw: &str) -> Value {
    let kind = KEYS
        .iter()
        .find(|(k, _)| *k == key)
        .map(|(_, kind)| kind)
        .unwrap_or_else(|| {
            let known: Vec<&str> = KEYS.iter().map(|(k, _)| *k).collect();
            fail(&format!("unknown key `{key}` (known: {})", known.join(", ")))
        });
    match kind {
        Kind::Bool => match raw {
            "true" | "on" | "1" | "yes" => Value::Bool(true),
            "false" | "off" | "0" | "no" => Value::Bool(false),
            _ => fail(&format!("`{key}` expects true or false")),
        },
        Kind::Int(min, max) => match raw.parse::<i64>() {
            Ok(n) if (*min..=*max).contains(&n) => Value::from(n),
            _ => fail(&format!("`{key}` expects a number from {min} to {max}")),
        },
        Kind::Float(min, max) => match raw.parse::<f64>() {
            Ok(n) if n >= *min && n <= *max => Value::from(n),
            _ => fail(&format!("`{key}` expects a number from {min} to {max}")),
        },
        Kind::OneOf(options) => {
            if options.contains(&raw) {
                Value::from(raw)
            } else {
                fail(&format!("`{key}` expects one of: {}", options.join(", ")))
            }
        }
        Kind::Color => {
            let hex = raw.strip_prefix('#').unwrap_or("");
            if hex.len() == 6 && hex.chars().all(|c| c.is_ascii_hexdigit()) {
                Value::from(raw)
            } else {
                fail(&format!("`{key}` expects a colour like #8E6BFF"))
            }
        }
        Kind::Text => {
            if key == "wallpaper" && !raw.is_empty() && raw != "default" && !PathBuf::from(raw).is_file() {
                fail("wallpaper must be an existing file, \"default\", or \"\" for none");
            }
            Value::from(raw)
        }
    }
}

fn set(key: &str, raw: &str) {
    let value = parse(key, raw);
    let mut map = load();
    map.insert(key.to_string(), value);
    let path = config_path();
    if let Some(dir) = path.parent() {
        fs::create_dir_all(dir).unwrap_or_else(|e| fail(&format!("cannot create {}: {e}", dir.display())));
    }
    // Write to a temp file and rename so the shell never reads a half-written file.
    let tmp = path.with_extension("json.tmp");
    let text = serde_json::to_string_pretty(&Value::Object(map)).unwrap() + "\n";
    fs::write(&tmp, text).unwrap_or_else(|e| fail(&format!("cannot write config: {e}")));
    fs::rename(&tmp, &path).unwrap_or_else(|e| fail(&format!("cannot write config: {e}")));
}

fn get(key: Option<&str>) {
    let map = load();
    match key {
        None => println!("{}", serde_json::to_string_pretty(&Value::Object(map)).unwrap()),
        Some(k) => match map.get(k) {
            Some(Value::String(s)) => println!("{s}"),
            Some(v) => println!("{v}"),
            None => fail(&format!("`{k}` is not set")),
        },
    }
}

fn has(program: &str) -> bool {
    env::var_os("PATH")
        .map(|paths| env::split_paths(&paths).any(|dir| dir.join(program).is_file()))
        .unwrap_or(false)
}

fn doctor() {
    let mut problems = 0;
    let mut check = |ok: bool, required: bool, label: &str, hint: &str| {
        let mark = if ok { "ok  " } else if required { "FAIL" } else { "warn" };
        println!("[{mark}] {label}{}", if ok { String::new() } else { format!(" - {hint}") });
        if !ok && required {
            problems += 1;
        }
    };

    let compositor = if env::var_os("NIRI_SOCKET").is_some() {
        "niri"
    } else if env::var_os("HYPRLAND_INSTANCE_SIGNATURE").is_some() {
        "hyprland"
    } else {
        ""
    };
    check(!compositor.is_empty(), true,
        &format!("compositor: {}", if compositor.is_empty() { "none detected" } else { compositor }),
        "run this inside a Hyprland or Niri session");
    check(has("qs"), true, "quickshell", "pacman -S quickshell");

    let fonts = Command::new("fc-list").arg(":").arg("family").output()
        .map(|o| String::from_utf8_lossy(&o.stdout).to_string()).unwrap_or_default();
    check(fonts.contains("Material Symbols"), true, "icon font (Material Symbols)",
        "pacman -S ttf-material-symbols-variable");
    check(has("brightnessctl"), false, "brightnessctl", "brightness slider hidden; pacman -S brightnessctl");
    check(has("nmcli"), false, "NetworkManager", "network tile disabled; pacman -S networkmanager");

    let home = env::var_os("HOME").map(PathBuf::from).unwrap_or_default();
    let config = env::var_os("XDG_CONFIG_HOME").map(PathBuf::from).unwrap_or_else(|| home.join(".config"));
    check(config.join("quickshell/voidline/shell.qml").is_file(), true,
        "shell files", "run ./install.sh from the Voidline repository");

    exit(if problems == 0 { 0 } else { 1 })
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let args: Vec<&str> = args.iter().map(String::as_str).collect();
    match args.as_slice() {
        ["toggle", panel] if PANELS.contains(panel) => ipc(&["toggle", panel]),
        ["close"] => ipc(&["close"]),
        ["style", name] if *name == "next" || STYLES.contains(name) => ipc(&["style", name]),
        ["minimize"] => ipc(&["minimize"]),
        ["restore"] => ipc(&["restore"]),
        ["get"] => get(None),
        ["get", key] => get(Some(key)),
        ["set", key, value] => set(key, value),
        ["doctor"] => doctor(),
        _ => usage(),
    }
}
