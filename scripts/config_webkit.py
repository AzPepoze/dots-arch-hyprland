import sys
import os
import json
import gi
import subprocess
import tempfile
import stat

# Use GTK4 and WebKit6 for modern standards
gi.require_version('Gtk', '4.0')
gi.require_version('WebKit', '6.0')

from gi.repository import Gtk, WebKit, GLib

class ConfigWindow(Gtk.ApplicationWindow):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.set_title("Az Arch Hyprland - Configuration")
        self.set_default_size(800, 600)

        self.repo_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.config_path = os.path.join(self.repo_dir, "config.json")
        
        # WebKit Setup
        self.webview = WebKit.WebView()
        
        # Bridge Setup
        content_manager = self.webview.get_user_content_manager()
        print("Registering script message handler...")
        content_manager.register_script_message_handler("controller", None)
        content_manager.connect("script-message-received::controller", self.on_message_received)

        # Load UI
        ui_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'webkit_ui', 'config.html')
        print(f"Loading UI from: {ui_path}")
        self.webview.load_uri(f"file://{ui_path}")

        # Add to window
        scrolled_window = Gtk.ScrolledWindow()
        scrolled_window.set_child(self.webview)
        self.set_child(scrolled_window)

        # DevTools
        settings = self.webview.get_settings()
        settings.set_enable_developer_extras(True)
        settings.set_allow_file_access_from_file_urls(True)
        settings.set_allow_universal_access_from_file_urls(True)

    def on_message_received(self, manager, js_value):
        try:
            message = js_value.to_json(0)
            data = json.loads(message)
            
            action = data.get('action')
            
            if action == 'load_config':
                self.send_config_to_js()
            elif action == 'save_config':
                self.save_config(data.get('config'))
        except Exception as e:
            print(f"Error processing message: {e}")
            
            action = data.get('action')
            
            if action == 'load_config':
                self.send_config_to_js()
            elif action == 'save_config':
                self.save_config(data.get('config'))
        except Exception as e:
            print(f"Error processing message: {e}")

    def send_config_to_js(self):
        print("Sending config to JS...")
        config_data = {}
        if os.path.exists(self.config_path):
            try:
                with open(self.config_path, "r") as f:
                    config_data = json.load(f)
            except Exception as e:
                print(f"Error loading config: {e}")
        
        json_data = json.dumps(config_data)
        script = f"receiveConfig({json_data})"
        self.webview.evaluate_javascript(script, -1, None, None, None, None, None)

    def save_config(self, new_config):
        if new_config is None:
            return

        try:
            with open(self.config_path, "w") as f:
                json.dump(new_config, f, indent=4)
            
            # Show success message in UI
            self.webview.evaluate_javascript("alert('Configuration saved successfully! Reloading...');", -1, None, None, None, None, None)
            
            # Run load_configs.sh
            self.run_load_configs()

        except Exception as e:
            self.webview.evaluate_javascript(f"alert('Error saving config: {str(e)}');", -1, None, None, None, None, None)

    def run_load_configs(self):
        script_path = os.path.join(self.repo_dir, "cli", "load_configs.sh")
        if not os.path.exists(script_path):
            return

        try:
            # Command to run the script and then wait for user input
            cmd = f"bash '{script_path}' --skip-gpu --skip-cursor; echo; read -p 'Press Enter to close...'"
            
            subprocess.Popen(
                ["kitty", "--title", "Reloading Configs", "bash", "-c", cmd]
            )
        except Exception as e:
            print(f"Failed to launch terminal: {e}")

def on_activate(app):
    win = ConfigWindow(application=app)
    win.present()

if __name__ == "__main__":
    app = Gtk.Application(application_id="com.az.arch.config")
    app.connect("activate", on_activate)
    app.run(None)
