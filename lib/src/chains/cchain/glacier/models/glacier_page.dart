// ---- GlacierPage ----

/// A paginated response from the Glacier Data API.
///
/// Contains the list of items and an optional [nextPageToken] for
/// fetching the next page.
///
/// Source: build.avax.network/docs/api-reference/data-api/usage#pagination
class GlacierPage<T> {
  /// Creates a [GlacierPage] with the given items and optional page token.
  const GlacierPage({
    required this.items,
    this.nextPageToken,
  });

  /// The items on this page.
  final List<T> items;

  /// Token to fetch the next page, or null if this is the last page.
  ///
  /// Pass this to the next API call as the `pageToken` parameter.
  /// Tokens expire after 24 hours.
  final String? nextPageToken;

  /// Returns true if there is a next page available.
  bool get hasNextPage => nextPageToken != null;

  @override
  String toString() => 'GlacierPage(items: ${items.length}, '
      'hasNextPage: $hasNextPage)';
}
