package installer

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type InstallerStage int

const (
	StageSetupWizard InstallerStage = iota
	StageMainGrid
)

type WizardStep int

const (
	WizardHardware WizardStep = iota
	WizardGPU
	WizardUseCase
	WizardSummary
)

func (m *InstallerModel) applyPreset() {
	gamingFuncs := map[string]bool{
		"install_steam":                true,
		"install_discord":              true,
		"install_vencord":              true,
		"install_wallpaper_engine":     true,
		"install_wallpaper_engine_gui": true,
	}
	devFuncs := map[string]bool{
		"install_npm":                     true,
		"install_pnpm":                    true,
		"install_bun":                     true,
		"fix_vscode_permissions":          true,
		"setup_git_credential_management": true,
	}

	for bIdx := range m.boxes {
		for iIdx := range m.boxes[bIdx].Items {
			item := &m.boxes[bIdx].Items[iIdx]

			if item.Type == "essential" {
				item.IsSelected = true
				continue
			}

			if m.useCaseIdx == 3 {
				item.IsSelected = false
				continue
			}

			if item.Func == "install_detected_graphics_stack" {
				item.IsSelected = (m.graphicsIdx == 0)
				continue
			}

			if item.Func == "install_laptop_power_diagnostics" {
				item.IsSelected = false
				continue
			}

			switch m.useCaseIdx {
			case 0:
				item.IsSelected = gamingFuncs[item.Func]
			case 1:
				item.IsSelected = devFuncs[item.Func]
			default:
				item.IsSelected = false
			}
		}
	}
}

func (m InstallerModel) updateWizard(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	optionCounts := [3]int{3, 2, 4}

	switch msg.String() {
	case "q", "ctrl+c", "esc":
		return m, tea.Quit

	case "up", "k":
		if m.wizardCursor > 0 {
			m.wizardCursor--
		}

	case "down", "j":
		step := int(m.wizardStep)
		if step < 3 && m.wizardCursor < optionCounts[step]-1 {
			m.wizardCursor++
		}

	case "b":
		if m.wizardStep > WizardHardware {
			m.wizardStep--
			m.wizardCursor = 0
		}

	case "enter", " ":
		switch m.wizardStep {
		case WizardHardware:
			if m.wizardCursor == 2 {
				for bIdx := range m.boxes {
					for iIdx := range m.boxes[bIdx].Items {
						m.boxes[bIdx].Items[iIdx].IsSelected = false
					}
				}
				m.stage = StageMainGrid
			} else {
				m.hardwareIdx = m.wizardCursor
				m.wizardStep = WizardGPU
				m.wizardCursor = 0
			}
		case WizardGPU:
			m.graphicsIdx = m.wizardCursor
			m.wizardStep = WizardUseCase
			m.wizardCursor = 0
		case WizardUseCase:
			m.useCaseIdx = m.wizardCursor
			m.wizardStep = WizardSummary
			m.wizardCursor = 0
		case WizardSummary:
			m.applyPreset()
			m.stage = StageMainGrid
		}
	}

	return m, nil
}

