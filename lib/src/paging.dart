/// One fetched slice. [nextCursor] is only used by [CursorPager].
class ItemBatch<T> {
  const ItemBatch({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<T> items;
  final bool hasMore;
  final String? nextCursor;
}

sealed class PagingState<T> {
  const PagingState();
}

final class PagingLoading<T> extends PagingState<T> {
  const PagingLoading();
}

final class PagingFailure<T> extends PagingState<T> {
  const PagingFailure(this.error);

  final Object error;
}

final class PagingReady<T> extends PagingState<T> {
  const PagingReady({
    required this.items,
    required this.hasMore,
    required this.loadingMore,
    this.loadMoreError,
  });

  final List<T> items;
  final bool hasMore;
  final bool loadingMore;
  final Object? loadMoreError;

  bool get isEmpty => items.isEmpty;

  PagingReady<T> copyWith({
    List<T>? items,
    bool? hasMore,
    bool? loadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return PagingReady(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreError: clearLoadMoreError
          ? null
          : loadMoreError ?? this.loadMoreError,
    );
  }
}

/// Page numbers start at 1. [idOf] must be stable for an item.
class PagePager<T> {
  PagePager({required this.pageSize, required this.fetch, required this.idOf})
    : assert(pageSize > 0);

  final int pageSize;
  final Future<ItemBatch<T>> Function(int page, int pageSize) fetch;
  final Object Function(T item) idOf;

  PagingState<T> state = const PagingLoading();
  int _page = 0;
  int _generation = 0;
  var _loadMoreInFlight = false;

  Future<void> refresh() => _loadFirst();

  Future<void> retry() => _loadFirst();

  Future<void> loadMore() async {
    final current = state;
    if (current is! PagingReady<T> ||
        !current.hasMore ||
        current.loadingMore ||
        _loadMoreInFlight) {
      return;
    }
    final generation = _generation;
    _loadMoreInFlight = true;
    state = current.copyWith(loadingMore: true, clearLoadMoreError: true);
    try {
      final batch = await fetch(_page + 1, pageSize);
      if (generation != _generation) {
        return;
      }
      _page += 1;
      state = PagingReady(
        items: _merge(current.items, batch.items),
        hasMore: batch.hasMore,
        loadingMore: false,
      );
    } catch (error) {
      if (generation != _generation) {
        return;
      }
      state = current.copyWith(loadingMore: false, loadMoreError: error);
    } finally {
      if (generation == _generation) {
        _loadMoreInFlight = false;
      }
    }
  }

  Future<void> _loadFirst() async {
    final generation = ++_generation;
    _loadMoreInFlight = false;
    state = const PagingLoading();
    try {
      final batch = await fetch(1, pageSize);
      if (generation != _generation) {
        return;
      }
      _page = 1;
      state = PagingReady(
        items: _merge(const [], batch.items),
        hasMore: batch.hasMore,
        loadingMore: false,
      );
    } catch (error) {
      if (generation != _generation) {
        return;
      }
      state = PagingFailure(error);
    }
  }

  List<T> _merge(List<T> existing, List<T> incoming) {
    final seen = <Object>{for (final item in existing) idOf(item)};
    final merged = [...existing];
    for (final item in incoming) {
      final id = idOf(item);
      if (seen.add(id)) {
        merged.add(item);
      }
    }
    return merged;
  }
}

/// [fetch] receives the cursor from the previous batch. The first call uses null.
class CursorPager<T> {
  CursorPager({required this.limit, required this.fetch, required this.idOf})
    : assert(limit > 0);

  final int limit;
  final Future<ItemBatch<T>> Function(String? cursor, int limit) fetch;
  final Object Function(T item) idOf;

  PagingState<T> state = const PagingLoading();
  String? _cursor;
  int _generation = 0;
  var _loadMoreInFlight = false;

  Future<void> refresh() => _loadFirst();

  Future<void> retry() => _loadFirst();

  Future<void> loadMore() async {
    final current = state;
    if (current is! PagingReady<T> ||
        !current.hasMore ||
        current.loadingMore ||
        _loadMoreInFlight) {
      return;
    }
    final generation = _generation;
    _loadMoreInFlight = true;
    state = current.copyWith(loadingMore: true, clearLoadMoreError: true);
    try {
      final batch = await fetch(_cursor, limit);
      if (generation != _generation) {
        return;
      }
      _cursor = batch.nextCursor;
      state = PagingReady(
        items: _merge(current.items, batch.items),
        hasMore: batch.nextCursor != null,
        loadingMore: false,
      );
    } catch (error) {
      if (generation != _generation) {
        return;
      }
      state = current.copyWith(loadingMore: false, loadMoreError: error);
    } finally {
      if (generation == _generation) {
        _loadMoreInFlight = false;
      }
    }
  }

  Future<void> _loadFirst() async {
    final generation = ++_generation;
    _loadMoreInFlight = false;
    _cursor = null;
    state = const PagingLoading();
    try {
      final batch = await fetch(null, limit);
      if (generation != _generation) {
        return;
      }
      _cursor = batch.nextCursor;
      state = PagingReady(
        items: _merge(const [], batch.items),
        hasMore: batch.nextCursor != null,
        loadingMore: false,
      );
    } catch (error) {
      if (generation != _generation) {
        return;
      }
      state = PagingFailure(error);
    }
  }

  List<T> _merge(List<T> existing, List<T> incoming) {
    final seen = <Object>{for (final item in existing) idOf(item)};
    final merged = [...existing];
    for (final item in incoming) {
      final id = idOf(item);
      if (seen.add(id)) {
        merged.add(item);
      }
    }
    return merged;
  }
}
