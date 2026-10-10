class BulkImportResult {
  final int totalRows;
  final int importedCount;
  final int updatedCount;
  final int skippedCount;
  final List<String> errors;

  BulkImportResult({
    required this.totalRows,
    required this.importedCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.errors,
  });

  factory BulkImportResult.fromJson(Map<String, dynamic> json) {
    return BulkImportResult(
      totalRows: json['total_rows'] is int
          ? json['total_rows'] as int
          : int.tryParse(json['total_rows']?.toString() ?? '0') ?? 0,
      importedCount: json['imported_count'] is int
          ? json['imported_count'] as int
          : int.tryParse(json['imported_count']?.toString() ?? '0') ?? 0,
      updatedCount: json['updated_count'] is int
          ? json['updated_count'] as int
          : int.tryParse(json['updated_count']?.toString() ?? '0') ?? 0,
      skippedCount: json['skipped_count'] is int
          ? json['skipped_count'] as int
          : int.tryParse(json['skipped_count']?.toString() ?? '0') ?? 0,
      errors: (json['errors'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
