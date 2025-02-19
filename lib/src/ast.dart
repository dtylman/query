import 'package:query/src/matcher.dart';

/// Base interface for queries.
abstract class Query {
  /// Returns a String-representation of this [Query].
  ///
  /// Implementation should aim to provide a format that can be parsed to the
  /// same form.
  ///
  /// [debug] is used to extend the format with additional characters, making
  /// testing unambiguous.
  @override
  String toString({bool debug = false});

  bool match(QueryMatcher matcher);
}

/// Text query to match [text].
///
/// [isExactMatch] is set when the [text] was inside quotes.
class TextQuery implements Query {
  final String text;
  final bool isExactMatch;
  TextQuery(this.text, {this.isExactMatch = false});

  @override
  String toString({bool debug = false}) =>
      _debug(debug, isExactMatch ? '"$text"' : text);

  @override
  bool match(matcher) {
    return matcher.matchField(QueryMatcher.AnyField, OP_EQUAL, this);
  }
}

/// Phrase query to match "[text]" for a list of words inside quotes.
class PhraseQuery extends TextQuery {
  final List<TextQuery> children;
  PhraseQuery(String phrase, this.children) : super(phrase, isExactMatch: true);

  @override
  String toString({bool debug = false}) =>
      '"' + children.map((n) => n.toString(debug: debug)).join(' ') + '"';
}

/// Scopes [child] [Query] to be applied only on the [field].
class FieldScope implements Query {
  final String field;
  final Query child;

  FieldScope(this.field, this.child);

  @override
  String toString({bool debug = false}) =>
      '$field:${child.toString(debug: debug)}';

  @override
  bool match(QueryMatcher matcher) {
    QueryMatcher? fm = matcher.getFieldMatcher(field);
    if (fm == null) {
      return false;
    }
    return child.match(fm);
  }
}

/// Describes a [field] [operator] [text] tripled (e.g. year < 2000).
class FieldCompareQuery implements Query {
  final String field;
  final String operator;
  final TextQuery text;

  FieldCompareQuery(this.field, this.operator, this.text);

  @override
  String toString({bool debug = false}) =>
      _debug(debug, '$field$operator$text');

  @override
  bool match(QueryMatcher matcher) {
    return matcher.matchField(field, operator, text);
  }
}

/// Describes a range query between [start] and [end].
class RangeQuery implements Query {
  final TextQuery start;
  final bool startInclusive;
  final TextQuery end;
  final bool endInclusive;

  RangeQuery(this.start, this.end,
      {this.startInclusive = true, this.endInclusive = true});

  @override
  String toString({bool debug = false}) => _debug(
      debug,
      '${_sp(true, startInclusive)}${start.toString(debug: debug)} TO '
      '${end.toString(debug: debug)}${_sp(false, endInclusive)}');

  String _sp(bool start, bool inclusive) {
    return start ? (inclusive ? '[' : ']') : (inclusive ? ']' : '[');
  }

  @override
  bool match(QueryMatcher matcher) {
    return matcher.matchRange(start, startInclusive, end, endInclusive);
  }
}

/// Negates the [child] query. (bool NOT)
class NotQuery implements Query {
  final Query child;
  NotQuery(this.child);

  @override
  String toString({bool debug = false}) => '-${child.toString(debug: debug)}';

  @override
  bool match(QueryMatcher matcher) {
    return !child.match(matcher);
  }
}

/// Groups the [child] query to override implicit precedence.
class GroupQuery implements Query {
  final Query child;
  GroupQuery(this.child);

  @override
  String toString({bool debug = false}) => '(${child.toString(debug: debug)})';

  @override
  bool match(QueryMatcher matcher) {
    return child.match(matcher);
  }
}

/// Bool AND composition of [children] queries.
class AndQuery implements Query {
  final List<Query> children;

  AndQuery(this.children);

  @override
  String toString({bool debug = false}) =>
      '(' + children.map((n) => n.toString(debug: debug)).join(' ') + ')';

  @override
  bool match(QueryMatcher matcher) {
    for (Query child in children) {
      if (!child.match(matcher)) {
        return false;
      }
    }
    return true;
  }
}

/// Bool OR composition of [children] queries.
class OrQuery implements Query {
  final List<Query> children;

  OrQuery(this.children);

  @override
  String toString({bool debug = false}) =>
      '(' + children.map((n) => n.toString(debug: debug)).join(' OR ') + ')';

  @override
  bool match(QueryMatcher matcher) {
    for (Query child in children) {
      if (child.match(matcher)) {
        return true;
      }
    }
    return false;
  }
}

String _debug(bool debug, String expr) => debug ? '<$expr>' : expr;
