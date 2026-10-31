package installer

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"tui/internal/runner"
	"tui/internal/theme"
)

type GridBox struct {
	Title string
	Items []InstallItem
}

type InstallerModel struct {
	repoDir      string
	boxes        []GridBox
	activeBox    int
	cursors      []int
	width        int
	finished     bool
	selectedCmd  []string
	stage        InstallerStage
	wizardStep   WizardStep
	wizardCursor int
	hardwareIdx  int
	graphicsIdx  int
	useCaseIdx   int
}

func NewInstallerModel(repoDir string) InstallerModel {
	raw := getInstallItems(repoDir)
	var boxes []GridBox
	var currentBox *GridBox

	for _, item := range raw {
		if item.IsHeader {
			title := strings.Trim(item.Text, "- ")
			boxes = append(boxes, GridBox{Title: title, Items: []InstallItem{}})
			currentBox = &boxes[len(boxes)-1]
		} else {
			if currentBox != nil {
				currentBox.Items = append(currentBox.Items, item)
			}
		}
	}

	cursors := make([]int, len(boxes))

	return InstallerModel{
		repoDir: repoDir,
		boxes:   boxes,
		cursors: cursors,
		width:   90,
		stage:   StageSetupWizard,
	}
}

func (m InstallerModel) Init() tea.Cmd {
	return nil
}

func (m InstallerModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		if m.stage == StageSetupWizard {
			return m.updateWizard(msg)
		}
		return m.updateGrid(msg)
	case tea.WindowSizeMsg:
		m.width = msg.Width
	}
	return m, nil
}

