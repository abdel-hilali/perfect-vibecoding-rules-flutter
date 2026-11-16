// dart format width=120
// Structure and size checks for docs/RULES.md: F1 (sizes), F2 (layers, names, imports), F8 (colours), F10 (icons),
// F11 (literal text), F12 (widget helper methods) and F17 (the test budget).
//
//   dart run tool/kit/check_structure.dart [--root DIR] [--files F...] [--max-lines N] [--strict] [--json]
//
// It reads only lib/ and test/ under the root (a project folder can also hold worktrees and build output with
// thousands of files), writes nothing, and imports only dart: libraries, so it runs in any project before `pub get`.
// Settings come from tool/kit/kit_config.json under the root (or --config FILE); built-in defaults when it is missing.
// Output: one line per finding, `path:line: rule: message`, at most --max-lines of them (default 60, 0 shows all),
// then one summary line, so an agent's context stays small. A full run (no --files) prints, just before the summary,
// `budget: test/ <N> counted lines, lib/ <M>`: scripts grep that prefix. Warnings fail the run only with --strict,
// and F17-budget never fails it; with --files, every finding in those files is an error. Exit codes: 0 clean,
// 1 findings that fail the run, 2 usage or config error.

import 'dart:convert';
import 'dart:io';

const _usage =
    'usage: dart run tool/kit/check_structure.dart [--root DIR] [--files F...] '
    '[--max-lines N] [--strict] [--json] [--config FILE]';

final _ruleIds = [
  ...'F1-file F1-function F1-build F1-exception F2-folder F2-suffix F2-name F2-import'.split(' '),
  ...'F8-color F10-icon F11-text F12-helper F17-budget'.split(' '),
];

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
      ..writeln('check_structure: ${e.message}')
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
  String? config;
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
      if (w.startsWith('--') && eq > 2) {
        words
          ..add(w.substring(0, eq))
          ..add(w.substring(eq + 1));
      } else {
        words.add(w);
      }
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
        case '--config':
          a.config = value(w);
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

// ---------------------------------------------------------------------------------------------------------- config

class SizeException {
  SizeException(this.reason, this.maxLines);
  final String reason;
  final int? maxLines;
}

class Config {
  int fileLines = 350;
  int testFileLines = 450;
  int functionLines = 60;
  int buildLines = 120;
  String controllersDir = 'controllers';
  List<String> coreFolders =
      'common/widgets common/data config errors network supabase router storage theme l10n usecases permissions'.split(
        ' ',
      );
  List<String> featureFolders = 'data/datasources data/models data/repositories domain/entities domain/repositories domain/usecases presentation/pages presentation/widgets'
      .split(' ');
  List<RegExp> libFiles = ['main.dart', 'main_*.dart', 'app.dart'].map(globToRegExp).toList();
  List<RegExp> generated = '**/*.g.dart **/*.freezed.dart lib/core/l10n/generated/** **/firebase_options.dart'
      .split(' ')
      .map(globToRegExp)
      .toList();
  final sizeExceptions = <String, SizeException>{};
  final rules = <String, bool>{};

  // A check runs unless its own id or its family ("F2") is switched off.
  bool isOn(String rule) => rules[rule] ?? rules[rule.split('-').first] ?? true;
}

Config loadConfig(String base, String? path) {
  final cfg = Config();
  final name = path ?? 'tool/kit/kit_config.json';
  final file = File(path ?? '$base/tool/kit/kit_config.json');
  if (!file.existsSync()) {
    if (path != null) throw UsageError('no config file at $path');
    return cfg;
  }
  Object? json;
  try {
    json = jsonDecode(file.readAsStringSync());
  } on FormatException catch (e) {
    throw UsageError('$name is not valid JSON: ${e.message}');
  }
  if (json is! Map<String, Object?>) throw UsageError('$name must hold one JSON object');
  UsageError bad(String what) => UsageError('$name: $what');
  List<String> strings(Object? v, String key) => v is List<Object?> && v.every((e) => e is String)
      ? v.cast<String>()
      : throw bad('$key must be a list of strings');
  for (final MapEntry(:key, :value) in json.entries) {
    if (key.startsWith('//')) continue; // a key that starts with // is a comment
    switch (key) {
      case 'limits':
        _limits(cfg, value, bad);
      case 'controllersDir':
        cfg.controllersDir = value is String && value.isNotEmpty ? value : throw bad('controllersDir must be a name');
      case 'coreFolders':
        cfg.coreFolders = strings(value, key);
      case 'featureFolders':
        cfg.featureFolders = strings(value, key);
      case 'libFiles':
        cfg.libFiles = strings(value, key).map(globToRegExp).toList();
      case 'generated':
        cfg.generated = strings(value, key).map(globToRegExp).toList();
      case 'sizeExceptions':
        _sizeExceptions(cfg, value, bad);
      case 'rules':
        _rules(cfg, value, bad);
      default:
        throw bad('unknown field "$key"');
    }
  }
  return cfg;
}

void _limits(Config cfg, Object? value, UsageError Function(String) bad) {
  if (value is! Map<String, Object?>) throw bad('limits must be an object');
  for (final MapEntry(key: k, value: v) in value.entries) {
    if (k.startsWith('//')) continue;
    final n = v is int && v > 0 ? v : throw bad('limits.$k must be a whole number above 0');
    switch (k) {
      case 'file':
        cfg.fileLines = n;
      case 'testFile':
        cfg.testFileLines = n;
      case 'function':
        cfg.functionLines = n;
      case 'build':
        cfg.buildLines = n;
      default:
        throw bad('unknown field "limits.$k" (file, testFile, function, build)');
    }
  }
}

