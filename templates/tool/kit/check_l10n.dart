// dart format width=120
// Translation catalog checks for docs/RULES.md F11: the ARB files that gen-l10n reads.
//
//   dart run tool/kit/check_l10n.dart [--root DIR] [--files F...] [--max-lines N] [--strict] [--json]
//
// It reads l10n.yaml under the root (arb-dir, template-arb-file, use-escaping), with the kit's defaults for what it
// does not set (lib/core/l10n, app_en.arb), and checks every locale against the template: missing and extra keys; the
// placeholders of each message ({name} in the text, plural and select aware) against the template's and against the
// template's @key metadata; duplicate keys (its own JSON reader: dart:convert keeps the last of two equal keys without
// a word); invalid JSON; the curly apostrophe (U+2019). It imports only dart: libraries and writes nothing.
// Output, cap and exit codes as check_structure.dart: one `path:line: rule: message` line per finding, at most
// --max-lines (default 60, 0 shows all), one summary line; exit 0 clean, 1 findings that fail the run, 2 usage.
// With --files, the catalogs are checked only when one of the files is an ARB file or l10n.yaml.

import 'dart:convert';
import 'dart:io';

const _usage =
    'usage: dart run tool/kit/check_l10n.dart [--root DIR] [--files F...] [--max-lines N] [--strict] [--json]';
final _ruleIds = 'F11-catalog F11-json F11-duplicate F11-missing F11-extra F11-placeholder F11-metadata F11-apostrophe'
    .split(' ');

void main(List<String> argv) {
  try {
    final args = Args.parse(argv);
    if (args == null) {
      stdout.writeln(_usage);
      return;
    }
    exitCode = run(args);
  } on UsageError catch (e) {
    stderr
      ..writeln('check_l10n: ${e.message}')
      ..writeln(_usage);
    exitCode = 2;
  }
}

class UsageError implements Exception {
  UsageError(this.message);
  final String message;
}

class Args {
  String root = '.';
  List<String>? files;
  int maxLines = 60;
  bool strict = false;
  bool json = false;

  // Returns null for --help. Accepts `--flag value` and `--flag=value`.
  static Args? parse(List<String> argv) {
    final a = Args();
    final words = <String>[];
    for (final w in argv) {
      final eq = w.indexOf('=');
      words.addAll(w.startsWith('--') && eq > 2 ? [w.substring(0, eq), w.substring(eq + 1)] : [w]);
    }
    var i = 0;
    String value(String flag) {
      if (i + 1 >= words.length) throw UsageError('$flag needs a value');
      i++;
      return words[i];
    }

    for (; i < words.length; i++) {
      final w = words[i];
      switch (w) {
        case '-h' || '--help':
          return null;
        case '--root':
          a.root = value(w);
        case '--max-lines':
          final n = int.tryParse(value(w));
          if (n == null || n < 0) throw UsageError('--max-lines takes a whole number (0 shows every finding)');
          a.maxLines = n;
        case '--strict':
          a.strict = true;
        case '--json':
          a.json = true;
        case '--files':
          final files = a.files ??= <String>[];
          while (i + 1 < words.length && !words[i + 1].startsWith('--')) {
            i++;
            files.add(words[i]);
          }
        default:
          throw UsageError('unknown argument "$w"');
      }
    }
    return a;
  }
}

// ------------------------------------------------------------------------------------------------------------ JSON

sealed class JValue {
  JValue(this.line);
  final int line;
}

class JObject extends JValue {
  JObject(super.line);
  final entries = <(String, int, JValue)>[]; // key, the key's line, value: every entry, duplicates included
}

class JString extends JValue {
  JString(super.line, this.value);
  final String value;
}

class JOther extends JValue {
  JOther(super.line);
}

class JsonError implements Exception {
  JsonError(this.line, this.message);
  final int line;
  final String message;
}

// A strict JSON reader (what gen-l10n accepts) that keeps every key with its line, so a duplicate key shows.
class JsonReader {
  JsonReader(this.s) {
    for (var k = 0; k < s.length; k++) {
      if (s.codeUnitAt(k) == 0x0A) _lineStarts.add(k + 1);
    }
  }

  final String s;
  final _lineStarts = <int>[0];
  int i = 0;

