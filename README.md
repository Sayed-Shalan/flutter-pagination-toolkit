# flutter-pagination-toolkit

Controllers for page-based and cursor-based lists. The widgets stay in the app. This package only tracks items, the next request, and whether a request is already running.

`flutter-architecture-blueprint` keeps a smaller page loader inside its booking view model. This package is the reusable version: cursors, stable ids, and a generation counter so a slow response cannot overwrite a newer refresh.

Package name: `pagination_toolkit`. Version 0.1.0 is not published.

## Behavior

- Call `refresh()` before reading items. Construction does not fetch.
- `loadMore()` does nothing while a load-more is in flight, or when `hasMore` is false.
- Page mode uses `ItemBatch.hasMore`. Cursor mode uses `nextCursor`: null means there is no next page.
- `idOf` decides identity. The first item with an id is kept.
- `refresh` and `retry` increment a generation. Responses from an older generation are dropped.

## Limitations

- No Flutter widgets. A list widget should read `state` and call `refresh` / `loadMore`.
- No automatic retry and no request cancellation of the underlying future. Stale results are ignored; the future still completes.
- The caller supplies `hasMore` for page mode. The controller does not infer it from item counts.

## Example

```bash
dart pub get
dart run example/main.dart
```

## Tests

```bash
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
```

## License

[MIT](LICENSE)