void _sizeExceptions(Config cfg, Object? value, UsageError Function(String) bad) {
  if (value is! List<Object?>) throw bad('sizeExceptions must be a list');
  for (final (i, e) in value.indexed) {
    if (e is! Map<String, Object?>) throw bad('sizeExceptions[$i] must be an object');
    final path = e['path'];
    final reason = e['reason'];
    final max = e['maxLines'];
    if (path is! String || path.isEmpty) throw bad('sizeExceptions[$i] needs a "path"');
    if (reason is! String || reason.trim().isEmpty) throw bad('sizeExceptions[$i] ($path) needs a "reason"');
    if (max != null && (max is! int || max <= 0)) throw bad('sizeExceptions[$i] ($path): maxLines must be above 0');
    for (final k in e.keys) {
      if (!k.startsWith('//') && !{'path', 'reason', 'maxLines'}.contains(k)) {
        throw bad('sizeExceptions[$i] ($path): unknown field "$k"');
      }
    }
    cfg.sizeExceptions[path] = SizeException(reason, max is int ? max : null);
  }
}

void _rules(Config cfg, Object? value, UsageError Function(String) bad) {
  if (value is! Map<String, Object?>) throw bad('rules must be an object');
  final known = {..._ruleIds, ..._ruleIds.map((r) => r.split('-').first)};
  for (final MapEntry(key: k, value: v) in value.entries) {
    if (k.startsWith('//')) continue;
    if (!known.contains(k)) throw bad('unknown rule "$k" (known: ${known.join(', ')})');
    cfg.rules[k] = v is bool ? v : throw bad('rules.$k must be true or false');
  }
}

// `**/` matches any folders (or none), `**` anything, `*` any part of one name, `?` one character.
RegExp globToRegExp(String glob) {
  final b = StringBuffer('^');
  for (var i = 0; i < glob.length; i++) {
    final c = glob[i];
    if (c == '*' && i + 1 < glob.length && glob[i + 1] == '*') {
      final slash = i + 2 < glob.length && glob[i + 2] == '/';
      b.write(slash ? '(?:.*/)?' : '.*');
      i += slash ? 2 : 1;
    } else if (c == '*') {
      b.write('[^/]*');
    } else if (c == '?') {
      b.write('[^/]');
    } else {
      b.write(RegExp.escape(c));
    }
  }
  b.write(r'$');
  return RegExp(b.toString());
}

// ----------------------------------------------------------------------------------------------------------- lexer

enum K { ident, punct, str, num }

class Tok {
  Tok(this.kind, this.text, this.start, this.end, [this.value = '']);
  final K kind;
  final String text; // the source text; for a string, the whole literal with its quotes
  final int start;
  final int end;
  final String value; // a string's own text: escapes decoded, interpolations left out
  int line = 0;
  int endLine = 0;

  bool isP(String s) => kind == K.punct && text == s;
  bool isId(String s) => kind == K.ident && text == s;
}

// A Dart lexer that knows every comment and string form, so a brace or a word inside a string or a comment never
// counts as code: line and block comments (block comments nest), single, double and triple quotes, raw strings,
// escapes, and `${...}` interpolation with nested braces and nested strings.
class Lexer {
  Lexer(this.src);
  final String src;
  final toks = <Tok>[];
  final lineStarts = <int>[0];

  static final _ops = '...? ?.. ??= ~/= <<= ... => == != <= && || ?? ?. .. += -= *= /= %= &= |= ^= << ++ -- ~/'.split(
    ' ',
  );
  static final _opStarts = {for (final o in _ops) o.codeUnitAt(0)};

  List<Tok> run() {
    final n = src.length;
    var i = src.startsWith('#!') ? _lineEnd(0) : 0;
    while (i < n) {
      final c = src.codeUnitAt(i);
      if (c <= 0x20 || c == 0xA0 || c == 0xFEFF) {
        i++;
      } else if (c == 0x2F && i + 1 < n && src.codeUnitAt(i + 1) == 0x2F) {
        i = _lineEnd(i);
      } else if (c == 0x2F && i + 1 < n && src.codeUnitAt(i + 1) == 0x2A) {
        i = _blockEnd(i);
      } else if (_isQuote(c)) {
        i = _addString(i, i, raw: false);
      } else if (_isIdStart(c)) {
        var j = i + 1;
        while (j < n && _isIdPart(src.codeUnitAt(j))) {
          j++;
        }
        if (j == i + 1 && c == 0x72 && j < n && _isQuote(src.codeUnitAt(j))) {
          i = _addString(i, j, raw: true); // r'...' and r"...": no escapes, no interpolation
        } else {
          toks.add(Tok(K.ident, src.substring(i, j), i, j));
          i = j;
        }
      } else if (_isDigit(c)) {
        final j = _number(i);
        toks.add(Tok(K.num, src.substring(i, j), i, j));
        i = j;
      } else {
        // '>' always stands alone, so `List<List<int>>` closes two type argument lists.
        var op = src[i];
        if (_opStarts.contains(c)) {
          op = _ops.firstWhere((o) => src.startsWith(o, i), orElse: () => op);
        }
        toks.add(Tok(K.punct, op, i, i + op.length));
        i += op.length;
      }
    }
    _setLines();
    return toks;
  }

  int _addString(int start, int quote, {required bool raw}) {
    final value = StringBuffer();
    final end = _string(quote, raw: raw, out: value);
    toks.add(Tok(K.str, src.substring(start, end), start, end, value.toString()));
    return end;
  }

