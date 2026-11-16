import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/herb_scan.dart';
import '../services/herb_recognition_service.dart';
import '../theme/app_animations.dart';
import '../theme/app_colors.dart';
import '../theme/herba_ui.dart';

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
  /// When true the scanner renders as a compact popup instead of a full page.
  final bool popup;

  const UploadScreen({super.key, this.popup = false});

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
      setState(
          () => _error = 'Could not open camera/gallery. Please try again.');
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

  // ---------------------------------------------------------------------
  // Display pieces
  // ---------------------------------------------------------------------

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
              style: TextStyle(fontSize: 14.5, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyPreview() {
    return Container(
      height: 248,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.emerald.withAlpha(AppColors.isDark ? 20 : 14),
            AppColors.bgBottom,
          ],
        ),
      ),
      child: CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: AppColors.emerald.withAlpha(110),
          radius: 20,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PulsingRings(
              size: 140,
              color: AppColors.emerald,
              ringCount: 3,
              child: HerbaLogo(size: 76),
            ),
            const SizedBox(height: 16),
            Text(
              'Drop a leaf into view',
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'A clear photo of one leaf works best.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            MicroLabel('Awaiting leaf sample', color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _photoPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 268,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(_imageBytes!, fit: BoxFit.cover),
            if (_loading) const ScanningOverlay(),
            if (!_loading)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(150),
                    ],
                    stops: const [0.55, 1.0],
                  ),
                ),
              ),
            if (!_loading)
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Row(
                  children: [
                    Icon(Icons.image_outlined,
                        size: 17, color: Colors.white.withAlpha(220)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withAlpha(230),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
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

    return FadeSlideIn(
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(38),
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
                color: Colors.amber.withAlpha(38),
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
              borderRadius: BorderRadius.circular(16),
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
                _tip(Icons.eco_outlined,
                    'Show one leaf, filling most of the photo.'),
                _tip(Icons.wb_sunny_outlined,
                    'Use good, even daylight. Avoid shadows.'),
                _tip(Icons.crop_free,
                    'Keep the background plain and uncluttered.'),
                _tip(Icons.center_focus_strong_outlined,
                    'Hold the camera steady so the leaf is sharp.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return Column(
        children: [
          Text(
            'Identifying your leaf',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const _CyclingStatus(
            messages: [
              'Reading the leaf pattern…',
              'Comparing with known herbs…',
              'Checking the details…',
            ],
          ),
        ],
      );
    }

    if (_notFound) return _notFoundContent();

    return Column(
      children: [
        Text(
          _imageBytes != null ? 'Photo selected' : 'Upload a photo',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          _imageBytes != null
              ? 'Ready — choose another photo to try again.'
              : 'Choose a clear, well-lit photo of a single leaf.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.5, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _primaryButton() {
    return NeonButton(
      onPressed: _showSourceSheet,
      icon: _imageBytes != null
          ? Icons.refresh_rounded
          : Icons.add_a_photo_outlined,
      label: _imageBytes != null ? 'Try another photo' : 'Choose photo',
      expand: true,
    );
  }

  Widget _scannerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.glassGradient,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _notFound ? AppColors.accentAmber : AppColors.glassBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: AppColors.emerald.withAlpha(AppColors.isDark ? 26 : 14),
            blurRadius: 60,
            spreadRadius: -18,
          ),
        ],
      ),
      child: Column(
        children: [
          if (_imageBytes != null) _photoPreview() else _emptyPreview(),
          const SizedBox(height: 20),
          AnimatedSize(
            duration: HerbaMotion.normal,
            curve: HerbaMotion.easeOut,
            child: _content(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_loading) _primaryButton(),
        if (!_loading && _notFound && !kIsWeb) ...[
          const SizedBox(height: 12),
          PressableScale(
            child: SizedBox(
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPopup() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 48,
            spreadRadius: -8,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 10, 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withAlpha(AppColors.isDark ? 26 : 18),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: AppColors.brand.withAlpha(60)),
                  ),
                  child: Icon(
                    Icons.local_florist_outlined,
                    size: 20,
                    color: AppColors.textAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan a leaf',
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Upload a photo and let HerbaVision name the plant.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed:
                      _loading ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 80),
                    child: _scannerCard(),
                  ),
                  const SizedBox(height: 18),
                  _actionArea(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.popup) return _buildPopup();

    return HerbaBackdrop(
      intensity: AppColors.dark ? 1.0 : 1.1,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Leaf scanner'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeSlideIn(
                        child: Column(
                          children: [
                            MicroLabel(
                              'Leaf recognition',
                              color: AppColors.lime,
                            ),
                            const SizedBox(height: 12),
                            GradientText(
                              'Scan a leaf',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Sora',
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.2,
                              ),
                              gradient: LinearGradient(
                                colors: AppColors.isDark
                                    ? const [
                                        Colors.white,
                                        Color(0xFFD8FF7A),
                                        Color(0xFF2EE59D),
                                      ]
                                    : const [
                                        Color(0xFF0C2015),
                                        Color(0xFF0F8A45),
                                      ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Point, upload, and let HerbaVision name the plant.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 120),
                        child: _scannerCard(),
                      ),
                      const SizedBox(height: 22),
                      _actionArea(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rotating status line shown while the model is working.
class _CyclingStatus extends StatefulWidget {
  final List<String> messages;

  const _CyclingStatus({required this.messages});

  @override
  State<_CyclingStatus> createState() => _CyclingStatusState();
}

class _CyclingStatusState extends State<_CyclingStatus> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % widget.messages.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Text(
        widget.messages[_index],
        key: ValueKey(_index),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary),
      ),
    );
  }
}

/// Dashed, rounded outline used by the empty upload area.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({
    required this.color,
    this.radius = 20,
  });

  static const double _dash = 7;
  static const double _gap = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      ));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dash;
        canvas.drawPath(
          metric.extractPath(distance, math.min(next, metric.length)),
          paint,
        );
        distance = next + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
