"""Small host-side contract check for the side-handle build."""

from pathlib import Path
import re
import sqlite3


root = Path(__file__).resolve().parents[1]
data = (root / "PanelData.m").read_text(encoding="utf-8")
panel = (root / "PanelView.m").read_text(encoding="utf-8")
prefs = (root / "Prefs" / "Preference.m").read_text(encoding="utf-8")
panel_settings = (root / "Prefs" / "PanelSettings.m").read_text(encoding="utf-8")
tweak = (root / "Tweak.xm").read_text(encoding="utf-8")
header = (root / "Tweak.h").read_text(encoding="utf-8")
common = (root / "Common.h").read_text(encoding="utf-8")
control = (root / "control").read_text(encoding="utf-8")

for zone in ("BCX_LEFT_ITEMS", "BCX_RIGHT_ITEMS"):
    assert zone in prefs and zone in panel
for removed in ("BCX_CENTER_ITEMS", "leftValue", "rightWidth", "edgeInsetValue", "showGestureAreas"):
    assert removed not in prefs and removed not in tweak

assert 'groupNamed:@"侧边手柄"' in prefs
assert '@"左侧手柄动作"' in prefs and '@"右侧手柄动作"' in prefs
assert "BCXConfigureSideHandles" in tweak and "BCXBeginSidePanel" in panel
assert "BCXHandleWindow" in panel and "hitTest:(CGPoint)point" in panel
assert "pill.layer.cornerRadius = 8" in panel and "CGRectMake(0, y, 28, 104)" in panel
assert "distance >= 40 || velocity >= 600" in panel
assert "BCXUpdatePanel(MAX(0, distance))" in panel and "BCXFinishPanel(NO)" in panel
for removed in ("SBFluidSwitcherGestureManager", "SBFluidSwitcherGestureExclusionTrapezoid", "SBMainSwitcherViewController"):
    assert removed not in tweak and removed not in header

assert "WFSpringBoardWorkflowRunnerClient" in tweak
assert "initWithWorkflowIdentifier:" in tweak and "shortcuts://run-shortcut" not in tweak
assert 'BCXRebootUserspace()' in tweak and '"reboot_userspace"' in tweak
assert 'else if ([identifier isEqualToString:@"respring"]) kill(getpid(), SIGTERM);' in tweak
assert 'BCXCloseBackgroundApps();\n        kill(getpid(), SIGTERM);' in tweak
assert "BCXApplicationQuickActions" in data
assert "BCXAllQuickActions" in data and 'BCXRequestQuickActions(@"*")' in panel_settings
assert 'activateShortcut:withBundleIdentifier:forIconView:' in tweak
assert "UISearchResultsUpdating" in panel_settings and "localizedCaseInsensitiveContainsString" in panel_settings
assert "com.mox1121.shortcutpanel" in common and "Package: com.mox1121.shortcutpanel" in control
assert "Name: ShortcutPanel" in control and "Version: 1.0.1+panel22" in control
assert "customSymbol" in data and "customImage" in data

db = sqlite3.connect(":memory:")
db.execute("CREATE TABLE ZSHORTCUT (ZWORKFLOWID TEXT, ZNAME TEXT)")
db.execute("INSERT INTO ZSHORTCUT VALUES (?, ?)", ("stable-id", "测试指令"))
query = re.search(r'"(SELECT ZWORKFLOWID, ZNAME FROM ZSHORTCUT[^\"]+)"', data).group(1)
assert db.execute(query).fetchall() == [("stable-id", "测试指令")]

for action in ("closeapps", "closeandrespring", "respring", "userspace", "reboot", "shutdown"):
    assert f'@"{action}"' in data and f'@"{action}"' in tweak

print("side handle contract OK")
