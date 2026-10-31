package installer

import "testing"

func presetTestItems() []InstallItem {
	return []InstallItem{
		{Type: ItemTypeEssential, Func: "install_essential"},
		{Type: ItemTypeOptional, Func: "install_steam"},
		{Type: ItemTypeOptional, Func: "install_discord"},
		{Type: ItemTypeOptional, Func: "install_vscode"},
		{Type: ItemTypeOptional, Func: "install_detected_graphics_stack"},
		{Type: ItemTypeOptional, Func: "install_laptop_power_diagnostics"},
		{Type: ItemTypeOptional, Func: "install_other"},
	}
}

func TestApplyPreset(t *testing.T) {
	tests := []struct {
		name      string
		useCase   int
		graphics  int
		selection map[string]bool
	}{
		{
			name:     "gaming",
			useCase:  0,
			graphics: 0,
			selection: map[string]bool{
				"install_essential":                true,
				"install_steam":                    true,
				"install_discord":                  true,
				"install_vscode":                   false,
				"install_detected_graphics_stack":  true,
				"install_laptop_power_diagnostics": false,
				"install_other":                    false,
			},
		},
		{
			name:     "development",
			useCase:  1,
			graphics: 1,
			selection: map[string]bool{
				"install_essential":                true,
				"install_steam":                    false,
				"install_discord":                  false,
				"install_vscode":                   true,
				"install_detected_graphics_stack":  false,
				"install_laptop_power_diagnostics": false,
				"install_other":                    false,
			},
		},
		{
			name:     "general",
			useCase:  2,
			graphics: 0,
			selection: map[string]bool{
				"install_essential":                true,
				"install_steam":                    false,
				"install_discord":                  false,
				"install_vscode":                   false,
				"install_detected_graphics_stack":  true,
				"install_laptop_power_diagnostics": false,
				"install_other":                    false,
			},
		},
		{
			name:     "minimal",
			useCase:  3,
			graphics: 0,
			selection: map[string]bool{
				"install_essential":                true,
				"install_steam":                    false,
				"install_discord":                  false,
				"install_vscode":                   false,
				"install_detected_graphics_stack":  false,
				"install_laptop_power_diagnostics": false,
				"install_other":                    false,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			m := InstallerModel{
				boxes:       []GridBox{{Items: presetTestItems()}},
				useCaseIdx:  tt.useCase,
				graphicsIdx: tt.graphics,
			}
			m.applyPreset()

			for _, item := range m.boxes[0].Items {
				want := tt.selection[item.Func]
				if item.IsSelected != want {
					t.Errorf("%s: selected = %v, want %v", item.Func, item.IsSelected, want)
				}
			}
		})
	}
}