  int lineAt(int offset) {
    var lo = 0;
    var hi = _lineStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_lineStarts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo + 1;
  }

  Never _fail(String what) => throw JsonError(lineAt(i), 'invalid JSON: $what');

  JValue read() {
    if (s.startsWith('﻿')) i = 1;
    _space();
    final v = _value();
    _space();
    if (i < s.length) _fail('text after the end of the top object');
    return v;
  }

  void _space() {
    while (i < s.length && ' \t\r\n'.contains(s[i])) {
      i++;
    }
  }

  JValue _value() {
    if (i >= s.length) _fail('the file ends too early');
    final line = lineAt(i);
    final c = s[i];
    if (c == '{') return _object();
    if (c == '"') return JString(line, _string());
    if (c == '[') {
      i++;
      _space();
      if (i < s.length && s[i] == ']') {
        i++;
        return JOther(line);
      }
      while (true) {
        _space();
        _value();
        _space();
        if (i < s.length && s[i] == ',') {
          i++;
        } else if (i < s.length && s[i] == ']') {
          i++;
          return JOther(line);
        } else {
          _fail('expected "," or "]"');
        }
      }
    }
    for (final word in ['true', 'false', 'null']) {
      if (s.startsWith(word, i)) {
        i += word.length;
        return JOther(line);
      }
    }
    final m = RegExp(r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?').matchAsPrefix(s, i);
    if (m == null || m.end == i) _fail('unexpected character "$c"');
    i = m.end;
    return JOther(line);
  }

  JObject _object() {
    final o = JObject(lineAt(i));
    i++;
    _space();
    if (i < s.length && s[i] == '}') {
      i++;
      return o;
    }
    while (true) {
      _space();
      if (i >= s.length || s[i] != '"') _fail('expected a key in double quotes (a trailing comma?)');
      final keyLine = lineAt(i);
      final key = _string();
      _space();
      if (i >= s.length || s[i] != ':') _fail('expected ":" after "$key"');
      i++;
      _space();
      o.entries.add((key, keyLine, _value()));
      _space();
      if (i < s.length && s[i] == ',') {
        i++;
      } else if (i < s.length && s[i] == '}') {
        i++;
        return o;
      } else {
        _fail('expected "," or "}" after the value of "$key"');
      }
    }
  }

  String _string() {
    final b = StringBuffer();
    i++; // the opening quote
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x22) {
        i++;
        return b.toString();
      }
      if (c < 0x20) _fail('a line break or control character inside a string (write \\n)');
      if (c != 0x5C) {
        b.writeCharCode(c);
        i++;
        continue;
      }
      if (i + 1 >= s.length) break;
      final e = s[i + 1];
      const simple = {'"': '"', r'\': r'\', '/': '/', 'b': '\b', 'f': '\f', 'n': '\n', 'r': '\r', 't': '\t'};
      final mapped = simple[e];
      if (mapped != null) {
        b.write(mapped);
        i += 2;
      } else if (e == 'u' && i + 6 <= s.length && int.tryParse(s.substring(i + 2, i + 6), radix: 16) != null) {
        b.writeCharCode(int.parse(s.substring(i + 2, i + 6), radix: 16));
        i += 6;
      } else {
        _fail('a bad escape "\\$e" in a string');
      }
    }
    _fail('a string is never closed');
  }
}

// ------------------------------------------------------------------------------------------------------------- ICU

class IcuError implements Exception {
  IcuError(this.message);
  final String message;
}

// The placeholder names of one message: `{name}`, and the argument of `{count, plural, ...}` or `{x, select, ...}`
// with the placeholders inside every branch. With use-escaping, text between single quotes is literal.
class Icu {
  Icu(this.text, {required this.escaping});
  final String text;
  final bool escaping;
  final names = <String>{};
  int i = 0;

  static final _name = RegExp('[A-Za-z_][A-Za-z0-9_]*');

  Set<String> read() {
    _message(nested: false);
    return names;
  }