  // Reads the string whose opening quote is at [j]; returns the index after its closing quote.
  int _string(int j, {required bool raw, StringBuffer? out}) {
    final n = src.length;
    final q = src.codeUnitAt(j);
    bool tripleAt(int k) =>
        k + 2 < n && src.codeUnitAt(k) == q && src.codeUnitAt(k + 1) == q && src.codeUnitAt(k + 2) == q;
    final triple = tripleAt(j);
    j += triple ? 3 : 1;
    while (j < n) {
      final c = src.codeUnitAt(j);
      final next = j + 1 < n ? src.codeUnitAt(j + 1) : 0;
      if (c == q && (!triple || tripleAt(j))) return j + (triple ? 3 : 1);
      if (c == 0x0A && !triple) return j; // an unclosed one-line string ends with its line
      if (!raw && c == 0x5C && j + 1 < n) {
        j = _escape(j, out);
      } else if (!raw && c == 0x24 && next == 0x7B) {
        j = _interpolation(j + 2);
      } else if (!raw && c == 0x24 && _isIdStart(next) && next != 0x24) {
        j += 2;
        while (j < n && _isIdPart(src.codeUnitAt(j)) && src.codeUnitAt(j) != 0x24) {
          j++;
        }
      } else {
        out?.writeCharCode(c);
        j++;
      }
    }
    return j;
  }

  int _escape(int j, StringBuffer? out) {
    final n = src.length;
    final e = src[j + 1];
    var next = j + 2;
    int hex(int from, int to) => int.tryParse(src.substring(from, to > n ? n : to), radix: 16) ?? 0x20;
    var code = switch (e) {
      'n' => 0x0A,
      'r' => 0x0D,
      't' => 0x09,
      'b' => 0x08,
      'f' => 0x0C,
      'v' => 0x0B,
      _ => e.codeUnitAt(0),
    };
    if (e == 'x') {
      code = hex(j + 2, j + 4);
      next = j + 4 > n ? n : j + 4;
    } else if (e == 'u' && j + 2 < n && src.codeUnitAt(j + 2) == 0x7B) {
      final close = src.indexOf('}', j + 3);
      code = hex(j + 3, close < 0 ? n : close);
      next = close < 0 ? n : close + 1;
    } else if (e == 'u') {
      code = hex(j + 2, j + 6);
      next = j + 6 > n ? n : j + 6;
    }
    out?.writeCharCode(code > 0x10FFFF ? 0x20 : code);
    return next;
  }

  // Skips the code of an interpolation, from just after its `${` to just after its closing brace.
  int _interpolation(int j) {
    final n = src.length;
    var depth = 1;
    while (j < n) {
      final c = src.codeUnitAt(j);
      if (c == 0x7B) {
        depth++;
      } else if (c == 0x7D && --depth == 0) {
        return j + 1;
      } else if (_isQuote(c)) {
        final raw = src.codeUnitAt(j - 1) == 0x72 && (j < 2 || !_isIdPart(src.codeUnitAt(j - 2)));
        j = _string(j, raw: raw);
        continue;
      } else if (c == 0x2F && j + 1 < n && src.codeUnitAt(j + 1) == 0x2F) {
        j = _lineEnd(j);
        continue;
      } else if (c == 0x2F && j + 1 < n && src.codeUnitAt(j + 1) == 0x2A) {
        j = _blockEnd(j);
        continue;
      }
      j++;
    }
    return j;
  }

  int _lineEnd(int j) {
    final k = src.indexOf('\n', j);
    return k < 0 ? src.length : k;
  }

  int _blockEnd(int j) {
    var depth = 0;
    while (j < src.length) {
      if (src.startsWith('/*', j)) {
        depth++;
        j += 2;
      } else if (src.startsWith('*/', j)) {
        depth--;
        j += 2;
        if (depth == 0) return j;
      } else {
        j++;
      }
    }
    return src.length;
  }

  int _number(int j) {
    final n = src.length;
    bool at(int k, bool Function(int) test) => k < n && test(src.codeUnitAt(k));
    if (src.codeUnitAt(j) == 0x30 && at(j + 1, (c) => c | 0x20 == 0x78)) {
      j += 2;
      while (at(j, (c) => _isHex(c) || c == 0x5F)) {
        j++;
      }
      return j;
    }
    int digits(int k) {
      while (at(k, (c) => _isDigit(c) || c == 0x5F)) {
        k++;
      }
      return k;
    }

    j = digits(j);
    if (at(j, (c) => c == 0x2E) && at(j + 1, _isDigit)) j = digits(j + 1);
    if (at(j, (c) => c | 0x20 == 0x65)) {
      final k = at(j + 1, (c) => c == 0x2B || c == 0x2D) ? j + 2 : j + 1;
      if (at(k, _isDigit)) j = digits(k);
    }
    return j;
  }

  void _setLines() {
    for (var k = 0; k < src.length; k++) {
      if (src.codeUnitAt(k) == 0x0A) lineStarts.add(k + 1);
    }
    var li = 0; // tokens come in order, so one forward walk over the line starts is enough
    for (final t in toks) {
      while (li + 1 < lineStarts.length && lineStarts[li + 1] <= t.start) {
        li++;
      }
      var le = li;
      while (le + 1 < lineStarts.length && lineStarts[le + 1] <= t.end - 1) {
        le++;
      }
      t
        ..line = li + 1
        ..endLine = le + 1;
    }
  }

  static bool _isQuote(int c) => c == 0x27 || c == 0x22;
  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
  static bool _isHex(int c) => _isDigit(c) || (c | 0x20) >= 0x61 && (c | 0x20) <= 0x66;
  static bool _isIdStart(int c) => (c | 0x20) >= 0x61 && (c | 0x20) <= 0x7A || c == 0x5F || c == 0x24;
  static bool _isIdPart(int c) => _isIdStart(c) || _isDigit(c);
}

// Counted lines: a line counts when a token (code or string text) touches it; blank and comment-only lines do not.
class Lines {
  Lines(List<Tok> toks, int count) : _sum = List<int>.filled(count + 1, 0) {
    final code = List<bool>.filled(count + 1, false);
    for (final t in toks) {
      for (var l = t.line; l <= t.endLine; l++) {
        code[l] = true;
      }
    }
    for (var l = 1; l <= count; l++) {
      _sum[l] = _sum[l - 1] + (code[l] ? 1 : 0);
    }
  }

  final List<int> _sum;
  int get total => _sum.last;
  int between(int first, int last) => _sum[last] - _sum[first - 1];
}