func (m InstallerModel) updateGrid(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "q", "ctrl+c", "esc":
		return m, tea.Quit
	case "left", "h", "right", "l", "up", "k", "down", "j":
		m.navigate(msg.String())
	case " ":
		m.toggleCurrent()
	case "a", "n", "e", "o":
		m.bulkSelect(msg.String())
	case "enter":
		commands := m.collectCommands()
		if len(commands) > 0 {
			m.selectedCmd = commands
			m.finished = true
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m *InstallerModel) navigate(key string) {
	switch key {
	case "left", "h":
		m.activeBox = (m.activeBox - 1 + len(m.boxes)) % len(m.boxes)
	case "right", "l":
		m.activeBox = (m.activeBox + 1) % len(m.boxes)
	case "up", "k":
		if m.cursors[m.activeBox] > 0 {
			m.cursors[m.activeBox]--
			return
		}
		switch m.activeBox {
		case 1:
			m.activeBox = 0
			if len(m.boxes[0].Items) > 0 {
				m.cursors[0] = len(m.boxes[0].Items) - 1
			}
		case 3:
			m.activeBox = 2
			if len(m.boxes[2].Items) > 0 {
				m.cursors[2] = len(m.boxes[2].Items) - 1
			}
		}
	case "down", "j":
		itemsLen := len(m.boxes[m.activeBox].Items)
		if m.cursors[m.activeBox] < itemsLen-1 {
			m.cursors[m.activeBox]++
			return
		}
		switch m.activeBox {
		case 0:
			m.activeBox = 1
			m.cursors[1] = 0
		case 2:
			m.activeBox = 3
			m.cursors[3] = 0
		}
	}
}

func (m *InstallerModel) toggleCurrent() {
	idx := m.cursors[m.activeBox]
	if len(m.boxes[m.activeBox].Items) > 0 {
		m.boxes[m.activeBox].Items[idx].IsSelected = !m.boxes[m.activeBox].Items[idx].IsSelected
	}
}

func (m *InstallerModel) bulkSelect(key string) {
	switch key {
	case "a":
		m.setSelected(func(InstallItem) bool { return true })
	case "n":
		m.setSelected(func(InstallItem) bool { return false })
	case "e":
		m.setSelected(func(item InstallItem) bool { return item.Type == "essential" })
	case "o":
		m.setSelected(func(item InstallItem) bool {
			return item.Type == "essential" || item.Type == "essential_laptop"
		})
	}
}

func (m *InstallerModel) setSelected(pred func(InstallItem) bool) {
	m.forEachItem(func(item *InstallItem) {
		item.IsSelected = pred(*item)
	})
}

func (m *InstallerModel) forEachItem(fn func(*InstallItem)) {
	for bIdx := range m.boxes {
		for iIdx := range m.boxes[bIdx].Items {
			fn(&m.boxes[bIdx].Items[iIdx])
		}
	}
}

func (m InstallerModel) collectCommands() []string {
	var commands []string
	m.forEachItem(func(item *InstallItem) {
		if item.IsSelected && item.Func != "" {
			commands = append(commands, item.Func)
		}
	})
	return commands
}

func (m InstallerModel) View() string {
	if m.finished {
		return "Starting installation process...\n"
	}
	if m.stage == StageSetupWizard {
		return m.renderWizard()
	}

	headerStyle := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#13BCFF")).Padding(0, 1)
	title := headerStyle.Render("Az Arch Hyprland Package Installer")

	usableWidth := m.width - 8
	if usableWidth < 70 {
		usableWidth = 70
	}

	var colsCount int
	if m.width >= 110 {
		colsCount = 3
	} else if m.width >= 75 {
		colsCount = 2
	} else {
		colsCount = 1
	}

	var colWidth int
	if colsCount == 3 {
		colWidth = usableWidth / 3
	} else if colsCount == 2 {
		colWidth = usableWidth / 2
	} else {
		colWidth = usableWidth
	}

	renderedBoxes := make([]string, 0, len(m.boxes))
	for bIdx := range m.boxes {
		renderedBoxes = append(renderedBoxes, m.renderBox(bIdx, colsCount, colWidth))
	}

	finalLayout := layoutColumns(renderedBoxes, colsCount)
	descriptionBox := m.renderDescription(usableWidth)

	footerStyle := lipgloss.NewStyle().Foreground(theme.Grey).Italic(true)
	footer := footerStyle.Render("arrows or hjkl: navigate grid/items | space: toggle | a: all | n: none | e: essential | o: laptop | enter: install | q: quit")

	return fmt.Sprintf("\n%s\n\n%s\n\n%s\n\n%s\n", title, finalLayout, descriptionBox, footer)
}

func (m InstallerModel) renderBox(bIdx, colsCount, colWidth int) string {
	box := m.boxes[bIdx]
	isFocused := bIdx == m.activeBox
	activeCursor := m.cursors[bIdx]

	boxHeight := 6
	if bIdx == 4 && colsCount == 3 {
		boxHeight = 15
	}

	visibleCount := boxHeight
	start, end := 0, len(box.Items)
	if len(box.Items) > visibleCount {
		start = activeCursor - visibleCount/2
		if start < 0 {
			start = 0
		}
		end = start + visibleCount
		if end > len(box.Items) {
			end = len(box.Items)
			start = end - visibleCount
		}
	}

	var listStrings []string
	for i := start; i < end; i++ {
		item := box.Items[i]
		cursorStr := "  "
		if i == activeCursor && isFocused {
			cursorStr = "> "
		}

		checkStr := "[ ]"
		if item.IsSelected {
			checkStr = "[x]"
		}

		line := fmt.Sprintf("%s%s %s", cursorStr, checkStr, item.Text)

		maxTextWidth := colWidth - 8
		if len(line) > maxTextWidth && maxTextWidth > 10 {
			line = line[:maxTextWidth] + "..."
		}

		if i == activeCursor && isFocused {
			line = lipgloss.NewStyle().Foreground(theme.Green).Bold(true).Render(line)
		}
		listStrings = append(listStrings, line)
	}

	for len(listStrings) < boxHeight {
		listStrings = append(listStrings, "")
	}

	content := lipgloss.JoinVertical(lipgloss.Left, listStrings...)

	borderColor := lipgloss.Color("#2C323C")
	if isFocused {
		borderColor = theme.Green
	}

	return lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(borderColor).
		Padding(0, 1).
		Width(colWidth - 2).
		Render(fmt.Sprintf("%s\n%s", lipgloss.NewStyle().Bold(true).Foreground(theme.Blue).Render(box.Title), content))
}

func layoutColumns(renderedBoxes []string, colsCount int) string {
	switch colsCount {
	case 3:
		col1 := lipgloss.JoinVertical(lipgloss.Left, renderedBoxes[0], renderedBoxes[1])
		col2 := lipgloss.JoinVertical(lipgloss.Left, renderedBoxes[2], renderedBoxes[3])
		col3 := renderedBoxes[4]
		return lipgloss.JoinHorizontal(lipgloss.Top, col1, col2, col3)
	case 2:
		col1 := lipgloss.JoinVertical(lipgloss.Left, renderedBoxes[0], renderedBoxes[1], renderedBoxes[2])
		col2 := lipgloss.JoinVertical(lipgloss.Left, renderedBoxes[3], renderedBoxes[4])
		return lipgloss.JoinHorizontal(lipgloss.Top, col1, col2)
	default:
		return lipgloss.JoinVertical(lipgloss.Left, renderedBoxes[0], renderedBoxes[1], renderedBoxes[2], renderedBoxes[3], renderedBoxes[4])
	}
}

func (m InstallerModel) renderDescription(usableWidth int) string {
	activeBox := m.activeBox
	activeCursor := m.cursors[activeBox]
	var descText string
	if len(m.boxes[activeBox].Items) > 0 && activeCursor < len(m.boxes[activeBox].Items) {
		item := m.boxes[activeBox].Items[activeCursor]
		descText = fmt.Sprintf(
			"%s: %s",
			lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#E5C07B")).Render(item.Text),
			item.Description,
		)
	}

	return lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(theme.Purple).
		Padding(0, 1).
		Width(usableWidth).
		Render(descText)
}

func Run(repoDir string) error {
	m := NewInstallerModel(repoDir)
	p := tea.NewProgram(m)
	finalModel, err := p.Run()
	if err != nil {
		return err
	}

	model := finalModel.(InstallerModel)
	if len(model.selectedCmd) > 0 {
		scriptContent := generateInstallScript(repoDir, model.selectedCmd)
		tmpFile, err := os.CreateTemp("", "az-install-*.sh")
		if err != nil {
			return err
		}
		defer os.Remove(tmpFile.Name())

		if _, err := tmpFile.WriteString(scriptContent); err != nil {
			return err
		}
		tmpFile.Close()

		if err := os.Chmod(tmpFile.Name(), 0755); err != nil {
			return err
		}

		c := runner.Bash(tmpFile.Name())
		return c.Run()
	}

	return nil
}

func generateInstallScript(repoDir string, commands []string) string {
	modulesDir := filepath.Join(repoDir, "scripts", "install_modules")
	var lines []string
	lines = append(lines, "#!/bin/bash")
	lines = append(lines, fmt.Sprintf("export repo_dir=%q", repoDir))
	lines = append(lines, "trap 'echo; read -p \"--- Script finished. Press Enter to close. ---\"' EXIT")

	lines = append(lines, `
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
            read -p "      [R]retry, [I]gnore, or [A]bort? " choice
            case "$choice" in
                [rR]) echo -e "\n\e[1;33m--- Retrying... ---\e[0m"; continue ;; 
                [iI]) echo -e "\n\e[1;33m--- Ignoring... ---\e[0m"; return 0 ;; 
                [aA]) echo -e "\n\e[1;31m--- Aborting. ---\e[0m"; exit 1 ;; 
                *) echo -e "\n\e[1;33m--- Retrying... ---\e[0m"; continue ;; 
            esac
        fi
    done
}
`)

	helpersPath := filepath.Join(modulesDir, "helpers.sh")
	if _, err := os.Stat(helpersPath); err == nil {
		lines = append(lines, fmt.Sprintf("source %s", helpersPath))
	}

	files, _ := os.ReadDir(modulesDir)
	var shellFiles []string
	for _, f := range files {
		if !f.IsDir() && strings.HasSuffix(f.Name(), ".sh") && f.Name() != "helpers.sh" {
			shellFiles = append(shellFiles, f.Name())
		}
	}
	sort.Strings(shellFiles)

	for _, fName := range shellFiles {
		lines = append(lines, fmt.Sprintf("source %s", filepath.Join(modulesDir, fName)))
	}

	for _, cmd := range commands {
		lines = append(lines, fmt.Sprintf("run_command %q", cmd))
	}

	return strings.Join(lines, "\n")
}