func (m InstallerModel) renderWizard() string {
	headerStyle := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("#C678DD")).
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("#C678DD")).
		Padding(0, 2).
		Width(54)

	header := headerStyle.Render("✦  Az Arch Hyprland Setup Wizard")

	stepNames := []string{"Hardware", "GPU", "Use Case", "Summary"}
	var dotParts []string
	for i, name := range stepNames {
		var dot string
		if i < int(m.wizardStep) {
			dot = lipgloss.NewStyle().Foreground(lipgloss.Color("#98C379")).Bold(true).Render("●")
		} else if i == int(m.wizardStep) {
			dot = lipgloss.NewStyle().Foreground(lipgloss.Color("#E5C07B")).Bold(true).Render("▶")
		} else {
			dot = lipgloss.NewStyle().Foreground(lipgloss.Color("#5C6370")).Render("○")
		}
		label := lipgloss.NewStyle().Foreground(lipgloss.Color("#5C6370")).Render(name)
		dotParts = append(dotParts, dot+" "+label)
	}
	progress := strings.Join(dotParts, "  ──  ")

	type wizardOption struct {
		label    string
		subtitle string
	}
	type wizardStepDef struct {
		title   string
		options []wizardOption
	}

	wizardSteps := []wizardStepDef{
		{
			title: "What type of system is this?",
			options: []wizardOption{
				{"PC / Desktop", "Optimized for stationary performance"},
				{"Laptop", "Enables laptop-specific configurations"},
				{"Skip Wizard", "Go directly to the package selection page"},
			},
		},
		{
			title: "Install a detected GPU userspace stack?",
			options: []wizardOption{
				{"Auto-detect", "Installs maintained userspace packages for every detected GPU"},
				{"Skip", "Leaves the current graphics packages unchanged"},
			},
		},
		{
			title: "What is the primary use case?",
			options: []wizardOption{
				{"🎮  Gaming", "Adds Steam, Discord, Vencord, Wallpaper Engine"},
				{"💻  Development", "Adds npm, pnpm, bun, VS Code, Git Credential Manager"},
				{"🌐  General / Daily", "Essentials + common apps, nothing extra"},
				{"⚡  Minimal", "Essential packages only, nothing optional"},
			},
		},
	}

	dimStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("#5C6370"))
	activeStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("#98C379")).Bold(true)
	subtitleStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("#5C6370")).Italic(true)

	if m.wizardStep == WizardSummary {
		hardwareLabels := []string{"PC / Desktop", "Laptop", "Skip Wizard"}
		gpuLabels := []string{"Auto-detect", "Skip"}
		useCaseLabels := []string{"🎮  Gaming", "💻  Development", "🌐  General / Daily", "⚡  Minimal"}

		summaryLines := []string{
			activeStyle.Render("  ✔  Hardware :  ") + hardwareLabels[m.hardwareIdx],
			activeStyle.Render("  ✔  GPU      :  ") + gpuLabels[m.graphicsIdx],
			activeStyle.Render("  ✔  Use Case :  ") + useCaseLabels[m.useCaseIdx],
		}

		var previewItems []string
		previewItems = append(previewItems, "  • Install Session & Power Profile")
		if m.graphicsIdx == 0 {
			previewItems = append(previewItems, "  • Install detected GPU userspace packages")
		}
		switch m.useCaseIdx {
		case 0:
			previewItems = append(previewItems,
				"  • Install Steam",
				"  • Install Discord + Vencord",
				"  • Install Linux Wallpaper Engine",
			)
		case 1:
			previewItems = append(previewItems,
				"  • Install npm, pnpm, bun",
				"  • Fix VSCode Insiders permissions",
				"  • Setup Git Credential Management",
			)
		}

		var previewSection string
		if len(previewItems) > 0 {
			previewSection = "\n\n" + dimStyle.Render("  Optional packages included:") + "\n" + strings.Join(previewItems, "\n")
		}

		bodyStr := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#E5C07B")).Render("  Profile Summary") + "\n" +
			dimStyle.Render("  "+strings.Repeat("─", 46)) + "\n" +
			strings.Join(summaryLines, "\n") +
			previewSection + "\n" +
			dimStyle.Render("\n  + all essential packages always included")

		content := lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("#61AFEF")).
			Padding(1, 2).
			Width(56).
			Render(bodyStr)

		footer := dimStyle.Render("  Enter: open installer   b: go back   q: quit")
		return fmt.Sprintf("\n%s\n\n  %s\n\n%s\n\n%s\n", header, progress, content, footer)
	}

	step := wizardSteps[int(m.wizardStep)]
	stepLabel := fmt.Sprintf("Step %d of 3", int(m.wizardStep)+1)

	var optionLines []string
	for i, opt := range step.options {
		if i == m.wizardCursor {
			optionLines = append(optionLines,
				activeStyle.Render("  ▶  "+opt.label),
				subtitleStyle.Render("       "+opt.subtitle),
			)
		} else {
			optionLines = append(optionLines,
				dimStyle.Render("     "+opt.label),
				subtitleStyle.Render("       "+opt.subtitle),
			)
		}
		optionLines = append(optionLines, "")
	}

	bodyStr := dimStyle.Render("  "+stepLabel) + "\n" +
		lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#ABB2BF")).Render("  "+step.title) + "\n\n" +
		strings.Join(optionLines, "\n")

	content := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(lipgloss.Color("#C678DD")).
		Padding(1, 2).
		Width(56).
		Render(bodyStr)

	footer := dimStyle.Render("  ↑↓ / jk: navigate   Enter: confirm   b: back   q: quit")
	return fmt.Sprintf("\n%s\n\n  %s\n\n%s\n\n%s\n", header, progress, content, footer)
}