// ---------------------------------------------------------------------------------------------------------- parser

class Fn {
  Fn(this.name, this.line, this.endLine, this.returnType, {required this.isOverride, required this.topLevel});
  final String name;
  final int line;
  final int endLine;
  final String returnType;
  final bool isOverride;
  final bool topLevel;
}

class Directive {
  Directive(this.uri, this.line);
  final String uri;
  final int line;
}

enum _Kind { type, fn, other }

// Finds the declarations that matter here: functions, methods, getters and constructors with a body (top level and
// in classes, mixins, enums and extensions), class names, and import or export directives. Function bodies are
// skipped whole: local functions and closures count as lines of the function around them.
class Parser {
  Parser(this.t);
  final List<Tok> t;
  final fns = <Fn>[];
  final classes = <String>[];
  final directives = <Directive>[];

  static const _typeMods = {'abstract', 'sealed', 'base', 'interface', 'final', 'mixin'};
  static final _notNames = 'static final const external factory covariant late var abstract required Function new return if for while switch catch assert super this'
      .split(' ')
      .toSet();
  static const _mods = {'static', 'external', 'abstract', 'get', 'set', 'factory', 'const'};
  static const _beforeLiteral = {'=', ',', ':', '(', '[', '=>', '??', '||', '&&', '!', '...', '...?'};

  void run() {
    for (var i = 0; i < t.length; i++) {
      i = _decls(i, top: true); // a stray '}' at the top level ends one pass; skip it and go on
    }
  }

  // Reads declarations from [i] to the '}' that closes this level (the end, at the top level); returns its index.
  int _decls(int i, {required bool top}) {
    var head = i;
    var depth = 0;
    for (; i < t.length; i++) {
      final x = t[i];
      if (x.kind != K.punct) continue;
      switch (x.text) {
        case '(' || '[':
          depth++;
        case ')' || ']':
          if (depth > 0) depth--;
        case '}':
          return i;
        case ';' when depth == 0:
          if (top) _directive(head, i);
          head = i + 1;
        case '{' when depth > 0 || _literalBrace(i):
          i = _close(i, '{', '}');
        case '{':
          final kind = _classify(head, i);
          if (kind == _Kind.type) {
            if (top) _addClass(head, i);
            i = _decls(i + 1, top: false);
            head = i + 1;
          } else if (kind == _Kind.fn) {
            final end = _close(i, '{', '}');
            _addFn(head, i, end, top);
            i = end;
            head = i + 1;
          } else {
            i = _close(i, '{', '}'); // a literal in a field's initializer: the field goes on to its ';'
          }
        case '=>' when depth == 0 && _classify(head, i) == _Kind.fn:
          final end = _arrowEnd(i);
          _addFn(head, i, end, top);
          i = end;
          head = i + 1;
      }
    }
    return i;
  }

  int _close(int i, String open, String close) {
    var depth = 0;
    for (var j = i; j < t.length; j++) {
      if (t[j].kind != K.punct) continue;
      if (t[j].text == open) {
        depth++;
      } else if (t[j].text == close && --depth == 0) {
        return j;
      }
    }
    return t.length - 1;
  }

  // The ';' that ends an arrow body (or the token before a '}' that closes the class first).
  int _arrowEnd(int i) {
    var depth = 0;
    for (var j = i + 1; j < t.length; j++) {
      if (t[j].kind != K.punct) continue;
      switch (t[j].text) {
        case '(' || '[' || '{':
          depth++;
        case ')' || ']' || '}':
          if (depth == 0) return j - 1;
          depth--;
        case ';' when depth == 0:
          return j;
      }
    }
    return t.length - 1;
  }

  // A '{' right after '=', ',', '(' or an operator opens a map, a set or a closure, never a body.
  bool _literalBrace(int i) {
    if (i == 0) return false;
    final p = t[i - 1];
    return p.isId('const') || p.kind == K.punct && _beforeLiteral.contains(p.text);
  }

  _Kind _classify(int head, int end) {
    final s = _skipAnnotations(head, end);
    if (s >= end) return _Kind.other;
    var j = s;
    var mixin = false;
    while (j < end && t[j].kind == K.ident && _typeMods.contains(t[j].text)) {
      mixin = mixin || t[j].text == 'mixin';
      j++;
    }
    if (j < end && t[j].kind == K.ident) {
      final w = t[j].text;
      if (w == 'class' || w == 'enum' || mixin) return _Kind.type;
      if (w == 'extension' && j + 1 < end && t[j + 1].kind == K.ident) return _Kind.type;
    }
    for (var k = s; k < end; k++) {
      if (t[k].isId('operator')) return _Kind.fn;
    }
    return _paramList(s, end) >= 0 || _isGetter(s, end) ? _Kind.fn : _Kind.other;
  }

  // The '(' of the parameter list, or -1. A '=' before it means a field whose initializer holds the brace or arrow.
  int _paramList(int s, int end) {
    var angle = 0;
    for (var k = s; k < end; k++) {
      if (t[k].kind != K.punct) continue;
      switch (t[k].text) {
        case '<':
          angle++;
        case '>':
          if (angle > 0) angle--;
        case '=' || '??=':
          return -1;
        case '(' when angle == 0:
          if (_nameBefore(k, s) >= 0) return k;
          k = _close(k, '(', ')'); // a record type or a function type
      }
    }
    return -1;
  }

  // The name before the '(' at [k]: `name(` or `name<T>(`; -1 when the paren does not follow a name.
  int _nameBefore(int k, int s) {
    var j = k - 1;
    if (j >= s && t[j].isP('>')) {
      var angle = 0;
      for (; j >= s; j--) {
        if (t[j].isP('>')) angle++;
        if (t[j].isP('<') && --angle == 0) break;
      }
      j--;
    }
    return j >= s && t[j].kind == K.ident && !_notNames.contains(t[j].text) ? j : -1;
  }

