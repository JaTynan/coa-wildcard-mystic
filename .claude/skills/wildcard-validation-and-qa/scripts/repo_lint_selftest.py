#!/usr/bin/env python3
"""Self-test for repo_lint.py: builds two tiny fake repositories in a temporary folder, one clean and one with a
planted mistake for every check, and confirms the lint passes the first and reports each planted mistake in the
second. Run it after changing repo_lint.py:

    python3 -I .claude/skills/wildcard-validation-and-qa/scripts/repo_lint_selftest.py

Exit code 0 = every expectation held. Standard library only; touches nothing outside its temporary folder.
"""
import json
import os
import subprocess
import sys

sys.dont_write_bytecode = True  # no __pycache__ in the skill folder
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
LINT = os.path.join(HERE, "repo_lint.py")

RESET = """-- reset
CREATE TABLE IF NOT EXISTS `wcme_owned` (`tbl` VARCHAR(32) NOT NULL, `id` INT NOT NULL, PRIMARY KEY (`tbl`, `id`));
DELETE FROM `spell_linked_spell` WHERE `comment` LIKE 'WCME:%';
DELETE `s` FROM `spell_dbc` `s` JOIN `wcme_owned` `o` ON `o`.`tbl` = 'spell_dbc' AND `o`.`id` = `s`.`ID`;
DELETE `p` FROM `spell_proc` `p` JOIN `wcme_owned` `o` ON `o`.`tbl` = 'spell_proc' AND `o`.`id` = `p`.`SpellId`;
CREATE TABLE IF NOT EXISTS `wcme_enchant_teach` (`enchant_spell` INT UNSIGNED NOT NULL, PRIMARY KEY (`enchant_spell`));
DELETE FROM `wcme_enchant_teach`;
DELETE FROM `spell_script_names` WHERE `ScriptName` LIKE 'spell\\_wcme\\_%';
DELETE FROM `wcme_owned`;
"""

GOOD_SQL = """-- a good file; a semicolon inside a string 'a;b' and a comment with one; must not split statements
INSERT IGNORE INTO `wcme_owned` (`tbl`, `id`) VALUES ('spell_proc', 100), ('spell_dbc', 200);
DELETE FROM `spell_proc` WHERE `SpellId` IN (100);
INSERT INTO `spell_proc` (`SpellId`, `Chance`) VALUES (100, 50);
INSERT INTO `spell_dbc` (`ID`, `Name`) VALUES (200, 'It''s; fine');
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES (1, 2, 2, 'WCME: twin');
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES (100, 'spell_wcme_thing');
INSERT INTO `wcme_enchant_teach` VALUES (5);
DELETE FROM `npc_vendor` WHERE `entry` = 7 AND `item` = 8;
INSERT INTO `npc_vendor` (`entry`, `item`) VALUES (7, 8);
"""

BAD_SQL = """-- a bad file
INSERT INTO `spell_proc` (`SpellId`, `Chance`) VALUES (300, 50);
INSERT INTO `spell_linked_spell` (`spell_trigger`, `spell_effect`, `type`, `comment`) VALUES (1, 2, 2, 'no marker');
INSERT INTO `npc_vendor` (`entry`, `item`) VALUES (7, 9);
CREATE TABLE `wcme_thing` (`id` INT);
DROP TABLE `creature_template`;
UPDATE `acore_characters`.`characters` SET `money` = 1;
UPDATE `item_template` SET `stackable` = `stackable` * 2 WHERE `entry` = 5;
INSERT INTO `wcme_owned` (`tbl`, `id`) VALUES ('spell_proc', 100);
INSERT INTO `wcme_owned` (`tbl`, `id`) VALUES ('spel_proc', 101);
DROP DATABASE acore_world;
"""

PATCH = '''$code = @"
    if (sConfigMgr->GetOption<bool>(`"Wildcard.Good`", true)) { }
    uint32 n = sConfigMgr->GetOption<uint32>(
        "Wildcard.AlsoGood", 3);
"@
'''
BAD_PATCH = '''$code = @"
    if (sConfigMgr->GetOption<bool>(`"Wildcard.NotListed`", true)) { }
    static constexpr uint32 SYNCHRONIZE = 986165;
    // DELETE = this comment line must not be reported
'''


def write(root, path, text, newline="\n"):
    full = os.path.join(root, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "wb") as handle:
        handle.write(text.replace("\n", newline).encode("utf-8"))


def base(root):
    write(root, "CHANGES.md", "| `10-good.ps1` | x | `Wildcard.Good` |\n| `mystic-*.patch` | y | |\n")
    write(root, "patches/10-good.ps1", PATCH)
    write(root, "patches/mystic-a.patch", "--- a/x\n+++ b/x\n@@ -1 +1,2 @@\n ctx GetOption<bool>(\"Core.Own\", 1)\n+new line\n")
    write(root, "server-settings/server-settings.txt",
          "# comment\nworldserver.conf | Wildcard.Good = 1\nworldserver.conf | Wildcard.AlsoGood = 3\n")
    write(root, "sql/enchants/000-reset.sql", RESET)
    write(root, "sql/enchants/001-good.sql", GOOD_SQL)
    write(root, "addon/Thing/Thing.toc", "## Interface: 30300\n## Version: 1.2\nThing.lua\n")
    write(root, "addon/Thing/Thing.lua", "local VERSION = \"1.2\"\n")
    write(root, "addon/third-party-addons.txt", "# pins\nowner/repo | " + "a" * 40 + " | Folder\n")
    write(root, "patch-night/Run.cmd", "@echo off\n", "\r\n")
    write(root, "patch-night/Run.ps1", "Write-Host 'hello'\n", "\r\n")
    write(root, "launcher/launcher-settings.json", "{\"site\": \"https://example.invalid\"}\n")
    write(root, "enchants/tracker.csv", "spell,name,status,fix file,tested\n1,A,verified,001-good.sql,2026-11-03 pass\n2,B,live,,\n")
    write(root, "enchants/test-checklist.csv", "file,spell,result\n001,1,pass\n")
    write(root, "scripts/tool.py", "print('ok')\n")