  void _message({required bool nested}) {
    while (i < text.length) {
      final c = text[i];
      if (escaping && c == "'") {
        final close = text.indexOf("'", i + 1);
        i = close < 0 ? text.length : close + 1; // '' is one apostrophe; 'x' quotes x
      } else if (c == '{') {
        _argument();
      } else if (c == '}') {
        if (nested) return;
        throw IcuError('a "}" with no "{" before it');
      } else {
        i++;
      }
    }
    if (nested) throw IcuError('a "{" is never closed');
  }

  void _space() {
    while (i < text.length && text[i].trim().isEmpty) {
      i++;
    }
  }

  String _word() {
    final m = _name.matchAsPrefix(text, i);
    if (m == null) throw IcuError('expected a placeholder name after "{"');
    i = m.end;
    return m[0]!; // a match of _name always has group 0
  }

  void _expect(String c, String what) {
    _space();
    if (i >= text.length || text[i] != c) throw IcuError(what);
    i++;
  }

  void _argument() {
    i++;
    _space();
    names.add(_word());
    _space();
    if (i < text.length && text[i] == '}') {
      i++;
      return;
    }
    _expect(',', 'expected "}" or "," after a placeholder name');
    _space();
    final type = _word();
    _space();
    if (i < text.length && text[i] == '}') {
      i++;
      return;
    }
    _expect(',', 'expected "," after "$type"');
    if (!const {'plural', 'select', 'selectordinal'}.contains(type)) {
      final close = text.indexOf('}', i);
      if (close < 0) throw IcuError('a "{" is never closed');
      i = close + 1;
      return;
    }
    while (true) {
      _space();
      if (i >= text.length) throw IcuError('the $type is never closed');
      if (text[i] == '}') {
        i++;
        return;
      }
      final start = i;
      while (i < text.length && text[i] != '{' && text[i].trim().isNotEmpty) {
        i++;
      }
      final selector = text.substring(start, i);
      if (selector.startsWith('offset:')) continue;
      if (selector.isEmpty) throw IcuError('a $type case with no selector');
      _expect('{', 'expected "{" after the $type case "$selector"');
      _message(nested: true);
      i++; // the '}' that closes the case
    }
  }
}

// --------------------------------------------------------------------------------------------------------- catalog

class Finding {
  Finding(this.path, this.line, this.rule, this.message, {required this.warning});
  final String path;
  final int line;
  final String rule;
  final String message;
  final bool warning;
}

class Catalog {
  Catalog(this.path);
  final String path; // relative to the root
  final texts = <String, String?>{}; // message key: its text (null when the value is not a string)
  final lines = <String, int>{};
  final meta = <String, JValue>{}; // '@key': its metadata
  bool readable = false;
}

class L10n {
  L10n(this.base, {required this.escaping});
  final String base;
  final bool escaping;
  final findings = <Finding>[];

  void add(String path, int line, String rule, String message, {bool warning = false}) =>
      findings.add(Finding(path, line, rule, message, warning: warning));

  Catalog load(String rel) {
    final cat = Catalog(rel);
    final src = utf8.decode(File('$base/$rel').readAsBytesSync(), allowMalformed: true);
    final JValue root;
    try {
      root = JsonReader(src).read();
    } on JsonError catch (e) {
      add(rel, e.line, 'F11-json', e.message);
      return cat;
    }
    if (root is! JObject) {
      add(rel, root.line, 'F11-json', 'a catalog is one JSON object');
      return cat;
    }
    final firstLine = <String, int>{};
    for (final (key, line, value) in root.entries) {
      final first = firstLine[key];
      if (first != null) {
        add(
          rel,
          line,
          'F11-duplicate',
          '"$key" appears twice (first at line $first): JSON keeps the last one '
              'without a word; keep one',
        );
      }
      firstLine[key] ??= line;
      if (key.startsWith('@@')) continue; // global metadata: @@locale and friends
      cat.lines[key] = line;
      if (key.startsWith('@')) {
        cat.meta[key] = value;
      } else {
        cat.texts[key] = value is JString ? value.value : null;
        if (value is! JString) add(rel, line, 'F11-json', 'the value of "$key" must be a string');
      }
      if (value is JString && value.value.contains('’')) {
        add(rel, line, 'F11-apostrophe', '"$key" holds a curly apostrophe (U+2019): use the straight one (\')');
      }
    }
    cat.readable = true;
    return cat;
  }