  // The index after the last header token, without a trailing `async`, `async*` or `sync*`.
  int _headerEnd(int s, int end) {
    var e = end;
    if (e - 1 > s && t[e - 1].isP('*')) e--;
    if (e - 1 > s && (t[e - 1].isId('async') || t[e - 1].isId('sync'))) e--;
    return e;
  }

  bool _isGetter(int s, int end) {
    final e = _headerEnd(s, end);
    return e - 2 >= s && t[e - 2].isId('get') && t[e - 1].kind == K.ident;
  }

  int _skipAnnotations(int k, int end) {
    while (k < end && t[k].isP('@')) {
      k++;
      if (k < end && t[k].kind == K.ident) k++;
      while (k + 1 < end && t[k].isP('.') && t[k + 1].kind == K.ident) {
        k += 2;
      }
      if (k < end && t[k].isP('(')) k = _close(k, '(', ')') + 1;
    }
    return k;
  }

  void _addFn(int head, int body, int end, bool top) {
    final s = _skipAnnotations(head, body);
    if (s >= body) return;
    var isOverride = false;
    for (var k = head; k < s; k++) {
      isOverride = isOverride || t[k].isId('override');
    }
    var at = -1;
    for (var k = s; k < body && at < 0; k++) {
      if (t[k].isId('operator')) at = k;
    }
    if (at < 0) {
      final p = _paramList(s, body);
      at = p >= 0 ? _nameBefore(p, s) : _headerEnd(s, body) - 1; // no parameter list: a getter, `get name`
    }
    if (at < s) return;
    final type = [
      for (var k = s; k < at; k++)
        if (!_mods.contains(t[k].text)) t[k].text,
    ].join();
    fns.add(Fn(t[at].text, t[s].line, t[end].line, type, isOverride: isOverride, topLevel: top));
  }

  void _addClass(int head, int brace) {
    for (var k = head; k + 1 < brace; k++) {
      if (t[k].isId('class') && t[k + 1].kind == K.ident) classes.add(t[k + 1].text);
    }
  }

  void _directive(int head, int end) {
    final s = _skipAnnotations(head, end);
    if (s >= end || !(t[s].isId('import') || t[s].isId('export'))) return;
    for (var k = s + 1; k < end; k++) {
      if (t[k].kind == K.str) directives.add(Directive(t[k].value, t[s].line));
    }
  }
}

// ----------------------------------------------------------------------------------------------------------- rules

class Finding {
  Finding(this.path, this.line, this.rule, this.message, {required this.warning});
  final String path;
  final int line;
  final String rule;
  final String message;
  final bool warning;
}

class Checker {
  Checker(this.cfg, this.pkg, {required this.filesMode});
  final Config cfg;
  final String? pkg; // the app's package name, to resolve package: imports of its own files
  final bool filesMode;
  final findings = <Finding>[];
  final checkedExceptions = <String>{};
  final _folders = <String, (String, List<String>)>{};
  // Counted lines (the F1 count) of the checked files, for the test budget (F17).
  var testLines = 0;
  var libLines = 0;

  static final _letter = RegExp(r'\p{L}', unicode: true);
  static final _snake = RegExp(r'^[a-z][a-z0-9_]*\.dart$');
  static final _widgetType = RegExp(r'^(?:(?:List|Iterable)<)?[A-Za-z]*Widget\??(?:>\??)?$');
  // An icon family's class: Icons, CupertinoIcons, LucideIcons, LucideIcons500... (AppIcons is the app's own list).
  static final _iconFamily = RegExp(r'^(?!AppIcons$)(?:[A-Z][A-Za-z]*)?Icons\d*$');
  static const _textArgs = {'hintText', 'labelText', 'tooltip', 'semanticsLabel'};

  void add(String path, int line, String rule, String message, {bool warning = false}) {
    if (!cfg.isOn(rule)) return;
    findings.add(Finding(path, line, rule, message, warning: warning && !filesMode));
  }

  void check(String rel, String src) {
    final lexer = Lexer(src);
    final toks = lexer.run();
    final parser = Parser(toks)..run();
    final lines = Lines(toks, lexer.lineStarts.length);
    if (rel.startsWith('test/')) testLines += lines.total;
    if (rel.startsWith('lib/')) libLines += lines.total;
    _sizes(rel, lines, parser);
    _fileName(rel);
    if (!rel.startsWith('lib/')) return; // tests: sizes and names only
    _layout(rel, parser);
    _imports(rel, parser);
    _tokens(rel, toks, iconWidget: parser.classes.contains('AppIcon'));
    _helpers(rel, parser);
  }

  // Folder findings are reported once per folder, on its first file, with the number of files in it.
  void finish() {
    for (final (message, files) in _folders.values) {
      files.sort();
      add(files.first, 1, 'F2-folder', files.length == 1 ? message : '$message (${files.length} files)');
    }
    _folders.clear();
  }

  // F17: the tests stay smaller than the code they test. A full run only: a few files say nothing about the whole.
  void budget() {
    if (testLines <= libLines) return;
    add(
      'test/',
      1,
      'F17-budget',
      'test/ has $testLines counted lines, more than lib/ ($libLines): prune before you add (RULES F17)',
      warning: true,
    );
  }

