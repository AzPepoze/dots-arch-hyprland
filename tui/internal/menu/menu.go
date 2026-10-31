package menu

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"tui/internal/logger"
	"tui/internal/repo"
	"tui/internal/runner"
)

type MenuState int

const (
	StateMainMenu MenuState = iota
	StateUtilsMenu
	StateWaitingKey
)

type MenuAction int

const (
	actionNone MenuAction = iota
	actionInstall
	actionConfig
	actionUtils
	actionQuit
	actionBack
)

type MenuOption struct {
	Text     string
	IsHeader bool
	Action   MenuAction
	Script   string
	Args     []string
	Sudo     bool
}

func scriptPath(repoDir, rel string) string {
	return repo.CLIScript(repoDir, rel)
}

type processFinishedMsg struct {
	err error
}

type MenuModel struct {
	repoDir    string
	state      MenuState
	cursor     int
	mainOpts   []MenuOption
	utilOpts   []MenuOption
	nextState  MenuState
	processErr error
}

func NewMenuModel(repoDir string) MenuModel {
	return MenuModel{
		repoDir: repoDir,
		state:   StateMainMenu,
		mainOpts: []MenuOption{
			{Text: "Run Package Installer", Action: actionInstall},
			{Text: "Open Configuration Editor", Action: actionConfig},
			{Text: "Load Dotfile Configurations", Script: repo.LoadConfigsScript(repoDir)},
			{Text: "Update System (Normal)", Script: filepath.Join(repoDir, "update.sh"), Args: []string{"--skip-cursor", "--skip-gpu"}},
			{Text: "Update System (Full)", Script: filepath.Join(repoDir, "update.sh"), Args: []string{"--full"}},
			{Text: "Open Utility Tools Menu", Action: actionUtils},
			{Text: "Wi-Fi Stability Workarounds", Script: scriptPath(repoDir, "configs/wifi_stability.sh")},
			{Text: "Quit", Action: actionQuit},
		},
		utilOpts: []MenuOption{
			{Text: "--- Interactive Configurations ---", IsHeader: true},
			{Text: "Configure Cursor Theme", Script: scriptPath(repoDir, "configs/cursor.sh")},
			{Text: "Configure GPU Devices", Script: scriptPath(repoDir, "configs/gpu.sh")},
			{Text: "Manage Drives (fstab auto-mount)", Script: scriptPath(repoDir, "mount_drive_manager.sh")},
			{Text: "Select Boot Entry (Reboot)", Script: scriptPath(repoDir, "boot_to.sh")},
			{Text: "--- System Maintenance & Helpers ---", IsHeader: true},
			{Text: "Run System Cleanup", Script: scriptPath(repoDir, "utils/cleanup.sh")},
			{Text: "Empty Trash Files", Script: scriptPath(repoDir, "utils/clear_trash.sh")},
			{Text: "Rank Package Mirrors", Script: scriptPath(repoDir, "utils/rank_mirrors.sh")},
			{Text: "Compile Cursor Themes (win2xcur)", Script: scriptPath(repoDir, "utils/build_cursors.sh")},
			{Text: "Set Kitty as Default Terminal", Script: scriptPath(repoDir, "utils/set_kitty_main_terminal.sh")},
			{Text: "Force Reload QuickShell", Script: scriptPath(repoDir, "utils/force_reload_quickshell.sh")},
			{Text: "SSH Key Manager", Script: scriptPath(repoDir, "ssh_key_manager.sh")},
			{Text: "Reset QuickShell Settings (Illogical Impulse)", Script: scriptPath(repoDir, "utils/reset_quickshell.sh")},
			{Text: "--- Special Configurations & Fun ---", IsHeader: true},
			{Text: "Enable/Disable SDDM Autologin", Script: scriptPath(repoDir, "configs/auto_login.sh"), Sudo: true},
			{Text: "Amogus Sus Cowsay", Script: scriptPath(repoDir, "utils/amogus.sh")},
			{Text: "Back to Main Menu", Action: actionBack},
		},
	}
}

func (m MenuModel) Init() tea.Cmd {
	return nil
}

