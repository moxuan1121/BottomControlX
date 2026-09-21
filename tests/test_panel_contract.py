"""Host-side check for the panel's saved IDs and Shortcuts query."""

from pathlib import Path
import re
import sqlite3


root = Path(__file__).resolve().parents[1]
data = (root / "PanelData.m").read_text(encoding="utf-8")
prefs = (root / "Prefs" / "Preference.m").read_text(encoding="utf-8")
panel_settings = (root / "Prefs" / "PanelSettings.m").read_text(encoding="utf-8")
tweak = (root / "Tweak.xm").read_text(encoding="utf-8")
common = (root / "Common.h").read_text(encoding="utf-8")
control = (root / "control").read_text(encoding="utf-8")

assert 'key:@"BottomLeftGesture"' not in prefs
assert 'key:@"BottomCenterGesture"' not in prefs
assert 'key:@"BottomRightGesture"' not in prefs
for zone in ("BCX_LEFT_ITEMS", "BCX_RIGHT_ITEMS"):
    assert zone in prefs and zone in tweak
assert "BCX_CENTER_ITEMS" not in prefs and "BCX_CENTER_ITEMS" not in tweak
assert 'key:@"leftValue"' in prefs and 'key:@"rightWidth"' in prefs
assert 'key:@"edgeInsetValue"' in prefs
assert 'activeItems.count > 1' in tweak
assert 'activeItems.count == 1' in tweak
assert 'BCXFinishPanel(commit)' in tweak
assert 'WFSpringBoardWorkflowRunnerClient' in tweak
assert 'initWithWorkflowIdentifier:' in tweak and '@selector(start)' in tweak
assert 'shortcuts://run-shortcut' not in tweak
assert 'BCXRebootUserspace()' in tweak and '"reboot_userspace"' in tweak
assert 'jbclient_root_set_mac_label' in tweak
assert 'exec_cmd_suspended' in tweak
assert 'else if ([identifier isEqualToString:@"respring"]) kill(getpid(), SIGTERM);' in tweak
assert 'BCXCloseBackgroundApps();\n        kill(getpid(), SIGTERM);' in tweak
assert 'position >= edgeInsetValue && position <= leftEnd' in tweak
assert 'position >= rightStart && position <= 1 - edgeInsetValue' in tweak
assert 'state == UIGestureRecognizerStateEnded && (distance >= 80 || velocity >= 700)' in tweak
assert 'BCXApplicationQuickActions' in data
assert 'BCXAllQuickActions' in data and 'BCXRequestQuickActions(@"*")' in panel_settings
assert 'SBIconController' in tweak and 'activateShortcut:withBundleIdentifier:forIconView:' in tweak
assert 'UISearchResultsUpdating' in panel_settings and 'localizedCaseInsensitiveContainsString' in panel_settings
assert 'showGestureAreas' in prefs and 'showGestureAreas' in tweak
assert '-velocity.y <= fabs(velocity.x) * 1.15' in tweak
assert 'com.mox1121.shortcutpanel' in common and 'Package: com.mox1121.shortcutpanel' in control
assert 'Name: ShortcutPanel' in control
assert 'customSymbol' in data and 'customImage' in data
assert '_applicationIconImageForBundleIdentifier' in data
assert '_fetchApplicationShortcutItemsIfAppropriate' in data
assert 'fetchApplicationShortcutItemsOfTypes:forBundleIdentifier:withCompletionHandler:' in data
assert 'for (NSInteger attempt = 0; attempt < 60; attempt++)' in data

db = sqlite3.connect(":memory:")
db.execute("CREATE TABLE ZSHORTCUT (ZWORKFLOWID TEXT, ZNAME TEXT)")
db.execute("INSERT INTO ZSHORTCUT VALUES (?, ?)", ("stable-id", "测试指令"))
list_query = re.search(r'"(SELECT ZWORKFLOWID, ZNAME FROM ZSHORTCUT[^\"]+)"', data).group(1)
assert db.execute(list_query).fetchall() == [("stable-id", "测试指令")]
assert "BCXRequestQuickActions" in data and "BCXQuickRequestReceived" in tweak

for action in ("closeapps", "closeandrespring", "respring", "userspace", "reboot", "shutdown"):
    assert f'@"{action}"' in data and f'@"{action}"' in tweak

print("panel contract OK")
