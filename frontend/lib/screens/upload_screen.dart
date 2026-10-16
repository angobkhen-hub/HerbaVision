import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/herb_scan.dart';
import '../services/herb_recognition_service.dart';
import '../theme/app_colors.dart';

/// Lets the user upload a photo of a leaf and shows the identification result.
///
/// Photo picking uses `image_picker`. The photo is kept as raw bytes (not a
/// dart:io File) so the same code works on web and mobile. The identification
/// call lives in [HerbRecognitionService], which sends the photo to the
/// backend's /recognize endpoint.
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _picker = ImagePicker();
  final _recognitionService = HerbRecognitionService();

  Uint8List? _imageBytes;
  String _filename = 'leaf.jpg';
  bool _loading = false;
  String? _error;

  Future<void> _showSourceSheet() async {
    // Desktop browsers have no camera option in image_picker, so go straight
    // to the file chooser on the web.
    if (kIsWeb) {
      await _pickImage(ImageSource.gallery);
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadius)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.photo_camera_outlined,
                    color: AppColors.textAccent),
                title: const Text('Take a photo'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined,
                    color: AppColors.textAccent),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (source == null) return;
    await _pickImage(source);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return; // user cancelled

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
        _filename = picked.name.isNotEmpty ? picked.name : 'leaf.jpg';
        _error = null;
      });

      await _identify();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open camera/gallery. Please try again.');
    }
  }

  Future<void> _identify() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final HerbScan scan = await _recognitionService.identifyLeaf(
        _imageBytes!,
        filename: _filename,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).pop(scan);
    } on PlantNotRecognizedException {
      if (!mounted) return;
      setState(() => _loading = false);
      await _showNotFoundDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _showNotFoundDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Plant not found'),
        content: const Text(
          "We couldn't identify this plant. It may not be in our database "
          'yet \u2014 more plants are coming soon.\n\n'
          'If it should be one of our herbs, try a clearer, close-up photo '
          'of a single leaf.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Upload a leaf photo')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(kRadius),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      if (_imageBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(kRadius - 4),
                          child: Image.memory(
                            _imageBytes!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.bgAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.image_outlined,
                              size: 32, color: AppColors.textAccent),
                        ),
                      const SizedBox(height: 16),
                      if (_loading) ...[
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: AppColors.textAccent, strokeWidth: 3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Identifying…',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                        ),
                      ] else ...[
                        Text(
                          _imageBytes != null ? 'Photo selected' : 'Upload a photo',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose a clear photo of the leaf.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.danger),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!_loading)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showSourceSheet,
                      icon: const Icon(Icons.upload_outlined, size: 18),
                      label: Text(_imageBytes != null
                          ? 'Try another photo'
                          : 'Choose photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: AppColors.onBrand,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kRadius),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}