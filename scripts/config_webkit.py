import sys
import os
import json
import gi
import subprocess
import tempfile
import stat

# Use GTK3 and WebKit2 for compatibility
gi.require_version('Gtk', '3.0')
gi.require_version('WebKit2', '4.1')

from gi.repository import Gtk, WebKit2, GLib

class ConfigWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="Az Arch Hyprland - Configuration")
        self.set_default_size(800, 600)
        self.connect("destroy", Gtk.main_quit)

        self.repo_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.config_path = os.path.join(self.repo_dir, "config.json")
        
        # WebKit Setup
        self.webview = WebKit2.WebView()
        
        # Bridge Setup
        content_manager = self.webview.get_user_content_manager()
        content_manager.register_script_message_handler("controller")
        content_manager.connect("script-message-received::controller", self.on_message_received)

        # Load UI
        ui_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'webkit_ui', 'config.html')
        self.webview.load_uri(f"file://{ui_path}")

        # Add to window
        scrolled_window = Gtk.ScrolledWindow()
        scrolled_window.add(self.webview)
        self.add(scrolled_window)

        # DevTools
        settings = self.webview.get_settings()
        settings.set_enable_developer_extras(True)

    def on_message_received(self, content_manager, js_result):
        js_value = js_result.get_js_value()
        message = js_value.to_json(0)
        data = json.loads(message)
        
        action = data.get('action')
        
        if action == 'load_config':
            self.send_config_to_js()
        elif action == 'save_config':
            self.save_config(data.get('config'))

    def send_config_to_js(self):
        config_data = {}
        if os.path.exists(self.config_path):
            try:
                with open(self.config_path, "r") as f:
                    config_data = json.load(f)
            except Exception as e:
                print(f"Error loading config: {e}")
        
        json_data = json.dumps(config_data)
        script = f"receiveConfig({json_data})"
        self.webview.run_javascript(script, None, None, None)

    def save_config(self, new_config):
        if new_config is None:
            return

        try:
            with open(self.config_path, "w") as f:
                json.dump(new_config, f, indent=4)
            
            # Show success message in UI
            self.webview.run_javascript("alert('Configuration saved successfully! Reloading...');", None, None, None)
            
            # Run load_configs.sh
            self.run_load_configs()

        except Exception as e:
            self.webview.run_javascript(f"alert('Error saving config: {str(e)}');", None, None, None)

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

if __name__ == "__main__":
    win = ConfigWindow()
    win.show_all()
    Gtk.main()
