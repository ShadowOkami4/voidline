use std::env;
use std::path::PathBuf;
use vte::gtk;
use vte::gtk::gdk;
use vte::gtk::gio;
use vte::gtk::glib;
use vte::gtk::pango;
use vte::gtk::prelude::*;
use vte::prelude::*;

const APPLICATION_ID: &str = "org.voidline.Terminal";

fn login_shell() -> PathBuf {
    let fallback = PathBuf::from("/bin/sh");
    let Some(value) = env::var_os("SHELL") else {
        return fallback;
    };
    let candidate = PathBuf::from(value);
    if !candidate.is_absolute() || !candidate.is_file() {
        return fallback;
    }
    let Ok(canonical) = candidate.canonicalize() else {
        return fallback;
    };
    if canonical.starts_with("/usr/bin") || canonical.starts_with("/bin") {
        canonical
    } else {
        fallback
    }
}

fn working_directory() -> PathBuf {
    env::current_dir()
        .ok()
        .filter(|path| path.is_dir())
        .or_else(|| {
            env::var_os("HOME")
                .map(PathBuf::from)
                .filter(|path| path.is_dir())
        })
        .unwrap_or_else(|| PathBuf::from("/"))
}

fn environment() -> Vec<String> {
    env::vars()
        .filter_map(|(name, value)| {
            if name.contains('\0') || value.contains('\0') {
                None
            } else {
                Some(format!("{name}={value}"))
            }
        })
        .collect()
}

fn configure_terminal(terminal: &vte::Terminal) {
    terminal.set_scrollback_lines(10_000);
    terminal.set_scroll_on_keystroke(true);
    terminal.set_scroll_on_output(false);
    terminal.set_mouse_autohide(true);
    terminal.set_allow_hyperlink(true);
    terminal.set_bold_is_bright(true);
    terminal.set_cursor_blink_mode(vte::CursorBlinkMode::System);
    terminal.set_font(Some(&pango::FontDescription::from_string("Monospace 11")));
    terminal.set_color_background(&gdk::RGBA::new(0.075, 0.09, 0.105, 1.0));
    terminal.set_color_foreground(&gdk::RGBA::new(0.86, 0.91, 0.90, 1.0));
}

fn install_shortcuts(terminal: &vte::Terminal) {
    let controller = gtk::EventControllerKey::new();
    let shortcut_terminal = terminal.clone();
    controller.connect_key_pressed(move |_, key, _, modifiers| {
        let control = modifiers.contains(gdk::ModifierType::CONTROL_MASK);
        let shift = modifiers.contains(gdk::ModifierType::SHIFT_MASK);
        let character = key.to_unicode().map(|value| value.to_ascii_lowercase());
        if control && shift && character == Some('c') {
            shortcut_terminal.emit_copy_clipboard();
            return glib::Propagation::Stop;
        }
        if control && shift && character == Some('v') {
            shortcut_terminal.paste_clipboard();
            return glib::Propagation::Stop;
        }
        if control && (character == Some('+') || character == Some('=')) {
            shortcut_terminal.set_font_scale((shortcut_terminal.font_scale() + 0.1).min(3.0));
            return glib::Propagation::Stop;
        }
        if control && character == Some('-') {
            shortcut_terminal.set_font_scale((shortcut_terminal.font_scale() - 0.1).max(0.5));
            return glib::Propagation::Stop;
        }
        if control && character == Some('0') {
            shortcut_terminal.set_font_scale(1.0);
            return glib::Propagation::Stop;
        }
        glib::Propagation::Proceed
    });
    terminal.add_controller(controller);
}

fn spawn_shell(terminal: &vte::Terminal, window: &gtk::ApplicationWindow) {
    let shell = login_shell();
    let shell_text = shell.to_string_lossy().to_string();
    let directory = working_directory();
    let directory_text = directory.to_string_lossy().to_string();
    let environment = environment();
    let environment_refs: Vec<&str> = environment.iter().map(String::as_str).collect();
    let arguments = [shell_text.as_str()];
    let shell_error_name = shell_text.clone();
    let weak_window = window.downgrade();

    terminal.spawn_async(
        vte::PtyFlags::DEFAULT,
        Some(&directory_text),
        &arguments,
        &environment_refs,
        glib::SpawnFlags::DEFAULT,
        || {},
        -1,
        gio::Cancellable::NONE,
        move |result| {
            if let Err(error) = result {
                eprintln!("Voidline Terminal could not start {shell_error_name}: {error}");
                if let Some(window) = weak_window.upgrade() {
                    window.set_title(Some("Voidline Terminal — shell failed to start"));
                }
            }
        },
    );
}

fn build_window(application: &gtk::Application) {
    let terminal = vte::Terminal::new();
    configure_terminal(&terminal);
    install_shortcuts(&terminal);

    let window = gtk::ApplicationWindow::builder()
        .application(application)
        .title("Voidline Terminal")
        .default_width(920)
        .default_height(600)
        .child(&terminal)
        .build();

    let weak_window = window.downgrade();
    terminal.connect_child_exited(move |_, _status| {
        if let Some(window) = weak_window.upgrade() {
            window.close();
        }
    });
    spawn_shell(&terminal, &window);
    window.present();
}

fn main() -> glib::ExitCode {
    match env::args().nth(1).as_deref() {
        Some("--version" | "-V") => {
            println!("voidline-terminal 0.3.0dev");
            return glib::ExitCode::SUCCESS;
        }
        Some("--help" | "-h") => {
            println!("Voidline Terminal 0.3.0dev\n\nUsage: voidline-terminal");
            return glib::ExitCode::SUCCESS;
        }
        _ => {}
    }
    let application = gtk::Application::builder()
        .application_id(APPLICATION_ID)
        .build();
    application.connect_activate(build_window);
    application.run()
}
