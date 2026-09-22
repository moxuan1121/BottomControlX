"""Small host-side contract check for the side-handle build."""

from pathlib import Path
import re
import sqlite3


root = Path(__file__).resolve().parents[1]
data = (root / "PanelData.m").read_text(encoding="utf-8")
panel = (root / "PanelView.m").read_text(encoding="utf-8")
prefs = (root / "Prefs" / "Preference.m").read_text(encoding="utf-8")
panel_settings = (root / "Prefs" / "PanelSettings.m").read_text(encoding="utf-8")
slider_cell = (root / "Prefs" / "BCXSliderCell.m").read_text(encoding="utf-8")
tweak = (root / "Tweak.xm").read_text(encoding="utf-8")
header = (root / "Tweak.h").read_text(encoding="utf-8")
common = (root / "Common.h").read_text(encoding="utf-8")
control = (root / "control").read_text(encoding="utf-8")
makefile = (root / "Makefile").read_text(encoding="utf-8")

for zone in ("BCX_LEFT_ITEMS", "BCX_RIGHT_ITEMS"):
    assert zone in prefs and zone in panel
for removed in ("BCX_CENTER_ITEMS", "leftValue", "rightWidth", "edgeInsetValue", "showGestureAreas"):
    assert removed not in prefs and removed not in tweak

assert 'groupNamed:@"侧边手柄"' in prefs
assert '@"左侧手柄动作"' in prefs and '@"右侧手柄动作"' in prefs
assert "BCXConfigureSideHandles" in tweak and "BCXBeginSidePanel" in panel
assert "BCXHandleWindow" in panel and "hitTest:(CGPoint)point" in panel
assert "pill.layer.cornerRadius = 8" in panel and "BCXHandleHeight()" in panel
assert "BCXHandlePosition()" in panel and "pillHeight * 0.9" in panel
assert "BCX_HANDLE_HEIGHT" in prefs and "BCX_HANDLE_POSITION" in prefs
assert "pillHeight * 0.055" in panel and "BCXHandleShadowWidth()" in panel
assert "BCXHandleShadowPosition()" in panel and "BCXHandleIndicatorPosition()" in panel
for key in ("BCX_HANDLE_INDICATOR_POSITION", "BCX_HANDLE_SHADOW_WIDTH", "BCX_HANDLE_SHADOW_POSITION"):
    assert key in prefs and key in data
assert "BCX_PANEL_MIN_WIDTH" in prefs and "BCXPanelMinimumWidth()" in panel
assert "sizeWithAttributes" in panel and "MIN(280, ceil(titleWidth))" in panel
assert "distance >= 40 || velocity >= 600" in panel
assert "BCXUpdatePanel(MAX(0, distance))" in panel and "BCXFinishPanel(NO)" in panel
for removed in ("SBFluidSwitcherGestureManager", "SBFluidSwitcherGestureExclusionTrapezoid", "SBMainSwitcherViewController"):
    assert removed not in tweak and removed not in header

assert "WFSpringBoardWorkflowRunnerClient" in tweak
assert "initWithWorkflowIdentifier:" in tweak and "shortcuts://run-shortcut" not in tweak
assert 'BCXRebootUserspace()' in tweak and '@"userspace"' in tweak
assert '"/bin/launchctl"' in tweak and '(char *)"reboot", (char *)"userspace"' in tweak
assert 'jbdRebootUserspace' not in tweak
assert 'ShortcutPanelHelper' not in tweak and 'TOOL_NAME' not in makefile
assert not (root / "Helper.m").exists() and not (root / "HelperEntitlements.plist").exists()
assert 'exec_cmd_suspended' not in tweak and 'jbclient_root_set_mac_label' not in tweak
assert 'else if ([identifier isEqualToString:@"respring"]) kill(getpid(), SIGTERM);' in tweak
assert 'BCXCloseBackgroundApps();\n        kill(getpid(), SIGTERM);' in tweak
assert "BCXApplicationQuickActions" in data
assert "BCXAllQuickActions" in data and 'BCXRequestQuickActions(@"*")' in panel_settings
assert 'activateShortcut:withBundleIdentifier:forIconView:' in tweak
assert "UISearchResultsUpdating" in panel_settings and "localizedCaseInsensitiveContainsString" in panel_settings
assert '@"手柄外观"' in prefs and "BCXHandleAppearanceController" in prefs
assert "BCXPickerModeOpenApps" in panel_settings and 'BCXOpenApplication(identifier)' in tweak
assert '[@"kind"] isEqualToString:@"app"' in data
assert "com.mox1121.shortcutpanel" in common and "Package: com.mox1121.shortcutpanel" in control
assert "Name: ShortcutPanel" in control and "Version: 1.0.1+panel32" in control
assert 'BCXSliderCell.class' in prefs and 'cell:PSStaticTextCell' in prefs
assert 'performGetter' in slider_cell and 'performSetterWithValue:' in slider_cell
assert 'setProperty:@"BCXSliderCell"' not in prefs
assert 'UILongPressGestureRecognizer' in slider_cell and 'UIKeyboardTypeDecimalPad' in slider_cell
assert 'UITableViewCellSelectionStyleNone' in slider_cell and 'monospacedDigitSystemFontOfSize:14' in slider_cell
assert 'tableView:(UITableView *)tableView willDisplayCell:' not in prefs
assert "customSymbol" in data and "customImage" in data

db = sqlite3.connect(":memory:")
db.execute("CREATE TABLE ZSHORTCUT (ZWORKFLOWID TEXT, ZNAME TEXT)")
db.execute("INSERT INTO ZSHORTCUT VALUES (?, ?)", ("stable-id", "测试指令"))
query = re.search(r'"(SELECT ZWORKFLOWID, ZNAME FROM ZSHORTCUT[^\"]+)"', data).group(1)
assert db.execute(query).fetchall() == [("stable-id", "测试指令")]

for action in ("closeapps", "closeandrespring", "respring", "userspace", "reboot", "shutdown"):
    assert f'@"{action}"' in data and f'@"{action}"' in tweak

print("side handle contract OK")
