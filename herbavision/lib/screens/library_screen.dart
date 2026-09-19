import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class HerbInfo {
  final String name;
  final String latinName;
  final String category;
  final String description;

  const HerbInfo({
    required this.name,
    required this.latinName,
    required this.category,
    required this.description,
  });
}

/// A browsable reference library of herbs the system can recognize.
/// Swap the sample list for data from your backend/database.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  final List<HerbInfo> _herbs = const [
    HerbInfo(
      name: 'Turmeric',
      latinName: 'Curcuma longa',
      category: 'Rhizome',
      description: 'Used for its anti-inflammatory properties and as a spice.',
    ),
    HerbInfo(
      name: 'Peppermint',
      latinName: 'Mentha piperita',
      category: 'Leaf',
      description: 'Commonly used to relieve digestive discomfort.',
    ),
    HerbInfo(
      name: 'Ginger',
      latinName: 'Zingiber officinale',
      category: 'Rhizome',
      description: 'Used to ease nausea and support digestion.',
    ),
    HerbInfo(
      name: 'Lemongrass',
      latinName: 'Cymbopogon citratus',
      category: 'Leaf',
      description: 'Often brewed as tea; known for a citrus aroma.',
    ),
    HerbInfo(
      name: 'Basil',
      latinName: 'Ocimum basilicum',
      category: 'Leaf',
      description: 'A culinary herb also used for its calming aroma.',
    ),
    HerbInfo(
      name: 'Aloe Vera',
      latinName: 'Aloe barbadensis miller',
      category: 'Succulent',
      description: 'Gel is commonly applied to soothe skin irritation.',
    ),
  ];

  List<HerbInfo> get _filtered {
    if (_query.isEmpty) return _herbs;
    final q = _query.toLowerCase();
    return _herbs
        .where((h) =>
            h.name.toLowerCase().contains(q) ||
            h.latinName.toLowerCase().contains(q))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Herb Library')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search herbs…',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kRadius),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kRadius),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text('No herbs found',
                          style: TextStyle(color: AppColors.textMuted)),
                    )
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final herb = _filtered[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.bgAccent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.eco,
                                    color: AppColors.textAccent, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(herb.name,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.bgAccent,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(herb.category,
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.textAccent)),
                                        ),
                                      ],
                                    ),
                                    Text(herb.latinName,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                            color: AppColors.textMuted)),
                                    const SizedBox(height: 6),
                                    Text(herb.description,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}