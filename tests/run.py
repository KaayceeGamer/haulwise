import sys, os, re, lupa.lua51 as L

DIR, TESTS = sys.argv[1], sys.argv[2]


def run(locale=None):
    lua = L.LuaRuntime(unpack_returned_tuples=True)
    lua.globals().DIR = DIR
    lua.execute(open(TESTS + "/mock.lua").read())
    if locale:
        # Same scenarios in another language: texts differ, so text checks only warn.
        lua.globals().PSEUDO = False
        lua.globals().LOCALE_RUN = True
        lua.execute('GetLocale = function() return "%s" end' % locale)
    for s in ("scenario.lua", "scenario2.lua", "scenario3.lua", "scenario4.lua"):
        try:
            lua.execute(open(TESTS + "/" + s).read())
        except Exception as e:
            if not locale:
                raise
            msg = str(e)
            if "FAIL:" in msg or "assert" in msg.lower() or "expected" in msg:
                print("  (%s: stopped at a text check in %s)" % (locale, s))
                return lua
            raise
    return lua


run()

# Every text the code looks up must be in both translations, with the same %s/%d and colours.
KEY = re.compile(r'L\["((?:[^"\\\n]|\\.)*)"\]')
keys = set()
for f in os.listdir(DIR):
    if f.endswith(".lua") and f != "Data.lua":
        keys.update(KEY.findall(open(os.path.join(DIR, f), encoding="utf-8").read()))
keys.discard("English text")
SPEC = re.compile(r'%[-\d.]*[sdf%]')
COL = re.compile(r'\|c[0-9a-fA-F]{8}|\|r|\\n')
PAIR = re.compile(r'^    \["((?:[^"\\]|\\.)*)"\] = "((?:[^"\\]|\\.)*)",$')
for code in ("deDE", "frFR"):
    have = {}
    for line in open(os.path.join(DIR, "Locales", code + ".lua"), encoding="utf-8"):
        m = PAIR.match(line.rstrip("\n"))
        if m:
            have[m.group(1)] = m.group(2)
    # A key may be left out when the text is the same in that language ("Gold", "HUD").
    missing = [k for k in keys if k not in have and not re.fullmatch(r"[\s|%\w./#:+\-()·]*", k) and len(k) > 12]
    assert not missing, "%s is missing %d texts, e.g. %r" % (code, len(missing), missing[:3])
    for k, v in have.items():
        assert SPEC.findall(k) == SPEC.findall(v), "%s: %%-codes differ in %r" % (code, k)
        assert sorted(COL.findall(k)) == sorted(COL.findall(v)), "%s: colours differ in %r" % (code, k)
    print("LOCALE %s PASSED (%d texts)" % (code, len(have)))

for code in ("deDE", "frFR"):
    lua = run(code)
    errs = lua.eval("Haulwise and Haulwise.db and Haulwise.db.errors or {}")
    real = [e for e in errs.values() if e["where"] not in ("x", "HAULWISE_TEST_EVENT") and "boom" not in str(e["msg"])]
    for e in real:
        print("   ", e["where"], e["msg"])
    assert not real, "%s run hit Lua errors" % code
    print("RUN %s PASSED" % code)
