"""Host-side check for the panel's saved IDs and Shortcuts query."""

from pathlib import Path
import re
import sqlite3


root = Path(__file__).resolve().parents[1]
data = (root / "PanelData.m").read_text(encoding="utf-8")
prefs = (root / "Prefs" / "Preference.m").read_text(encoding="utf-8")
tweak = (root / "Tweak.xm").read_text(encoding="utf-8")

assert prefs.count('key:@"BottomLeftGesture"') == 1
assert prefs.count('key:@"BottomCenterGesture"') == 1
assert prefs.count('key:@"BottomRightGesture"') == 1
assert 'key:@"AppBottom' not in prefs and 'key:@"SBBottom' not in prefs
assert "case BCX_PANEL_ACTION:" in tweak
assert tweak.count("BCXClaimsSwipe(normalizedPoint.x)") == 2
assert 'NSString *name = item[@"title"]' in tweak

db = sqlite3.connect(":memory:")
db.execute("CREATE TABLE ZSHORTCUT (ZWORKFLOWID TEXT, ZNAME TEXT)")
db.execute("INSERT INTO ZSHORTCUT VALUES (?, ?)", ("stable-id", "测试指令"))
list_query = re.search(r'"(SELECT ZWORKFLOWID, ZNAME FROM ZSHORTCUT[^\"]+)"', data).group(1)
assert db.execute(list_query).fetchall() == [("stable-id", "测试指令")]
assert "BCXRequestQuickActions" in data and "BCXQuickRequestReceived" in tweak

for action in ("closeapps", "closeandrespring", "respring", "userspace"):
    assert f'@"{action}"' in data and f'@"{action}"' in tweak

print("panel contract OK")
