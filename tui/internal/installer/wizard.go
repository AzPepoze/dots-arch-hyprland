package installer

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"tui/internal/theme"
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

type wizardOption struct {
	label    string
	subtitle string
}

type wizardStepDef struct {
	title   string
	options []wizardOption
}

type useCaseProfile struct {
	label        string
	subtitle     string
	functions    map[string]bool
	previewItems []string
}

var hardwareOptions = []wizardOption{
	{label: "PC / Desktop", subtitle: "Optimized for stationary performance"},
	{label: "Laptop", subtitle: "Enables laptop-specific configurations"},
	{label: "Skip Wizard", subtitle: "Go directly to the package selection page"},
}

var gpuOptions = []wizardOption{
	{label: "Auto-detect", subtitle: "Installs maintained userspace packages for every detected GPU"},
	{label: "Skip", subtitle: "Leaves the current graphics packages unchanged"},
}

var useCaseProfiles = []useCaseProfile{
	{
		label:    "🎮  Gaming",
		subtitle: "Adds Steam, Discord, Vencord, Wallpaper Engine",
		functions: map[string]bool{
			"install_steam":                true,
			"install_discord":              true,
			"install_vencord":              true,
			"install_wallpaper_engine":     true,
			"install_wallpaper_engine_gui": true,
		},
		previewItems: []string{
			"  • Install Steam",
			"  • Install Discord + Vencord",
			"  • Install Linux Wallpaper Engine",
		},
	},
	{
		label:    "💻  Development",
		subtitle: "Adds npm, pnpm, bun, VS Code, Git Credential Manager",
		functions: map[string]bool{
			"install_npm":                     true,
			"install_pnpm":                    true,
			"install_bun":                     true,
			"install_vscode":                  true,
			"setup_git_credential_management": true,
		},
		previewItems: []string{
			"  • Install VS Code",
			"  • Install npm, pnpm, bun",
			"  • Setup Git Credential Management",
		},
	},
	{
		label:    "🌐  General / Daily",
		subtitle: "Essentials + common apps, nothing extra",
	},
	{
		label:    "⚡  Minimal",
		subtitle: "Essential packages only, nothing optional",
	},
}

var useCaseOptions = buildUseCaseOptions()

var (
	hardwareLabels = optionLabels(hardwareOptions)
	gpuLabels      = optionLabels(gpuOptions)
	useCaseLabels  = optionLabels(useCaseOptions)
	wizardSteps    = []wizardStepDef{
		{title: "What type of system is this?", options: hardwareOptions},
		{title: "Install a detected GPU userspace stack?", options: gpuOptions},
		{title: "What is the primary use case?", options: useCaseOptions},
	}
	wizardOptionCounts = [3]int{len(hardwareOptions), len(gpuOptions), len(useCaseProfiles)}
	wizardStepNames    = []string{"Hardware", "GPU", "Use Case", "Summary"}
)

func buildUseCaseOptions() []wizardOption {
	options := make([]wizardOption, len(useCaseProfiles))
	for i, profile := range useCaseProfiles {
		options[i] = wizardOption{label: profile.label, subtitle: profile.subtitle}
	}
	return options
}

func optionLabels(options []wizardOption) []string {
	labels := make([]string, len(options))
	for i, option := range options {
		labels[i] = option.label
	}
	return labels
}

func (m *InstallerModel) applyPreset() {
	m.forEachItem(func(item *InstallItem) {
		if item.Type == ItemTypeEssential {
			item.IsSelected = true
			return
		}

		if m.useCaseIdx == 3 {
			item.IsSelected = false
			return
		}

		if item.Func == "install_detected_graphics_stack" {
			item.IsSelected = (m.graphicsIdx == 0)
			return
		}

		if item.Func == "install_laptop_power_diagnostics" {
			item.IsSelected = false
			return
		}

		if m.useCaseIdx < len(useCaseProfiles) {
			item.IsSelected = useCaseProfiles[m.useCaseIdx].functions[item.Func]
		} else {
			item.IsSelected = false
		}
	})
}