  void _sizes(String rel, Lines lines, Parser p) {
    final test = rel.startsWith('test/');
    final limit = test ? cfg.testFileLines : cfg.fileLines;
    final over = <(int, String, String)>[];
    if (lines.total > limit) {
      over.add((1, 'F1-file', 'the file has ${lines.total} counted lines (limit $limit): split it by responsibility'));
    }
    for (final f in p.fns) {
      if (test && f.topLevel && f.name == 'main') continue; // a test file's main() only registers its tests
      final build = f.name == 'build';
      final max = build ? cfg.buildLines : cfg.functionLines;
      final n = lines.between(f.line, f.endLine);
      if (n <= max) continue;
      over.add(
        build
            ? (f.line, 'F1-build', 'build has $n counted lines (limit $max): extract widget classes')
            : (f.line, 'F1-function', '${f.name} has $n counted lines (limit $max): split it by responsibility'),
      );
    }
    final ex = cfg.sizeExceptions[rel];
    if (ex == null) {
      for (final (line, rule, message) in over) {
        add(rel, line, rule, message);
      }
      return;
    }
    checkedExceptions.add(rel);
    final cap = ex.maxLines;
    if (cap != null && lines.total > cap) {
      add(
        rel,
        1,
        'F1-file',
        'the file has ${lines.total} counted lines, over the $cap of its sizeExceptions entry: '
            'it may not grow; split it',
      );
    }
    if (over.isEmpty) {
      add(
        rel,
        1,
        'F1-exception',
        'the file is within the F1 limits now: remove its sizeExceptions entry',
        warning: true,
      );
    }
  }

  void _fileName(String rel) {
    final file = rel.split('/').last;
    if (_snake.hasMatch(file)) return;
    final want = file
        .replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
        .replaceAll(RegExp('[^A-Za-z0-9.]+'), '_')
        .toLowerCase();
    add(rel, 1, 'F2-name', 'file names are snake_case: $want');
  }

  void _layout(String rel, Parser p) {
    final parts = rel.split('/');
    if (parts.length == 2) {
      if (!cfg.libFiles.any((g) => g.hasMatch(parts[1]))) {
        add(rel, 1, 'F2-folder', 'a file directly in lib/: move it under lib/core/ or lib/features/<feature>/');
      }
      return;
    }
    switch (parts[1]) {
      case 'core':
        _coreLayout(rel, parts);
      case 'features':
        _featureLayout(rel, parts, p);
      default:
        _folder(
          'lib/${parts[1]}',
          rel,
          'lib/${parts[1]}/ is outside lib/core/ and lib/features/: move its files there',
        );
    }
  }

  void _folder(String folder, String rel, String message) {
    (_folders[folder] ??= (message, <String>[])).$2.add(rel);
  }

  static bool _inside(String dir, Iterable<String> folders) => folders.any((f) => dir == f || dir.startsWith('$f/'));

  // The first folder on the way to [dir] that is neither allowed nor on the way to an allowed folder.
  static String _badPrefix(String dir, List<String> allowed) {
    final segs = dir.split('/');
    for (var m = 1; m <= segs.length; m++) {
      final pre = segs.sublist(0, m).join('/');
      if (!_inside(pre, allowed) && !allowed.any((a) => a.startsWith('$pre/'))) return pre;
    }
    return dir;
  }

  void _coreLayout(String rel, List<String> parts) {
    final dir = parts.sublist(2, parts.length - 1).join('/');
    if (dir.isEmpty) {
      add(rel, 1, 'F2-folder', 'a file directly in lib/core/: move it into the core folder its kind says');
    } else if (!_inside(dir, cfg.coreFolders)) {
      final bad = _badPrefix(dir, cfg.coreFolders);
      _folder('lib/core/$bad', rel, 'lib/core/$bad/ is not a core folder (coreFolders in tool/kit/kit_config.json)');
    } else if (_inside(dir, ['config/injection-modules']) && !parts.last.endsWith('_module.dart')) {
      add(rel, 1, 'F2-suffix', 'files in core/config/injection-modules/ are <feature>_module.dart');
    }
  }

  void _featureLayout(String rel, List<String> parts, Parser p) {
    if (parts.length == 3) {
      add(rel, 1, 'F2-folder', 'a file directly in lib/features/: put it in its feature folder');
      return;
    }
    final feature = parts[2];
    final file = parts.last;
    final dir = parts.sublist(3, parts.length - 1).join('/');
    final allowed = [...cfg.featureFolders, 'presentation/${cfg.controllersDir}'];
    if (dir.isEmpty) {
      if (file != '${feature}_routes.dart') {
        add(
          rel,
          1,
          'F2-folder',
          'only ${feature}_routes.dart sits directly in the feature folder: move this file into a layer',
        );
      }
      return;
    }
    if (!_inside(dir, allowed)) {
      final bad = _badPrefix(dir, allowed);
      _folder(
        'lib/features/$feature/$bad',
        rel,
        'lib/features/$feature/$bad/ is not a feature folder (featureFolders in tool/kit/kit_config.json)',
      );
      return;
    }
    final suffixes = {
      'presentation/pages': '_page.dart',
      'presentation/${cfg.controllersDir}': '_controller.dart',
      'domain/repositories': '_repository.dart',
      'data/repositories': '_repository_impl.dart',
      'data/models': '_model.dart',
      'data/datasources': '_datasource.dart',
    };
    for (final MapEntry(key: folder, value: suffix) in suffixes.entries) {
      if (_inside(dir, [folder]) && !file.endsWith(suffix)) {
        add(rel, 1, 'F2-suffix', 'files in $folder/ end with $suffix');
      }
    }
    if (_inside(dir, ['domain/entities']) && (file.endsWith('_model.dart') || file.endsWith('_entity.dart'))) {
      add(rel, 1, 'F2-suffix', 'entity files have no suffix (models live in data/models/)');
    }
    if (_inside(dir, ['domain/usecases'])) {
      final want = file
          .substring(0, file.length - 5)
          .split('_')
          .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
          .join();
      if (!p.classes.contains(want)) {
        add(rel, 1, 'F2-name', 'a use case file holds the one class named after it: class $want');
      }
    }
  }

  // (feature, layer) of a lib/ path: layer is data, domain, presentation or null.
  static (String?, String?) _place(String path) {
    final parts = path.split('/');
    if (parts.length < 4 || parts[0] != 'lib' || parts[1] != 'features') return (null, null);
    final layer = parts.length > 4 && const {'data', 'domain', 'presentation'}.contains(parts[3]) ? parts[3] : null;
    return (parts[2], layer);
  }