  // The placeholder names of [key], or null (reported) when the message does not parse.
  Set<String>? placeholders(Catalog cat, String key) {
    final text = cat.texts[key];
    if (text == null) return null;
    try {
      return Icu(text, escaping: escaping).read();
    } on IcuError catch (e) {
      add(cat.path, cat.lines[key] ?? 1, 'F11-placeholder', '"$key": message syntax: ${e.message}');
      return null;
    }
  }

  void checkTemplate(Catalog t) {
    for (final key in t.texts.keys) {
      final used = placeholders(t, key);
      if (used == null) continue;
      final meta = t.meta['@$key'];
      final line = t.lines[key] ?? 1;
      if (meta is! JObject) {
        if (used.isNotEmpty) {
          add(
            t.path,
            line,
            'F11-metadata',
            '"$key" uses ${_list(used)}: add an "@$key" entry that declares each one with its type',
          );
        }
        continue;
      }
      final declared = <String, JValue>{};
      for (final (name, _, value) in meta.entries) {
        if (name == 'placeholders' && value is JObject) {
          for (final (p, _, v) in value.entries) {
            declared[p] = v;
          }
        }
      }
      final undeclared = used.difference(declared.keys.toSet());
      final unused = declared.keys.toSet().difference(used);
      if (undeclared.isNotEmpty) add(t.path, line, 'F11-metadata', '"@$key" does not declare ${_list(undeclared)}');
      if (unused.isNotEmpty) add(t.path, line, 'F11-metadata', '"@$key" declares ${_list(unused)}, unused in the text');
      for (final MapEntry(key: p, value: v) in declared.entries) {
        final typed = v is JObject && v.entries.any((e) => e.$1 == 'type' && e.$3 is JString);
        if (used.contains(p) && !typed) add(t.path, line, 'F11-metadata', '"@$key": placeholder {$p} has no "type"');
      }
    }
  }

  void checkLocale(Catalog t, Catalog c) {
    final name = t.path.split('/').last;
    for (final key in t.texts.keys) {
      if (!c.texts.containsKey(key)) {
        add(c.path, 1, 'F11-missing', 'no "$key" ($name line ${t.lines[key]}): add it, translated');
      }
    }
    for (final key in c.texts.keys) {
      if (!t.texts.containsKey(key)) {
        add(c.path, c.lines[key] ?? 1, 'F11-extra', '"$key" is not in $name: add it there first, or remove it');
        continue;
      }
      final mine = placeholders(c, key);
      final want = Icu(t.texts[key] ?? '', escaping: escaping);
      Set<String> theirs;
      try {
        theirs = want.read();
      } on IcuError {
        continue; // reported on the template
      }
      if (mine != null && (mine.length != theirs.length || !mine.containsAll(theirs))) {
        add(c.path, c.lines[key] ?? 1, 'F11-placeholder', '"$key" uses ${_list(mine)}; $name uses ${_list(theirs)}');
      }
    }
  }

  static String _list(Set<String> names) =>
      names.isEmpty ? 'no placeholder' : (names.toList()..sort()).map((n) => '{$n}').join(' ');
}

// ------------------------------------------------------------------------------------------------------------- run

String _norm(String path) {
  final p = File(path).absolute.uri.normalizePath().toFilePath();
  return p.length > 1 && p.endsWith(Platform.pathSeparator) ? p.substring(0, p.length - 1) : p;
}

// The keys of l10n.yaml this check needs: flat `key: value` lines, so no YAML library is needed.
Map<String, String> _l10nYaml(String base) {
  final f = File('$base/l10n.yaml');
  final out = <String, String>{};
  if (!f.existsSync()) return out;
  for (final raw in f.readAsLinesSync()) {
    final line = raw.replaceFirst(RegExp(r'\s+#.*$'), '');
    final m = RegExp(r'''^([A-Za-z-]+):\s*['"]?([^'"]*?)['"]?\s*$''').firstMatch(line);
    if (m != null) out[m[1]!] = m[2]!; // both groups always take part in a match
  }
  return out;
}

