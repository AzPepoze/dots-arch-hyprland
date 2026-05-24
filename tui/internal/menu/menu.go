package menu

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type MenuState int

const (
	StateMainMenu MenuState = iota
	StateUtilsMenu
	StateWaitingKey
)

type MenuOption struct {
	Text     string
	IsHeader bool
	ActionID int
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
	waitingMsg string
	nextState  MenuState
}

func NewMenuModel(repoDir string) MenuModel {
	return MenuModel{
		repoDir: repoDir,
		state:   StateMainMenu,
		cursor:  0,
		mainOpts: []MenuOption{
			{Text: "Run Package Installer", ActionID: 0},
			{Text: "Open Configuration Editor", ActionID: 1},
			{Text: "Load Dotfile Configurations", ActionID: 2},
			{Text: "Update System (Normal)", ActionID: 3},
			{Text: "Update System (Full)", ActionID: 4},
			{Text: "Open Utility Tools Menu", ActionID: 5},
			{Text: "Quit", ActionID: 6},
		},
		utilOpts: []MenuOption{
			{Text: "--- Interactive Configurations ---", IsHeader: true},
			{Text: "Configure Cursor Theme", ActionID: 0},
			{Text: "Configure GPU Devices", ActionID: 1},
			{Text: "Manage Drives (fstab auto-mount)", ActionID: 2},
			{Text: "Select Boot Entry (Reboot)", ActionID: 3},
			{Text: "--- System Maintenance & Helpers ---", IsHeader: true},
			{Text: "Run System Cleanup", ActionID: 4},
			{Text: "Empty Trash Files", ActionID: 5},
			{Text: "Rank Package Mirrors", ActionID: 6},
			{Text: "Compile Cursor Themes (win2xcur)", ActionID: 7},
			{Text: "Set Kitty as Default Terminal", ActionID: 8},
			{Text: "Force Reload QuickShell", ActionID: 9},
			{Text: "Reset QuickShell Settings (Illogical Impulse)", ActionID: 13},
			{Text: "--- Special Configurations & Fun ---", IsHeader: true},
			{Text: "Enable/Disable SDDM Autologin", ActionID: 10},
			{Text: "Amogus Sus Cowsay", ActionID: 11},
			{Text: "Back to Main Menu", ActionID: 12},
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
		m.waitingMsg = "Process finished. Press Enter to return to the menu..."
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
	selected := m.mainOpts[m.cursor]
	switch selected.ActionID {
	case 0:
		c := exec.Command(os.Args[0], "install")
		m.nextState = StateMainMenu
		return m, tea.ExecProcess(c, func(err error) tea.Msg {
			return processFinishedMsg{err}
		})
	case 1:
		c := exec.Command(os.Args[0], "config")
		m.nextState = StateMainMenu
		return m, tea.ExecProcess(c, func(err error) tea.Msg {
			return processFinishedMsg{err}
		})
	case 2:
		c := exec.Command("bash", filepath.Join(m.repoDir, "cli", "load_configs.sh"))
		m.nextState = StateMainMenu
		return m, tea.ExecProcess(c, func(err error) tea.Msg {
			return processFinishedMsg{err}
		})
	case 3:
		c := exec.Command("bash", filepath.Join(m.repoDir, "update.sh"), "--skip-cursor", "--skip-gpu")
		m.nextState = StateMainMenu
		return m, tea.ExecProcess(c, func(err error) tea.Msg {
			return processFinishedMsg{err}
		})
	case 4:
		c := exec.Command("bash", filepath.Join(m.repoDir, "update.sh"), "--full")
		m.nextState = StateMainMenu
		return m, tea.ExecProcess(c, func(err error) tea.Msg {
			return processFinishedMsg{err}
		})
	case 5:
		m.state = StateUtilsMenu
		m.cursor = 1
		return m, nil
	case 6:
		return m, tea.Quit
	}
	return m, nil
}

func (m MenuModel) handleUtilsSelect() (tea.Model, tea.Cmd) {
	selected := m.utilOpts[m.cursor]
	var c *exec.Cmd
	m.nextState = StateUtilsMenu

	switch selected.ActionID {
	case 0:
		c = exec.Command("bash", filepath.Join(m.repoDir, "cli", "configs", "cursor.sh"))
	case 1:
		c = exec.Command("bash", filepath.Join(m.repoDir, "cli", "configs", "gpu.sh"))
	case 2:
		c = exec.Command("bash", filepath.Join(m.repoDir, "cli", "mount_drive_manager.sh"))
	case 3:
		c = exec.Command("bash", filepath.Join(m.repoDir, "cli", "boot_to.sh"))
	case 4:
		c = exec.Command("bash", filepath.Join(m.repoDir, "cli", "utils", "cleanup.sh"))
	case 5:
		c = exec.Command("bash", filepath.Join(m.repoDir, "cli", "utils", "clear_trash.sh"))
	case 6:
		c = exec.Command("bash", filepath.Join(m.repoDir, "cli", "utils", "rank_mirrors.sh"))
	case 7:
		c = exec.Command("bash", filepath.Join(m.repoDir, "cli", "utils", "build_cursors.sh"))
	case 8:
		c = exec.Command("bash", filepath.Join(m.repoDir, "cli", "utils", "set_kitty_main_terminal.sh"))
	case 9:
		c = exec.Command("bash", filepath.Join(m.repoDir, "cli", "utils", "force_reload_quickshell.sh"))
	case 13:
		c = exec.Command("bash", filepath.Join(m.repoDir, "cli", "utils", "reset_quickshell.sh"))
	case 10:
		c = exec.Command("sudo", "bash", filepath.Join(m.repoDir, "cli", "configs", "auto_login.sh"))
	case 11:
		c = exec.Command("bash", filepath.Join(m.repoDir, "cli", "utils", "amogus.sh"))
	case 12:
		m.state = StateMainMenu
		m.cursor = 0
		return m, nil
	}

	if c != nil {
		return m, tea.ExecProcess(c, func(err error) tea.Msg {
			return processFinishedMsg{err}
		})
	}
	return m, nil
}

func (m MenuModel) View() string {
	if m.state == StateWaitingKey {
		return lipgloss.NewStyle().Foreground(lipgloss.Color("#98C379")).Bold(true).Render("\n" + m.waitingMsg + "\n")
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
	fmt.Println()

	m := NewMenuModel(repoDir)
	p := tea.NewProgram(m)
	_, err := p.Run()
	return err
}
