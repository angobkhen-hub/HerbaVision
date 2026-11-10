import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/herb_scan.dart';
import '../services/herb_recognition_service.dart';
import '../theme/app_colors.dart';

/// What the upload screen returns: the scan result plus the photo the user sent.
class UploadResult {
  final HerbScan scan;
  final Uint8List imageBytes;
  const UploadResult(this.scan, this.imageBytes);
}

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
  bool _notFound = false; // true after the backend says "plant not found"
  String? _guessName; // best guess from the backend, if it sent one
  int? _guessConfidence;
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
        _notFound = false;
        _guessName = null;
        _guessConfidence = null;
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
      _notFound = false;
      _guessName = null;
      _guessConfidence = null;
      _error = null;
    });

    try {
      final HerbScan scan = await _recognitionService.identifyLeaf(
        _imageBytes!,
        filename: _filename,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      // Send back the photo together with the result so the dashboard can
      // show it in the result dialog.
      Navigator.of(context).pop(UploadResult(scan, _imageBytes!));
    } on PlantNotRecognizedException catch (e) {
      if (!mounted) return;
      // No popup: the card on this screen switches to the "not found" view.
      setState(() {
        _loading = false;
        _notFound = true;
        _guessName = e.guessName;
        _guessConfidence = e.guessConfidence;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget _tip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notFoundContent() {
    final amber = Colors.amber.shade700;
    final guess = _guessName;
    final guessText = guess == null
        ? null
        : (_guessConfidence != null
            ? 'Closest guess: $guess ($_guessConfidence%)'
            : 'Closest guess: $guess');

    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.search_off_rounded, size: 36, color: amber),
        ),
        const SizedBox(height: 16),
        Text(
          "We couldn't confirm this plant",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'It may not be in our database yet, or the photo may be unclear. '
          'More plants are coming soon.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: AppColors.textMuted),
        ),
        if (guessText != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              guessText,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.bgAccent,
            borderRadius: BorderRadius.circular(kRadius - 4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tips for a better photo',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              _tip(Icons.eco_outlined, 'Show one leaf, filling most of the photo.'),
              _tip(Icons.wb_sunny_outlined, 'Use good, even daylight. Avoid shadows.'),
              _tip(Icons.crop_free, 'Keep the background plain and uncluttered.'),
              _tip(Icons.center_focus_strong_outlined,
                  'Hold the camera steady so the leaf is sharp.'),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Upload a leaf photo')),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 32, horizontal: 24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(kRadius),
                      border: Border.all(
                        color: _notFound
                            ? Colors.amber.shade600
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (_imageBytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(kRadius - 4),
                            child: Image.memory(
                              _imageBytes!,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: AppColors.bgAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.image_outlined,
                                size: 40, color: AppColors.textAccent),
                          ),
                        const SizedBox(height: 20),
                        if (_loading) ...[
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                                color: AppColors.textAccent, strokeWidth: 3),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Identifying…',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                          ),
                        ] else if (_notFound) ...[
                          _notFoundContent(),
                        ] else ...[
                          Text(
                            _imageBytes != null
                                ? 'Photo selected'
                                : 'Upload a photo',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Choose a clear photo of the leaf.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15, color: AppColors.textMuted),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15, color: AppColors.danger),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!_loading)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showSourceSheet,
                        icon: const Icon(Icons.upload_outlined, size: 22),
                        label: Text(
                          _imageBytes != null
                              ? 'Try another photo'
                              : 'Choose photo',
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: AppColors.onBrand,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kRadius),
                          ),
                        ),
                      ),
                    ),
                  if (!_loading && _notFound && !kIsWeb) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined, size: 22),
                        label: const Text('Take a new photo',
                            style: TextStyle(fontSize: 16)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textAccent,
                          side: BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kRadius),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}