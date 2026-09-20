"""Small host-side check for the panel's saved IDs and Shortcuts query."""

from pathlib import Path
import re
import sqlite3


root = Path(__file__).resolve().parents[1]
data = (root / "PanelData.m").read_text(encoding="utf-8")
prefs = (root / "Prefs" / "Preference.m").read_text(encoding="utf-8")
tweak = (root / "Tweak.xm").read_text(encoding="utf-8")

gesture_values = re.findall(r"\[spec setValues:@\[([^]]+)\]\s*titles:@\[([^]]+)\]\]", prefs)
assert sum("@11" in values and "快捷面板" in titles for values, titles in gesture_values) == 6
assert "case BCX_PANEL_ACTION:" in tweak

db = sqlite3.connect(":memory:")
db.execute("CREATE TABLE ZSHORTCUT (ZWORKFLOWID TEXT, ZNAME TEXT)")
db.execute("INSERT INTO ZSHORTCUT VALUES (?, ?)", ("stable-id", "测试指令"))
list_query = re.search(r'"(SELECT ZWORKFLOWID, ZNAME FROM ZSHORTCUT[^\"]+)"', data).group(1)
name_query = re.search(r'"(SELECT ZNAME FROM ZSHORTCUT[^\"]+)"', data).group(1)
assert db.execute(list_query).fetchall() == [("stable-id", "测试指令")]
assert db.execute(name_query, ("stable-id",)).fetchone() == ("测试指令",)

for action in ("closeapps", "closeandrespring", "respring", "userspace"):
    assert f'@"{action}"' in data and f'@"{action}"' in tweak

print("panel contract OK")
