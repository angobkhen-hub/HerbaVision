import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/herb_scan.dart';
import '../services/herb_recognition_service.dart';
import '../theme/app_colors.dart';

/// Lets the user upload a photo of a leaf and shows the identification result.
///
/// Photo picking uses `image_picker`. The actual identification call lives
/// in [HerbRecognitionService] — right now it's mocked, so swap that file
/// out (not this one) once a real backend exists.
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _picker = ImagePicker();
  final _recognitionService = HerbRecognitionService();

  File? _image;
  bool _loading = false;
  String? _error;

  Future<void> _showSourceSheet() async {
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
                leading: const Icon(Icons.photo_camera_outlined,
                    color: AppColors.textAccent),
                title: const Text('Take a photo'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
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

      setState(() {
        _image = File(picked.path);
        _error = null;
      });

      await _identify();
    } catch (e) {
      setState(() => _error = 'Could not open camera/gallery. Please try again.');
    }
  }

  Future<void> _identify() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final HerbScan scan = await _recognitionService.identifyLeaf(_image!);
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).pop(scan);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Upload a leaf photo')),
      body: Center(
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
                    if (_image != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(kRadius - 4),
                        child: Image.file(
                          _image!,
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.bgAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.image_outlined,
                            size: 32, color: AppColors.textAccent),
                      ),
                    const SizedBox(height: 16),
                    if (_loading) ...[
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: AppColors.textAccent, strokeWidth: 3),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Identifying…',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                    ] else ...[
                      Text(
                        _image != null ? 'Photo selected' : 'Upload a photo',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
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
                        style: const TextStyle(
                            fontSize: 13, color: Colors.redAccent),
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
                    label: Text(_image != null ? 'Try another photo' : 'Choose photo'),
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
    );
  }
}