int run(Args args) {
  final base = _norm(args.root);
  if (!Directory(base).existsSync()) throw UsageError('no folder at ${args.root}');
  final yaml = _l10nYaml(base);
  final dir = (yaml['arb-dir'] ?? 'lib/core/l10n').replaceAll(RegExp(r'/+$'), '');
  final templateName = yaml['template-arb-file'] ?? 'app_en.arb';
  final l10n = L10n(base, escaping: yaml['use-escaping'] == 'true');
  final given = args.files;
  if (given != null && !given.any((f) => f.endsWith('.arb') || f.endsWith('l10n.yaml'))) {
    return report(l10n.findings, 0, 0, args, note: 'no ARB file among the files: nothing to check');
  }
  final folder = Directory('$base/$dir');
  final arbs = folder.existsSync()
      ? (folder
            .listSync()
            .whereType<File>()
            .map((f) => f.path.split(Platform.pathSeparator).last)
            .where((n) => n.endsWith('.arb'))
            .toList()
          ..sort())
      : <String>[];
  if (arbs.isEmpty) {
    l10n.add(
      dir,
      1,
      'F11-catalog',
      'no ARB catalog in $dir/: nothing checked (set arb-dir in l10n.yaml)',
      warning: true,
    );
    return report(l10n.findings, 0, 0, args);
  }
  if (!arbs.contains(templateName)) {
    l10n.add('$dir/$templateName', 1, 'F11-catalog', 'the template $templateName is missing from $dir/');
    return report(l10n.findings, arbs.length, 0, args);
  }
  final template = l10n.load('$dir/$templateName');
  if (template.readable) l10n.checkTemplate(template);
  for (final name in arbs.where((n) => n != templateName)) {
    final cat = l10n.load('$dir/$name');
    if (cat.readable && template.readable) l10n.checkLocale(template, cat);
  }
  return report(l10n.findings, arbs.length, template.texts.length, args, note: '$dir/, template $templateName');
}

int report(List<Finding> found, int catalogs, int keys, Args args, {String note = ''}) {
  found.sort((a, b) {
    if (a.warning != b.warning) return a.warning ? 1 : -1;
    final byPath = a.path.compareTo(b.path);
    if (byPath != 0) return byPath;
    // List.sort is not stable: the message breaks a tie, so every run prints the same order.
    return a.line != b.line ? a.line.compareTo(b.line) : a.message.compareTo(b.message);
  });
  final errors = found.where((f) => !f.warning).length;
  final warnings = found.length - errors;
  final counts = <String, int>{
    for (final r in _ruleIds)
      if (found.any((f) => f.rule == r)) r: found.where((f) => f.rule == r).length,
  };
  final passed = errors == 0 && !(args.strict && warnings > 0);
  final shown = found.take(args.maxLines == 0 ? found.length : args.maxLines).toList();
  final more = found.length - shown.length;
  if (args.json) {
    stdout.writeln(
      jsonEncode({
        'tool': 'check_l10n',
        'passed': passed,
        'catalogs': catalogs,
        'keys': keys,
        'errors': errors,
        'warnings': warnings,
        'counts': counts,
        'findings': [
          for (final f in shown)
            {
              'path': f.path,
              'line': f.line,
              'rule': f.rule,
              'severity': f.warning ? 'warning' : 'error',
              'message': f.message,
            },
        ],
        'more': more,
      }),
    );
    return passed ? 0 : 1;
  }
  for (final f in shown) {
    stdout.writeln('${f.path}:${f.line}: ${f.rule}: ${f.warning ? 'warning: ' : ''}${f.message}');
  }
  if (more > 0) stdout.writeln('... $more more findings not shown (--max-lines 0 shows all)');
  final byRule = counts.isEmpty ? '' : ' [${counts.entries.map((e) => '${e.key} ${e.value}').join(', ')}]';
  final strict = !passed && errors == 0 ? ' (--strict: warnings fail the run)' : '';
  final what = note.isEmpty ? '' : ' ($note)';
  stdout.writeln(
    'check_l10n: ${passed ? 'passed' : 'FAILED'}$strict, ${_n(errors, 'error')} and ${_n(warnings, 'warning')} in '
    '${_n(catalogs, 'catalog')}, ${_n(keys, 'key')}$what$byRule',
  );
  return passed ? 0 : 1;
}

String _n(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