def bad(root):
    base(root)
    write(root, "CHANGES.md", "| `10-good.ps1` | x | |\n| `77-gone.ps1` | removed | |\n")
    write(root, "patches/10-other.ps1", "Write-Host 1\n")                       # duplicate number
    write(root, "patches/100-late.ps1", "Write-Host 1\n")                       # sorts out of order, no CHANGES row
    write(root, "patches/20-bad.ps1", BAD_PATCH)                                 # unknown option, unclosed here-string
    write(root, "patches/30-crlf.ps1", "Write-Host 1\n", "\r\n")                # CRLF patch script
    write(root, "patches/mystic-a.patch", "--- a/x\n+++ b/x\n", "\r\n")         # CRLF .patch
    write(root, "server-settings/server-settings.txt",
          "worldserver.conf | Wildcard.Good = 1\nworldserver.conf | Wildcard.Good = 2\nthis line is wrong\n")
    write(root, "sql/enchants/002-bad.sql", BAD_SQL)
    write(root, "sql/enchants/002-twin.sql", "DELETE FROM `wcme_enchant_teach`;\n")
    write(root, "addon/Thing/Thing.toc", "## Interface: 11200\n## Version: 1.2\nThing.lua\nMissing.lua\n")
    write(root, "addon/Thing/Thing.lua", "local VERSION = \"1.3\"\n")
    write(root, "addon/Thing/Extra.lua", "-- never loaded\n")
    write(root, "addon/third-party-addons.txt", "owner/repo | main | Folder\n")
    write(root, "patch-night/Run.cmd", "@echo off\n", "\n")
    full = os.path.join(root, "patch-night/Mixed.ps1")
    with open(full, "wb") as handle:
        handle.write(b"Write-Host 1\r\nWrite-Host 2\n")
    write(root, "launcher/launcher-settings.json", "{\"site\": }\n")
    write(root, "launcher/x.py", "def broken(:\n")
    write(root, "client-patch/patch-ZZW.MPQ", "x")
    write(root, "signup/signup-settings.json", "{}\n")
    write(root, "signup/notes.txt", "token = \"" + "ghp_" + "A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8" + "\"\n")
    write(root, "enchants/tracker.csv",
          "spell,name,status,fix file,tested\n1,A,verified,,\n1,B,live,099-gone.sql,3 Nov pass\n")
    write(root, "enchants/test-checklist.csv", "file,spell,result\n099,1\n")


EXPECT_BAD = {
    "patch-number-dup", "patch-order", "changes-row", "changes-stale", "settings-missing", "settings-format",
    "settings-dup", "sql-number-dup", "sql-rerun", "sql-marker", "sql-forbidden", "sql-other-db",
    "sql-relative-update", "sql-owned-dup", "sql-owned-key", "sql-not-owned", "client-data", "secret-file", "secret",
    "addon-pin", "eol-mixed", "eol-cmd", "eol-patch-script", "eol-patch", "json-parse", "py-parse", "ps1-herestring",
    "csv-width", "toc-interface", "toc-file", "toc-unlisted", "addon-version", "tracker-dup", "tracker-verified",
    "tracker-fix-file", "tracker-tested-format", "checklist-file", "win-macro",
}


def run(root):
    out = subprocess.run([sys.executable, "-I", LINT, "--root", root, "--json"], capture_output=True, text=True)
    return out.returncode, json.loads(out.stdout)


def main():
    failures = []
    with tempfile.TemporaryDirectory() as temp:
        good_root, bad_root = os.path.join(temp, "good"), os.path.join(temp, "bad")
        base(good_root)
        bad(bad_root)
        code, result = run(good_root)
        noisy = [f for f in result["findings"] if f["severity"] != "info"]
        if code != 0 or noisy:
            failures.append("clean repository: exit %d, unexpected findings: %s"
                            % (code, "; ".join("%s %s" % (f["check"], f["path"]) for f in noisy)))
        code, result = run(bad_root)
        seen = {f["check"] for f in result["findings"] if f["severity"] != "info"}
        if code != 1:
            failures.append("broken repository: exit code %d, expected 1" % code)
        for check in sorted(EXPECT_BAD - seen):
            failures.append("broken repository: planted mistake not reported: %s" % check)
        if "lint-crash" in seen:
            failures.append("a check crashed: %s" % [f["message"] for f in result["findings"] if f["check"] == "lint-crash"])
        print("clean repository: PASS expected, got exit %s" % ("0" if not failures else "see below"))
        print("broken repository: %d of %d planted mistakes reported; %d distinct check ids fired"
              % (len(EXPECT_BAD & seen), len(EXPECT_BAD), len(seen)))
    for failure in failures:
        print("FAIL: " + failure)
    print("SELF-TEST " + ("FAILED" if failures else "PASSED"))
    return 1 if failures else 0


if __name__ == "__main__":
    import argparse
    argparse.ArgumentParser(
        description=(__doc__ or "") + "\nTakes no options. Builds a clean and a broken fake repository in a temporary "
        "folder, runs repo_lint.py on each and compares the verdicts. Run from any folder.\n"
        "Exit codes: 0 SELF-TEST PASSED; 1 the lint missed a planted mistake or flagged the clean fixture; "
        "2 bad arguments.",
        formatter_class=argparse.RawDescriptionHelpFormatter).parse_args()
    sys.exit(main())
