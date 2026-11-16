/// One page of a list the server paginates (F6).
///
/// "Is there more" comes from the server's cursor, never from counting what the app already holds: a page shorter
/// than asked can still be followed by more, when the server filtered rows out.
class Paged<T> {
  const Paged({required this.items, this.nextCursor});

  final List<T> items;

  /// The cursor to send for the next page; null on the last page.
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
