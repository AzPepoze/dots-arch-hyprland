package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type AppConfig struct {
	ReplaceColor  bool   `json:"replace_end4_color_to_catpuccin"`
	Model         string `json:"model"`
	RemoveBg      bool   `json:"remove_end4_background"`
	UseShutdown   bool   `json:"use_hyprshutdown"`
}

type ConfigModel struct {
	repoDir      string
	configPath   string
	config       AppConfig
	cursor       int
	models       []string
	modelIdx     int
	width        int
	height       int
	saved        bool
	quitted      bool
}

func NewConfigModel(repoDir string) ConfigModel {
	configPath := filepath.Join(repoDir, "config.json")
	cfg := AppConfig{
		ReplaceColor: false,
		Model:        "laptop",
		RemoveBg:     false,
		UseShutdown:  false,
	}

	if data, err := os.ReadFile(configPath); err == nil {
		_ = json.Unmarshal(data, &cfg)
	}

	modelOpts := []string{"laptop", "pc", "desktop"}
	if dotsDir, err := os.ReadDir(filepath.Join(repoDir, "dots")); err == nil {
		for _, f := range dotsDir {
			if f.IsDir() && f.Name() != "base" && f.Name() != "post-install" {
				found := false
				for _, m := range modelOpts {
					if m == f.Name() {
						found = true
						break
					}
				}
				if !found {
					modelOpts = append(modelOpts, f.Name())
				}
			}
		}
	}

	modelIdx := 0
	for i, m := range modelOpts {
		if m == cfg.Model {
			modelIdx = i
			break
		}
	}

	return ConfigModel{
		repoDir:    repoDir,
		configPath: configPath,
		config:     cfg,
		models:     modelOpts,
		modelIdx:   modelIdx,
		cursor:     0,
		width:      80,
	}
}

func (m ConfigModel) Init() tea.Cmd {
	return nil
}

func (m ConfigModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c", "esc":
			m.quitted = true
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < 5 {
				m.cursor++
			}
		case "left", "h":
			if m.cursor == 1 {
				if m.modelIdx > 0 {
					m.modelIdx--
					m.config.Model = m.models[m.modelIdx]
				}
			}
		case "right", "l":
			if m.cursor == 1 {
				if m.modelIdx < len(m.models)-1 {
					m.modelIdx++
					m.config.Model = m.models[m.modelIdx]
				}
			}
		case " ", "enter":
			switch m.cursor {
			case 0:
				m.config.ReplaceColor = !m.config.ReplaceColor
			case 1:
				m.modelIdx = (m.modelIdx + 1) % len(m.models)
				m.config.Model = m.models[m.modelIdx]
			case 2:
				m.config.RemoveBg = !m.config.RemoveBg
			case 3:
				m.config.UseShutdown = !m.config.UseShutdown
			case 4:
				m.saved = true
				return m, tea.Quit
			case 5:
				m.quitted = true
				return m, tea.Quit
			}
		}
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	}
	return m, nil
}

func (m ConfigModel) View() string {
	headerStyle := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#C678DD")).Padding(0, 1)
	title := headerStyle.Render("Az Arch Hyprland Configuration Editor")

	var lines []string

	boxWidth := 72
	if m.width > 0 {
		if m.width-8 < boxWidth {
			boxWidth = m.width - 8
		}
	}
	if boxWidth < 60 {
		boxWidth = 60
	}
	if m.width > 0 && boxWidth > m.width {
		boxWidth = m.width
	}

	renderRow := func(idx int, label string, val string) string {
		cursor := "  "
		if idx == m.cursor {
			cursor = "> "
		}

		innerWidth := boxWidth - 6
		labelWidth := lipgloss.Width(cursor) + lipgloss.Width(label)
		valWidth := lipgloss.Width(val)

		spacing := innerWidth - labelWidth - valWidth
		if spacing < 1 {
			spacing = 1
		}

		row := fmt.Sprintf("%s%s%s%s", cursor, label, strings.Repeat(" ", spacing), val)
		if idx == m.cursor {
			return lipgloss.NewStyle().Foreground(lipgloss.Color("#98C379")).Bold(true).Render(row)
		}
		return row
	}

	boolStr := func(b bool) string {
		if b {
			return lipgloss.NewStyle().Foreground(lipgloss.Color("#98C379")).Render("ENABLED (true)")
		}
		return lipgloss.NewStyle().Foreground(lipgloss.Color("#E06C75")).Render("DISABLED (false)")
	}

	lines = append(lines, renderRow(0, "Replace QuickShell Color to Catppuccin", boolStr(m.config.ReplaceColor)))
	lines = append(lines, renderRow(1, "Hardware Model Mode", lipgloss.NewStyle().Foreground(lipgloss.Color("#61AFEF")).Render("< "+m.config.Model+" >")))
	lines = append(lines, renderRow(2, "Remove QuickShell Background image", boolStr(m.config.RemoveBg)))
	lines = append(lines, renderRow(3, "Use hyprshutdown for Power management", boolStr(m.config.UseShutdown)))

	lines = append(lines, "")
	saveRow := "  [ Save Configuration & Reload ]"
	if m.cursor == 4 {
		saveRow = lipgloss.NewStyle().Foreground(lipgloss.Color("#98C379")).Bold(true).Render("> [ Save Configuration & Reload ]")
	}
	lines = append(lines, saveRow)

	cancelRow := "  [ Cancel & Exit ]"
	if m.cursor == 5 {
		cancelRow = lipgloss.NewStyle().Foreground(lipgloss.Color("#E06C75")).Bold(true).Render("> [ Cancel & Exit ]")
	}
	lines = append(lines, cancelRow)

	content := lipgloss.JoinVertical(lipgloss.Left, lines...)
	box := lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color("#61AFEF")).Padding(1, 2).Width(boxWidth).Render(content)

	footerStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("#5C6370")).Italic(true)
	footer := footerStyle.Render("space/enter: toggle or select | left/right: change model | up/down: navigate")

	return fmt.Sprintf("\n%s\n\n%s\n\n%s\n", title, box, footer)
}

func runConfigEditor(repoDir string) error {
	m := NewConfigModel(repoDir)
	p := tea.NewProgram(m)
	finalModel, err := p.Run()
	if err != nil {
		return err
	}

	model := finalModel.(ConfigModel)
	if model.saved {
		data, err := json.MarshalIndent(model.config, "", "    ")
		if err != nil {
			return err
		}

		if err := os.WriteFile(model.configPath, data, 0644); err != nil {
			return err
		}

		fmt.Println("Configuration saved successfully! Reloading dotfiles...")
		loadConfigsScript := filepath.Join(repoDir, "cli", "load_configs.sh")
		c := exec.Command("bash", loadConfigsScript, "--skip-gpu", "--skip-cursor")
		c.Stdout = os.Stdout
		c.Stderr = os.Stderr
		c.Stdin = os.Stdin
		return c.Run()
	}

	return nil
}
