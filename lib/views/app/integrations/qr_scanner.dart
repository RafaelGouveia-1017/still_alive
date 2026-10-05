import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../data/all.dart';
import '../../widgets/primitives.dart';

/// A screen that scans QR codes used for application pairing.
///
/// The scanner accepts QR codes whose contents are Base64URL-encoded URLs.
/// Successfully decoded URLs are returned through the navigation result.
///
/// The screen also:
/// * Requests camera permission when necessary.
/// * Provides a torch toggle when supported by the device.
/// * Displays a scanning overlay and QR-code guidance.
/// * Prevents multiple QR codes from being processed simultaneously.
///
/// Returns the decoded URL when a valid QR code is scanned, or `null` when
/// the scanner is dismissed or an invalid QR code is encountered.
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();

  /// Decodes a Base64URL-encoded value into a JSON string.
  ///
  /// The input may use unpadded Base64URL encoding. The encoded value is
  /// normalized to standard Base64 before decoding.
  ///
  /// The decoded value must be valid JSON.
  ///
  /// Returns the decoded JSON string when validation succeeds.
  ///
  /// Throws an [Exception] when the value cannot be decoded or the decoded
  /// value is not valid JSON.
  static String decodeBase64Url(String value) {
    // Base64URL -> standard Base64
    String normalized = value.replaceAll('-', '+').replaceAll('_', '/');

    // Restore padding if omitted.
    normalized += '=' * ((4 - normalized.length % 4) % 4);

    String decoded = '';

    try {
      // Decode as UTF-8.
      decoded = utf8.decode(base64Decode(normalized));
    } catch (e) {
      throw Exception('QR value is not a valid base64 string.\noriginal:\t$value');
    }

    try {
      jsonDecode(decoded);
      return decoded;
    } catch (e) {
      throw Exception(
        'QR value is a base64 string but not valid JSON.\noriginal:\t$value\ndecoded:\t$decoded',
      );
    }
  }
}

/// State for [QRScannerScreen].
///
/// Manages the camera permission state, QR scanner controller, torch state,
/// and QR-code detection lifecycle.
class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  PermissionStatus _cameraStatus = PermissionStatus.denied;

  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() async {
    final status = await Permission.camera.status;
    setState(() {
      _cameraStatus = status;
    });
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _requestCameraStatus() async {
    final status = await PermissionManager.instance.requestPermission(Permission.camera);
    if (!mounted) return;
    setState(() => _cameraStatus = status);
  }

  /// Handles QR and barcode detection events from [MobileScanner].
  ///
  /// Only the first successfully detected value is processed. The detected
  /// value is expected to be a Base64URL-encoded HTTP or HTTPS URL.
  ///
  /// If the QR code is valid, the decoded URL is returned through the
  /// navigation result. Invalid QR codes cause the scanner screen to close
  /// without returning a result.
  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;

      if (value != null && value.isNotEmpty) {
        _hasScanned = true;

        try {
          final json = decodeBase64Url(value);
          AppLogger.log.info('Valid QR Result: $json');
          Navigator.of(context).pop(json);
        } catch (e, st) {
          AppLogger.log.fine('Invalid QR Result:', e, st);
          Navigator.of(context).pop();
        }

        return;
      }
    }
  }

  /// Decodes a Base64URL-encoded value into a JSON string.
  ///
  /// The input may use unpadded Base64URL encoding. The encoded value is
  /// normalized to standard Base64 before decoding.
  ///
  /// The decoded value must be valid JSON.
  ///
  /// Returns the decoded JSON string when validation succeeds.
  ///
  /// Throws an [Exception] when the value cannot be decoded or the decoded
  /// value is not valid JSON.
  String decodeBase64Url(String value) {
    return QRScannerScreen.decodeBase64Url(value);
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    TorchState torchState = controller.value.torchState;

    return ScreenBase(
      noSpacing: true,
      header: AppHeader(
        title: local.translate("qr_pairing.title"),
        subtitle: local.translate("qr_pairing.description"),
        left: CircleIconButton(icon: LucideIcons.chevronLeft, onTap: () => Navigator.pop(context)),
        right: CircleIconButton(
          icon: switch (torchState) {
            TorchState.auto => Icons.flash_auto,
            TorchState.on => LucideIcons.zap,
            TorchState.off => LucideIcons.zapOff,
            _ => LucideIcons.zapOff,
          },
          onTap: () => (torchState == TorchState.unavailable) ? null : controller.toggleTorch(),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: (_cameraStatus != PermissionStatus.granted)
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(AppRadius.xxl),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Icon(LucideIcons.cameraOff, size: 36, color: scheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Center(
                        child: Text(
                          local.translate("qr_pairing.no_camera"),
                          style: AppText.bodySm(scheme).copyWith(color: scheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Pressable(
                        onTap: () => _requestCameraStatus(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.ms),
                          decoration: BoxDecoration(color: scheme.primary, borderRadius: AppRadius.chip),
                          child: Text(switch (_cameraStatus) {
                            PermissionStatus.denied => local.translate("permissions.allow"),
                            _ => local.translate("settings.title"),
                          }, style: AppText.caption(scheme).copyWith(color: scheme.onPrimary)),
                        ),
                      ),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(controller: controller, onDetect: _onDetect),

                      CustomPaint(painter: ScannerOverlayPainter(scanSize: 330)),

                      Positioned(
                        left: 24,
                        right: 24,
                        top: 80,
                        child: Column(
                          children: [
                            Text(
                              local.translate("qr_pairing.valid_qr.0"),
                              style: AppText.bodySm(scheme).copyWith(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  local.translate("qr_pairing.valid_qr.1"),
                                  style: AppText.bodySm(scheme).copyWith(color: Colors.white70),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(width: 8),
                                Icon(LucideIcons.shield, color: Colors.white, size: 20),
                                if (local.translate("qr_pairing.valid_qr.0") != "") ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    local.translate("qr_pairing.valid_qr.2"),
                                    style: AppText.bodySm(scheme).copyWith(color: Colors.white70),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      Center(
                        child: SizedBox(
                          width: 330,
                          height: 330,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white70, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Paints a darkened area surrounding the QR-code scanning region.
///
/// The scanner region remains transparent so that the camera preview is
/// visible through it. The surrounding area is dimmed to visually guide the
/// user toward the intended scanning region.
///
/// The [scanSize] determines the width and height of the transparent
/// scanning area.
class ScannerOverlayPainter extends CustomPainter {
  final double scanSize;

  ScannerOverlayPainter({required this.scanSize});

  /// Paints the dimmed overlay and transparent scanning region.
  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);

    final clearPaint = Paint()..blendMode = BlendMode.clear;

    final scanRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: size.center(Offset.zero), width: scanSize, height: scanSize),
      const Radius.circular(16),
    );

    canvas.saveLayer(Offset.zero & size, Paint());

    canvas.drawRect(Offset.zero & size, overlayPaint);

    canvas.drawRRect(scanRect, clearPaint);

    canvas.restore();
  }

  /// Determines whether the overlay needs to be repainted.
  ///
  /// The overlay only needs repainting when [scanSize] changes.
  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanSize != scanSize;
  }
}