func (m InstallerModel) updateWizard(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "q", "ctrl+c", "esc":
		return m, tea.Quit

	case "up", "k":
		if m.wizardCursor > 0 {
			m.wizardCursor--
		}

	case "down", "j":
		step := int(m.wizardStep)
		if step < len(wizardOptionCounts) && m.wizardCursor < wizardOptionCounts[step]-1 {
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
				m.setSelected(func(InstallItem) bool { return false })
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
		Foreground(theme.Purple).
		Border(lipgloss.RoundedBorder()).
		BorderForeground(theme.Purple).
		Padding(0, 2).
		Width(54)

	header := headerStyle.Render("✦  Az Arch Hyprland Setup Wizard")

	var dotParts []string
	for i, name := range wizardStepNames {
		var dot string
		if i < int(m.wizardStep) {
			dot = lipgloss.NewStyle().Foreground(theme.Green).Bold(true).Render("●")
		} else if i == int(m.wizardStep) {
			dot = lipgloss.NewStyle().Foreground(lipgloss.Color("#E5C07B")).Bold(true).Render("▶")
		} else {
			dot = lipgloss.NewStyle().Foreground(theme.Grey).Render("○")
		}
		label := lipgloss.NewStyle().Foreground(theme.Grey).Render(name)
		dotParts = append(dotParts, dot+" "+label)
	}
	progress := strings.Join(dotParts, "  ──  ")

	if m.wizardStep == WizardSummary {
		return m.renderSummary(header, progress)
	}
	return m.renderStep(header, progress)
}

func (m InstallerModel) renderSummary(header, progress string) string {
	dimStyle := lipgloss.NewStyle().Foreground(theme.Grey)
	activeStyle := lipgloss.NewStyle().Foreground(theme.Green).Bold(true)

	summaryLines := []string{
		activeStyle.Render("  ✔  Hardware :  ") + hardwareLabels[m.hardwareIdx],
		activeStyle.Render("  ✔  GPU      :  ") + gpuLabels[m.graphicsIdx],
		activeStyle.Render("  ✔  Use Case :  ") + useCaseLabels[m.useCaseIdx],
	}

	previewItems := []string{"  • Install Session & Power Profile"}
	if m.graphicsIdx == 0 {
		previewItems = append(previewItems, "  • Install detected GPU userspace packages")
	}
	if m.useCaseIdx < len(useCaseProfiles) {
		previewItems = append(previewItems, useCaseProfiles[m.useCaseIdx].previewItems...)
	}
	previewSection := "\n\n" + dimStyle.Render("  Optional packages included:") + "\n" + strings.Join(previewItems, "\n")

	bodyStr := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#E5C07B")).Render("  Profile Summary") + "\n" +
		dimStyle.Render("  "+strings.Repeat("─", 46)) + "\n" +
		strings.Join(summaryLines, "\n") +
		previewSection + "\n" +
		dimStyle.Render("\n  + all essential packages always included")

	content := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(theme.Blue).
		Padding(1, 2).
		Width(56).
		Render(bodyStr)

	footer := dimStyle.Render("  Enter: open installer   b: go back   q: quit")
	return fmt.Sprintf("\n%s\n\n  %s\n\n%s\n\n%s\n", header, progress, content, footer)
}

func (m InstallerModel) renderStep(header, progress string) string {
	dimStyle := lipgloss.NewStyle().Foreground(theme.Grey)
	activeStyle := lipgloss.NewStyle().Foreground(theme.Green).Bold(true)
	subtitleStyle := lipgloss.NewStyle().Foreground(theme.Grey).Italic(true)

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
		BorderForeground(theme.Purple).
		Padding(1, 2).
		Width(56).
		Render(bodyStr)

	footer := dimStyle.Render("  ↑↓ / jk: navigate   Enter: confirm   b: back   q: quit")
	return fmt.Sprintf("\n%s\n\n  %s\n\n%s\n\n%s\n", header, progress, content, footer)
}