  String? _resolve(String rel, String uri) {
    final own = pkg;
    if (uri.startsWith('package:')) {
      return own != null && uri.startsWith('package:$own/') ? 'lib/${uri.substring(own.length + 9)}' : null;
    }
    if (uri.contains(':')) return null; // dart: and any other scheme
    final segs = rel.split('/')..removeLast();
    for (final s in uri.split('/')) {
      if (s == '..') {
        if (segs.isNotEmpty) segs.removeLast();
      } else if (s != '.' && s.isNotEmpty) {
        segs.add(s);
      }
    }
    return segs.join('/');
  }

  static bool _platformImport(String uri) =>
      uri.startsWith('package:flutter/') ||
      uri.startsWith('package:material_ui/') || // Material and Cupertino now ship as their own packages
      uri.startsWith('package:cupertino_ui/') ||
      uri == 'dart:ui' ||
      uri.startsWith('package:dio/') ||
      uri.startsWith('package:supabase') ||
      uri.startsWith('package:gotrue/') ||
      uri.startsWith('package:postgrest/');

  // core/ and lib/ files may import any feature: they assemble the app (router, modules).
  void _imports(String rel, Parser p) {
    final (feature, layer) = _place(rel);
    if (feature == null) return;
    for (final d in p.directives) {
      if (layer == 'domain' && _platformImport(d.uri)) {
        add(rel, d.line, 'F2-import', 'domain/ imports ${d.uri}: domain is plain Dart (no Flutter, dio or Supabase)');
      }
      final target = _resolve(rel, d.uri);
      if (target == null) continue;
      final (toFeature, toLayer) = _place(target);
      if (toFeature == null) continue;
      if (toFeature != feature) {
        if (toLayer != 'domain') {
          add(
            rel,
            d.line,
            'F2-import',
            'imports $target: another feature is open only through its domain/ '
                '(or lift the shared piece to lib/core/)',
          );
        }
      } else if (layer == 'domain' && (toLayer == 'data' || toLayer == 'presentation')) {
        add(rel, d.line, 'F2-import', 'domain/ imports $target: domain never depends on data/ or presentation/');
      } else if (layer == 'presentation' && toLayer == 'data') {
        add(
          rel,
          d.line,
          'F2-import',
          'presentation/ imports $target: take repositories and use cases from the '
              "feature's module, never from data/",
        );
      } else if (layer == 'data' && toLayer == 'presentation') {
        add(rel, d.line, 'F2-import', 'data/ imports $target: data never depends on presentation/');
      }
    }
  }

  // iconWidget: the file declares the AppIcon widget, which draws the Icon of an AppIcons constant for every page.
  void _tokens(String rel, List<Tok> t, {required bool iconWidget}) {
    final theme = rel.startsWith('lib/core/theme/');
    final kit = theme || rel.startsWith('lib/core/common/widgets/');
    final l10n = rel.startsWith('lib/core/l10n/');
    bool p(int k, String s) => k < t.length && t[k].isP(s);
    bool id(int k) => k < t.length && t[k].kind == K.ident;
    bool text(int k) => k < t.length && t[k].kind == K.str && _letter.hasMatch(t[k].value);
    for (var k = 0; k < t.length; k++) {
      final x = t[k];
      if (x.kind != K.ident) continue;
      switch (x.text) {
        case 'Color' when !theme && p(k + 1, '(') && k + 2 < t.length && t[k + 2].text.toLowerCase().startsWith('0x'):
          add(rel, x.line, 'F8-color', 'Color(${t[k + 2].text}) outside lib/core/theme/: use a context.colors token');
        case 'Color'
            when !theme && p(k + 1, '.') && id(k + 2) && const {'fromARGB', 'fromRGBO', 'from'}.contains(t[k + 2].text):
          add(rel, x.line, 'F8-color', 'Color.${t[k + 2].text} outside lib/core/theme/: use a context.colors token');
        case 'Colors' when !theme && p(k + 1, '.') && id(k + 2) && t[k + 2].text != 'transparent':
          add(
            rel,
            x.line,
            'F8-color',
            'Colors.${t[k + 2].text} outside lib/core/theme/: use a context.colors token '
                '(add one to AppColors, in both themes)',
          );
        case 'Icon' when !kit && p(k + 1, '(') && id(k + 2) && _iconFamily.hasMatch(t[k + 2].text):
          final family = t[k + 2].text;
          final name = p(k + 3, '.') && id(k + 4) ? t[k + 4].text : '...';
          add(rel, x.line, 'F10-icon', 'Icon($family.$name) outside the widget kit: use AppIcon(AppIcons.<name>)');
        // The right family, but a bare Icon skips the size from AppIconSize and the colour from the tokens.
        case 'Icon' when !theme && !iconWidget && p(k + 1, '(') && id(k + 2) && t[k + 2].text == 'AppIcons':
          final name = p(k + 3, '.') && id(k + 4) ? t[k + 4].text : '...';
          add(
            rel,
            x.line,
            'F10-icon',
            'Icon(AppIcons.$name) skips AppIcon, which sets the size and the colour from tokens: '
                'use AppIcon(AppIcons.$name)',
          );
        case 'SvgPicture' when !kit && (p(k + 1, '.') || p(k + 1, '(')):
          add(rel, x.line, 'F10-icon', 'SvgPicture outside the widget kit: use AppIcon (icons) or AppImage (pictures)');
        case 'Text' when !l10n && p(k + 1, '(') && text(k + 2):
          add(
            rel,
            x.line,
            'F11-text',
            'literal text ${_shown(t[k + 2])} in Text(): put it in the ARB catalogs and '
                'read it with context.l10n',
            warning: true,
          );
        case final name
            when !l10n &&
                _textArgs.contains(name) &&
                k > 0 &&
                (p(k - 1, '(') || p(k - 1, ',')) &&
                p(k + 1, ':') &&
                text(k + 2):
          add(
            rel,
            x.line,
            'F11-text',
            'literal text ${_shown(t[k + 2])} in $name: put it in the ARB catalogs and '
                'read it with context.l10n',
            warning: true,
          );
      }
    }
  }

