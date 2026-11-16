#!/usr/bin/env bash
# The static checks: what a contributor breaks most often, checked in seconds without running anything.
# 1. Syntax: bash -n on every .sh, node --check on every .mjs and .js, the Python compiler on every .py (its
#    output goes to a temp folder, so no __pycache__ lands in the kit).
# 2. tests/static/check.mjs on the kit: JSON, the skill format, the hooks, the manifest, the scan for anything real.
# 3. A self-test of check.mjs on small planted trees, so a scan that stopped seeing problems fails here.
# 4. tests/run-all.sh on a fake area: strict unless --lenient or KIT_STRICT=0, and a missing area is skipped.
# A problem in a plumbing file fails; in another package's file it is a warning (--strict or KIT_STRICT=1: fails).
# Optional: KIT_PRIVATE_PATTERN, a case-insensitive regular expression of real names (your apps, people), also
# fails on every line that holds one; the kit never stores those names.
# usage: tests/static/run.sh [--strict]
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
STRICT=""
case "${1:-}" in
  "") ;;
  --strict) STRICT=--strict ;;
  *) echo "usage: tests/static/run.sh [--strict]" >&2; exit 2 ;;
esac
[ "${KIT_STRICT:-0}" = 1 ] && STRICT=--strict
for tool in node python3; do
  command -v "$tool" >/dev/null 2>&1 || { echo "static: $tool is required" >&2; exit 1; }
done
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

