class HerbScan {
  final String name;
  final String latinName;
  final int confidence; // 0-100
  final DateTime scannedAt;

  HerbScan({
    required this.name,
    required this.latinName,
    required this.confidence,
    DateTime? scannedAt,
  }) : scannedAt = scannedAt ?? DateTime.now();
}