  static String _shown(Tok s) {
    final v = s.value.replaceAll('\n', r'\n');
    return '"${v.length > 40 ? '${v.substring(0, 37)}...' : v}"';
  }

  void _helpers(String rel, Parser p) {
    for (final f in p.fns) {
      if (f.isOverride || f.name == 'build' || !_widgetType.hasMatch(f.returnType)) continue;
      add(
        rel,
        f.line,
        'F12-helper',
        '${f.name} returns a widget: make it a widget class (const, tested and rebuilt '
            'alone)',
        warning: true,
      );
    }
  }
}

// ------------------------------------------------------------------------------------------------------------- run

String _norm(String path) {
  final p = File(path).absolute.uri.normalizePath().toFilePath();
  return p.length > 1 && p.endsWith(Platform.pathSeparator) ? p.substring(0, p.length - 1) : p;
}

String _relTo(String base, String path) => path.substring(base.length + 1).replaceAll(r'\', '/');

List<String> _walk(String base) {
  final out = <String>[];
  for (final sub in ['lib', 'test']) {
    final dir = Directory('$base/$sub');
    if (!dir.existsSync()) continue;
    for (final e in dir.listSync(recursive: true, followLinks: false)) {
      final rel = _relTo(base, e.path);
      if (e is File && rel.endsWith('.dart') && !rel.split('/').any((s) => s.startsWith('.'))) out.add(rel);
    }
  }
  return out..sort();
}

// --files: relative paths are read from the working folder first, then from the root. Deleted files, other file
// types and files outside lib/ and test/ are skipped, so `--files $(git diff --name-only)` just works.
(List<String>, int) _given(String base, List<String> files) {
  final out = <String>{};
  var skipped = 0;
  for (final f in files) {
    String? rel;
    for (final c in [f, if (!File(f).isAbsolute) '$base/$f']) {
      final abs = _norm(c);
      if (rel == null && File(abs).existsSync() && abs.startsWith('$base${Platform.pathSeparator}')) {
        rel = _relTo(base, abs);
      }
    }
    if (rel != null && rel.endsWith('.dart') && (rel.startsWith('lib/') || rel.startsWith('test/'))) {
      out.add(rel);
    } else {
      skipped++;
    }
  }
  return (out.toList()..sort(), skipped);
}

String? _packageName(String base) {
  final pubspec = File('$base/pubspec.yaml');
  if (!pubspec.existsSync()) return null;
  final m = RegExp(r'''^name:\s*['"]?([A-Za-z0-9_]+)''', multiLine: true).firstMatch(pubspec.readAsStringSync());
  return m?.group(1);
}

int run(Args args) {
  final base = _norm(args.root);
  if (!Directory(base).existsSync()) throw UsageError('no folder at ${args.root}');
  final cfg = loadConfig(base, args.config);
  final given = args.files;
  final checker = Checker(cfg, _packageName(base), filesMode: given != null);
  final (all, skipped) = given == null ? (_walk(base), 0) : _given(base, given);
  final files = [
    for (final rel in all)
      if (!cfg.generated.any((g) => g.hasMatch(rel))) rel,
  ];
  for (final rel in files) {
    final bytes = File('$base/$rel').readAsBytesSync();
    checker.check(rel, utf8.decode(bytes, allowMalformed: true));
  }
  checker.finish();
  if (given == null) {
    for (final path in cfg.sizeExceptions.keys) {
      if (!checker.checkedExceptions.contains(path) && !File('$base/$path').existsSync()) {
        checker.add(
          'tool/kit/kit_config.json',
          1,
          'F1-exception',
          'sizeExceptions names $path, which does not exist: '
              'remove the entry',
          warning: true,
        );
      }
    }
    checker.budget();
  }
  final budget = given == null ? (test: checker.testLines, lib: checker.libLines) : null;
  return report(checker.findings, files.length, skipped, args, budget: budget);
}

// budget: the counted lines of test/ and lib/, in a full run only.
int report(List<Finding> found, int files, int skipped, Args args, {({int test, int lib})? budget}) {
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
  // F17-budget is advice for the next change: it never fails a run, even with --strict.
  final strictFails = found.any((f) => f.warning && f.rule != 'F17-budget');
  final passed = errors == 0 && !(args.strict && strictFails);
  final cap = args.maxLines == 0 ? found.length : args.maxLines;
  final shown = found.take(cap).toList();
  final more = found.length - shown.length;
  if (args.json) {
    stdout.writeln(
      jsonEncode({
        'tool': 'check_structure',
        'passed': passed,
        'files': files,
        'skipped': skipped,
        'errors': errors,
        'warnings': warnings,
        'counts': counts,
        if (budget != null) 'budget': {'test': budget.test, 'lib': budget.lib},
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
  if (more > 0) stdout.writeln('... $more more findings not shown (--max-lines 0 shows all; --files narrows the run)');
  if (budget != null) stdout.writeln('budget: test/ ${budget.test} counted lines, lib/ ${budget.lib}');
  final byRule = counts.isEmpty ? '' : ' [${counts.entries.map((e) => '${e.key} ${e.value}').join(', ')}]';
  final skip = skipped > 0 ? ' ($skipped skipped: not Dart, missing, or outside lib/ and test/)' : '';
  final strict = !passed && errors == 0 ? ' (--strict: warnings fail the run)' : '';
  stdout.writeln(
    'check_structure: ${passed ? 'passed' : 'FAILED'}$strict, ${_n(errors, 'error')} and '
    '${_n(warnings, 'warning')} in ${_n(files, 'file')}$skip$byRule',
  );
  return passed ? 0 : 1;
}

String _n(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
