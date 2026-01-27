import sys
import os
import json
import gi
import subprocess
import tempfile
import stat

# Use GTK3 and WebKit2 for compatibility
gi.require_version('Gtk', '3.0')
gi.require_version('WebKit2', '4.1') # Try 4.1 first, fallback can be handled if needed

from gi.repository import Gtk, WebKit2, GLib

# Add the script's directory to the Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from installer_components.installer_core import InstallerCore

class InstallerWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="Az Arch Hyprland Installer")
        self.set_default_size(900, 700)
        self.connect("destroy", Gtk.main_quit)

        self.repo_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self.installer_core = InstallerCore(self.repo_dir)

        # WebKit Setup
        self.webview = WebKit2.WebView()
        
        # Bridge Setup
        content_manager = self.webview.get_user_content_manager()
        # In WebKit2, we register the handler like this
        content_manager.register_script_message_handler("controller")
        content_manager.connect("script-message-received::controller", self.on_message_received)

        # Load UI
        ui_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'webkit_ui', 'index.html')
        self.webview.load_uri(f"file://{ui_path}")

        # Add to window (GTK3 uses add() instead of set_child())
        scrolled_window = Gtk.ScrolledWindow()
        scrolled_window.add(self.webview)
        self.add(scrolled_window)

        # DevTools
        settings = self.webview.get_settings()
        settings.set_enable_developer_extras(True)

    def on_message_received(self, content_manager, js_result):
        # WebKit2 message handling
        js_value = js_result.get_js_value()
        message = js_value.to_json(0)
        data = json.loads(message)
        
        action = data.get('action')
        
        if action == 'get_items':
            self.send_items_to_js()
        elif action == 'update_selection':
            self.installer_core.update_item_selection(data['id'], data['is_selected'])
        elif action == 'select_essential':
            self.installer_core.select_essential()
            self.send_items_to_js()
        elif action == 'select_essential_laptop':
            self.installer_core.select_essential_laptop()
            self.send_items_to_js()
        elif action == 'select_all':
            self.installer_core.select_all()
            self.send_items_to_js()
        elif action == 'deselect_all':
            self.installer_core.deselect_all()
            self.send_items_to_js()
        elif action == 'run_installation':
            self.run_installation()

    def send_items_to_js(self):
        items = self.installer_core.get_display_items()
        json_items = json.dumps(items)
        script = f"receiveItems({json_items})"
        # WebKit2 uses run_javascript
        self.webview.run_javascript(script, None, None, None)

    def run_installation(self):
        commands_to_run = self.installer_core.get_selected_commands()
        if not commands_to_run:
            self.show_alert("No items were selected for installation.")
            return

        script_content = self._generate_install_script(commands_to_run)
        
        try:
            with tempfile.NamedTemporaryFile(
                mode="w+", delete=False, suffix=".sh", prefix="az-installer-"
            ) as temp_script:
                temp_script.write(script_content)
                script_path = temp_script.name
            
            os.chmod(script_path, stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR)
            
            subprocess.Popen(
                ["kitty", "--title", "Installation Process", "bash", script_path]
            )
            
        except FileNotFoundError:
            self.show_alert("Could not find 'kitty'. Please ensure it is installed.")
        except Exception as e:
            self.show_alert(f"Failed to launch installer: {e}")

    def show_alert(self, message):
        script = f"alert('{message}')"
        self.webview.run_javascript(script, None, None, None)

    def _generate_install_script(self, commands):
        modules_dir = os.path.join(self.repo_dir, "scripts", "install_modules")

        # Use raw string (r"...") to handle backslashes for bash escape sequences correctly
        run_command_func = r"""
run_command() {
    local command_to_run="$1"
    echo -e "\n\e[1;34m--- Running: ${command_to_run} ---\e[0m"
    while true; do
        eval "${command_to_run}"
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            echo -e "\n\e[1;32m--- Finished: ${command_to_run} ---\e[0m"
            return 0
        else
            echo -e "\n\e[1;31m--- ERROR: Command \"${command_to_run}\" failed with exit code $exit_code. ---\e[0m"
            read -p "      [R]etry, [I]gnore, or [A]bort? " choice
            case "$choice" in
                [rR]) echo -e "\n\e[1;33m--- Retrying... ---\e[0m"; continue ;; 
                [iI]) echo -e "\n\e[1;33m--- Ignoring... ---\e[0m"; return 0 ;; 
                [aA]) echo -e "\n\e[1;31m--- Aborting. ---\e[0m"; exit 1 ;; 
                *) echo -e "\n\e[1;33m--- Retrying... ---\e[0m"; continue ;; 
            esac
        fi
    done
}
"""
        script_lines = ["#!/bin/bash", f'export repo_dir="{self.repo_dir}"']
        script_lines.append(
            "trap 'echo; read -p \"--- Script finished. Press Enter to close terminal. ---\"' EXIT"
        )
        script_lines.append(run_command_func)

        # Source helpers.sh first to ensure utility functions are available
        helpers_path = os.path.join(modules_dir, "helpers.sh")
        if os.path.exists(helpers_path):
            script_lines.append(f"source {helpers_path}")

        for filename in sorted(os.listdir(modules_dir)):
            if filename.endswith(".sh") and filename != "helpers.sh":
                script_lines.append(f"source {os.path.join(modules_dir, filename)}")

        for command in commands:
            script_lines.append(f"run_command '{command}'")

        return "\n".join(script_lines)

if __name__ == "__main__":
    win = InstallerWindow()
    win.show_all()
    Gtk.main()