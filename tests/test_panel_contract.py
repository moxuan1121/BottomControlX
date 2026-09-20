"""Host-side check for the panel's saved IDs and Shortcuts query."""

from pathlib import Path
import re
import sqlite3


root = Path(__file__).resolve().parents[1]
data = (root / "PanelData.m").read_text(encoding="utf-8")
prefs = (root / "Prefs" / "Preference.m").read_text(encoding="utf-8")
tweak = (root / "Tweak.xm").read_text(encoding="utf-8")

assert 'key:@"BottomLeftGesture"' not in prefs
assert 'key:@"BottomCenterGesture"' not in prefs
assert 'key:@"BottomRightGesture"' not in prefs
for zone in ("BCX_LEFT_ITEMS", "BCX_CENTER_ITEMS", "BCX_RIGHT_ITEMS"):
    assert zone in prefs and zone in tweak
assert 'key:@"leftValue"' in prefs and 'key:@"rightWidth"' in prefs
assert 'activeItems.count > 1' in tweak
assert 'activeItems.count == 1' in tweak
assert 'BCXFinishPanel(commit)' in tweak
assert 'WFSpringBoardWorkflowRunnerClient' in tweak
assert 'shortcuts://run-shortcut' not in tweak
assert 'BCXRebootUserspace()' in tweak and '"reboot_userspace"' in tweak
assert 'customSymbol' in data and 'customImage' in data
assert '_applicationIconImageForBundleIdentifier' in data
assert '_fetchApplicationShortcutItemsIfAppropriate' in data

db = sqlite3.connect(":memory:")
db.execute("CREATE TABLE ZSHORTCUT (ZWORKFLOWID TEXT, ZNAME TEXT)")
db.execute("INSERT INTO ZSHORTCUT VALUES (?, ?)", ("stable-id", "测试指令"))
list_query = re.search(r'"(SELECT ZWORKFLOWID, ZNAME FROM ZSHORTCUT[^\"]+)"', data).group(1)
assert db.execute(list_query).fetchall() == [("stable-id", "测试指令")]
assert "BCXRequestQuickActions" in data and "BCXQuickRequestReceived" in tweak

for action in ("closeapps", "closeandrespring", "respring", "userspace"):
    assert f'@"{action}"' in data and f'@"{action}"' in tweak

print("panel contract OK")
