enum CatalogEntryKind {
  creature,
  special,
  defense;

  static CatalogEntryKind fromJson(Object? value) =>
      switch (value?.toString()) {
        'defense' => defense,
        'special' => special,
        _ => creature,
      };
}