func (m MenuModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case processFinishedMsg:
		m.state = StateWaitingKey
		m.processErr = msg.err
		if msg.err != nil {
			logger.Error("menu", "Process failed: %v", msg.err)
		}
		return m, nil
	case tea.KeyMsg:
		if m.state == StateWaitingKey {
			if msg.String() == "enter" {
				m.state = m.nextState
				if m.state == StateUtilsMenu {
					m.cursor = 1
				} else {
					m.cursor = 0
				}
			}
			return m, nil
		}

		opts := m.mainOpts
		if m.state == StateUtilsMenu {
			opts = m.utilOpts
		}

		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
				for m.cursor > 0 && opts[m.cursor].IsHeader {
					m.cursor--
				}
				if opts[m.cursor].IsHeader {
					for i, opt := range opts {
						if !opt.IsHeader {
							m.cursor = i
							break
						}
					}
				}
			}
		case "down", "j":
			if m.cursor < len(opts)-1 {
				m.cursor++
				for m.cursor < len(opts)-1 && opts[m.cursor].IsHeader {
					m.cursor++
				}
				if opts[m.cursor].IsHeader {
					m.cursor = len(opts) - 1
				}
			}
		case "enter", " ":
			switch m.state {
			case StateMainMenu:
				return m.handleMainSelect()
			case StateUtilsMenu:
				return m.handleUtilsSelect()
			}
		}
	}
	return m, nil
}

func (m MenuModel) handleMainSelect() (tea.Model, tea.Cmd) {
	return m.selectOption(StateMainMenu, m.mainOpts[m.cursor])
}

func (m MenuModel) handleUtilsSelect() (tea.Model, tea.Cmd) {
	return m.selectOption(StateUtilsMenu, m.utilOpts[m.cursor])
}

func (m MenuModel) selectOption(next MenuState, opt MenuOption) (tea.Model, tea.Cmd) {
	switch opt.Action {
	case actionInstall:
		return m.run(next, exec.Command(os.Args[0], "install"))
	case actionConfig:
		return m.run(next, exec.Command(os.Args[0], "config"))
	case actionUtils:
		m.state = StateUtilsMenu
		m.cursor = 1
		return m, nil
	case actionQuit:
		return m, tea.Quit
	case actionBack:
		m.state = StateMainMenu
		m.cursor = 0
		return m, nil
	}

	if opt.Script != "" {
		return m.runScript(next, opt)
	}
	return m, nil
}

func (m MenuModel) runScript(next MenuState, opt MenuOption) (tea.Model, tea.Cmd) {
	if opt.Sudo {
		args := append([]string{"bash", opt.Script}, opt.Args...)
		return m.run(next, exec.Command("sudo", args...))
	}
	return m.run(next, runner.Bash(opt.Script, opt.Args...))
}

func (m MenuModel) run(next MenuState, c *exec.Cmd) (tea.Model, tea.Cmd) {
	m.nextState = next
	m.processErr = nil
	return m, tea.ExecProcess(c, func(err error) tea.Msg {
		return processFinishedMsg{err}
	})
}

func (m MenuModel) View() string {
	if m.state == StateWaitingKey {
		message := "Process finished. Press Enter to return to the menu..."
		if m.processErr != nil {
			message = fmt.Sprintf("Process failed: %v. Press Enter to return to the menu...", m.processErr)
		}
		return lipgloss.NewStyle().Foreground(lipgloss.Color("#98C379")).Bold(true).Render("\n" + message + "\n")
	}

	var lines []string

	headerColor := "#61AFEF"
	titleText := "Az Arch Hyprland Management Menu"
	opts := m.mainOpts

	if m.state == StateUtilsMenu {
		headerColor = "#C678DD"
		titleText = "System Utility CLI Tools"
		opts = m.utilOpts
	}

	headerStyle := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color(headerColor)).Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color(headerColor)).Padding(0, 2)
	lines = append(lines, headerStyle.Render(titleText))
	lines = append(lines, "")

	index := 1
	for i, opt := range opts {
		if opt.IsHeader {
			lines = append(lines, "")
			lines = append(lines, lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#E06C75")).Render(opt.Text))
			continue
		}

		cursorStr := "  "
		if i == m.cursor {
			cursorStr = "> "
		}
		line := fmt.Sprintf("%s%d) %s", cursorStr, index, opt.Text)
		if i == m.cursor {
			line = lipgloss.NewStyle().Foreground(lipgloss.Color("#98C379")).Bold(true).Render(line)
		}
		lines = append(lines, line)
		index++
	}

	lines = append(lines, "")
	footerStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("#5C6370")).Italic(true)
	lines = append(lines, footerStyle.Render("up/down or j/k: navigate | enter/space: select | q: quit"))

	return lipgloss.JoinVertical(lipgloss.Left, lines...) + "\n"
}

func Run(repoDir string) error {
	c := exec.Command("fastfetch")
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	_ = c.Run()
	logger.Info("menu", "Starting main menu")

	m := NewMenuModel(repoDir)
	p := tea.NewProgram(m)
	_, err := p.Run()
	return err
}