failed=0
syntax_fail=0
syntax_warn=0
checked=0
# own <path relative to the kit>: true for the plumbing package's files (the same list as check.mjs).
own() {
  case "$1" in
    .claude-plugin/* | install.mjs | README.md | LICENSE | templates/scripts/tools/* | templates/CLAUDE.md) return 0 ;;
    hooks/token-guard.mjs) return 1 ;;
    hooks/* | skills/tools/* | skills/new-project/* | tests/run-all.sh) return 0 ;;
    tests/install/* | tests/guard-bash/* | tests/save-chat/* | tests/tools/* | tests/static/* | tests/token-guard/*) return 0 ;;
  esac
  return 1
}
# syntax <path> <what>: a syntax error fails in a plumbing file (or with --strict), else it is a warning.
syntax() {
  local r=${1#"$ROOT"/}
  if [ -n "$STRICT" ] || own "$r"; then
    echo "FAIL $2: $r"
    syntax_fail=$((syntax_fail + 1))
  else
    echo "warn $2: $r (another package's file)"
    syntax_warn=$((syntax_warn + 1))
  fi
}
while IFS= read -r f; do
  checked=$((checked + 1))
  bash -n "$f" 2>"$T/err" || { sed 's/^/     | /' "$T/err" | head -5; syntax "$f" "bash -n"; }
done < <(find "$ROOT" -name '*.sh' -not -path '*/.git/*' -not -path '*/node_modules/*')
while IFS= read -r f; do
  checked=$((checked + 1))
  node --check "$f" 2>"$T/err" || { sed 's/^/     | /' "$T/err" | head -5; syntax "$f" "node --check"; }
done < <(find "$ROOT" \( -name '*.mjs' -o -name '*.js' \) -not -path '*/.git/*' -not -path '*/node_modules/*')
n=0
while IFS= read -r f; do
  checked=$((checked + 1))
  n=$((n + 1))
  python3 -I -c 'import py_compile, sys; py_compile.compile(sys.argv[1], cfile=sys.argv[2], doraise=True)' \
    "$f" "$T/py-$n.pyc" 2>"$T/err" || { sed 's/^/     | /' "$T/err" | head -5; syntax "$f" "python compile"; }
done < <(find "$ROOT" -name '*.py' -not -path '*/.git/*' -not -path '*/node_modules/*')
echo "syntax: $checked scripts (bash -n, node --check, the Python compiler), $syntax_fail failed, $syntax_warn warning(s)"
[ "$syntax_fail" -eq 0 ] || failed=1

# The manifest check with Claude Code itself: opt-in, since the CLI reads the user's own settings. CLAUDE_BIN names
# the binary when it is not on the PATH (the VS Code extension ships its own). Asked for and not found: a failure,
# never a silent skip.
if [ "${KIT_CLAUDE_VALIDATE:-0}" = 1 ]; then
  cli="${CLAUDE_BIN:-$(command -v claude 2>/dev/null)}"
  if [ -z "$cli" ] || [ ! -x "$cli" ]; then
    echo "FAIL claude plugin validate: no claude CLI (put it on the PATH or set CLAUDE_BIN)"; failed=1
  else
    (cd "$ROOT" && "$cli" plugin validate .) || { echo "FAIL claude plugin validate ."; failed=1; }
  fi
fi

node "$HERE/check.mjs" "$ROOT" $STRICT >"$T/kit.out" 2>&1 || failed=1
grep -v '^static: ' "$T/kit.out"
kit_line="$(grep '^static: ' "$T/kit.out" | tail -n 1)"
# The self-test trees below must not meet the caller's own names.
unset KIT_PRIVATE_PATTERN

# The self-test: planted problems must be found, the allowed forms must pass. The scheme, the e-mail's at sign
# and the home folders are joined at run time, so this file itself holds none of them.
S="https:"
AT="@"
M="$T/mini"
mkdir -p "$M/hooks" "$M/skills/good-skill" "$M/skills/bad-skill" "$M/.claude-plugin" "$M/templates/scripts/tools"
printf '{ "hooks": {} }\n' >"$M/hooks/hooks.json"
printf '{ "name": "perfect-vibecoding-rules-flutter", "repository": "%s//github.com/abdel-hilali/perfect-vibecoding-rules-flutter" }\n' "$S" >"$M/.claude-plugin/plugin.json"
printf '{ "plugins": [{ "name": "perfect-vibecoding-rules-flutter", "source": "./" }] }\n' >"$M/.claude-plugin/marketplace.json"
cat >"$M/README.md" <<MD
git clone $S//github.com/abdel-hilali/perfect-vibecoding-rules-flutter.git
See $S//github.com/abdel-hilali/perfect-vibecoding-rules-flutter.
Base URL: $S//api.example.com/v1, a mail to orders${AT}example.com, xmlns http://schemas.android.com/apk/res/android
Home: /home/user/projects and ~/.claude, local 127.0.0.1
MD
printf '%s//github.com/someone/other-kit\n%s//github.com/abdel-hilali/perfect-vibecoding-rules-flutter-fork\n%s//pub.dev/packages/dio\n' "$S" "$S" "$S" >"$M/templates/scripts/tools/bad.md"
printf 'write to someone%smail.test.org\nthe app at /ho%sme/realname/apps/x and /Us%sers/realname/x\nserver 10.1.%s.3\n' "$AT" "" "" 2 >"$M/templates/scripts/tools/real.md"
printf -- '---\nname: good-skill\ndescription: Does a thing. Use when a test needs a good skill.\n---\n\nBody.\n' >"$M/skills/good-skill/SKILL.md"
printf -- '---\nname: other-name\ndescription: No use-when part here.\ncolour: red\n---\n\nBody.\n' >"$M/skills/bad-skill/SKILL.md"
printf 'kill $(pgrep -f worker)\n' >"$M/templates/scripts/tools/kill.sh"
printf '{ not json\n' >"$M/templates/scripts/tools/broken.json"
node "$HERE/check.mjs" "$M" --strict >"$T/mini.out" 2>&1
mini_code=$?
self=0
self_fail() { echo "FAIL self-test: $1"; self=1; }
expect_line() { grep -qF -- "$2" "$T/mini.out" || self_fail "$1"; }
refuse_line() { ! grep -qF -- "$2" "$T/mini.out" || self_fail "$1"; }
[ "$mini_code" -eq 1 ] || self_fail "planted problems must fail (exit $mini_code)"
expect_line "another GitHub URL is reported" 'bad.md: URL host "github.com"'
[ "$(grep -c 'bad.md: URL host "github.com"' "$T/mini.out")" -eq 2 ] || self_fail "both other GitHub URLs are reported"
expect_line "a docs host is reported too" 'bad.md: URL host "pub.dev"'
refuse_line "the kit's own repository URL is allowed" 'README.md: URL host'
expect_line "an e-mail address off example.com" 'real.md: e-mail address at "mail.test.org"'
refuse_line "an example.com address is allowed" 'README.md: e-mail'
expect_line "an absolute home folder (Linux)" 'real.md: an absolute home folder (/home/<name>)'
expect_line "an absolute home folder (macOS)" 'real.md: an absolute home folder (/Users/<name>)'
refuse_line "/home/user is a placeholder" 'README.md: an absolute home folder'
IP="10.1.""2"".3"
expect_line "an IP address" "real.md: IP address $IP"
expect_line "a skill named unlike its folder" 'bad-skill/SKILL.md: name "other-name" differs from its folder "bad-skill"'
expect_line "a description without Use when" 'bad-skill/SKILL.md: the description needs a "Use when ..." part'
expect_line "an unknown frontmatter key" 'bad-skill/SKILL.md: frontmatter key not allowed: colour'
refuse_line "a good skill passes" 'good-skill/SKILL.md:'
expect_line "a full-match kill in a script" 'kill.sh: line 1: a full-match kill'
expect_line "broken JSON" 'broken.json: invalid JSON'
expect_line "a missing skill of the ten" 'skills/tools/SKILL.md: is missing'
# Without --strict, the same tree: a problem in another package's file is only a warning.
printf -- '---\nname: wrong\ndescription: x. Use when y.\n---\n' >"$M/skills/bad-skill/SKILL.md"
rm "$M/templates/scripts/tools/kill.sh" "$M/templates/scripts/tools/broken.json" "$M/templates/scripts/tools/bad.md" "$M/templates/scripts/tools/real.md"
mkdir -p "$M/skills/tools" "$M/skills/new-project"
for s in tools new-project; do printf -- '---\nname: %s\ndescription: x. Use when y.\n---\n' "$s" >"$M/skills/$s/SKILL.md"; done
KIT_STRICT=0 node "$HERE/check.mjs" "$M" >"$T/mini.out" 2>&1
mini_code=$?
[ "$mini_code" -eq 0 ] || self_fail "other packages' problems alone must not fail (exit $mini_code)"
expect_line "...they are reported as warnings" 'warn skills/bad-skill/SKILL.md: name "wrong" differs'
# A name given at run time (never written in the kit) is found by line; without the pattern, no name is looked for.
printf 'The first line.\nBuilt for the Qzxv-orders app.\n' >"$M/templates/scripts/tools/private.md"
KIT_PRIVATE_PATTERN='qzxv' node "$HERE/check.mjs" "$M" >"$T/mini.out" 2>&1
[ "$?" -eq 1 ] || self_fail "a private name in a plumbing file must fail"
expect_line "KIT_PRIVATE_PATTERN finds a name, case-insensitive, by its line" 'private.md: line 2 matches KIT_PRIVATE_PATTERN'
refuse_line "...and never repeats the name" 'Qzxv'
node "$HERE/check.mjs" "$M" >"$T/mini.out" 2>&1
refuse_line "without KIT_PRIVATE_PATTERN no name is looked for" 'matches KIT_PRIVATE_PATTERN'
rm "$M/templates/scripts/tools/private.md"
if [ "$self" -eq 0 ]; then echo "self-test: the scan finds every planted problem and passes the allowed forms"; else failed=1; fi

# run-all.sh on a fake area that prints the KIT_STRICT it got: strict unless --lenient or KIT_STRICT=0, and an
# area without its run.sh is skipped, never passed.
R="$T/run-all/tests"
mkdir -p "$R/static"
cp "$ROOT/tests/run-all.sh" "$R/run-all.sh"
printf 'echo "strict=${KIT_STRICT:-unset}"\n' >"$R/static/run.sh"
runner=""
env -u KIT_STRICT bash "$R/run-all.sh" static 2>&1 | grep -q 'strict=1$' || runner="$runner [default: not strict]"
env -u KIT_STRICT bash "$R/run-all.sh" --lenient static 2>&1 | grep -q 'strict=0$' || runner="$runner [--lenient]"
KIT_STRICT=0 bash "$R/run-all.sh" static 2>&1 | grep -q 'strict=0$' || runner="$runner [KIT_STRICT=0]"
bash "$R/run-all.sh" recipes 2>&1 | grep -q '^run-all: 0 area(s) passed, 0 failed, 1 skipped$' ||
  runner="$runner [skip]"
if [ -z "$runner" ]; then echo "run-all: strict unless --lenient or KIT_STRICT=0; a missing area is skipped"
else echo "FAIL run-all.sh:$runner"; failed=1; fi

echo "$kit_line"
[ "$failed" -eq 0 ]
