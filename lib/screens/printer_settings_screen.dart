import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_context.dart';
import '../services/language_service.dart';
import '../services/printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _lang = LanguageService();
  final _printer = PrinterService();
  bool _testBusy = false;

  @override
  void initState() {
    super.initState();
    _lang.addListener(_onL);
    _lang.init();
    _printer.addListener(_onL);
  }

  void _onL() => setState(() {});

  @override
  void dispose() {
    _lang.removeListener(_onL);
    _printer.removeListener(_onL);
    super.dispose();
  }

  Future<void> _onTestPrint() async {
    if (_testBusy) return;
    setState(() => _testBusy = true);
    try {
      if (_printer.isDirectPrintReady) {
        final ok = await _printer.testPrint();
        if (ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_lang.isUrdu ? 'ٹیسٹ پرنٹ بھیجا' : 'Test print sent'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        if (!ok) {
          await _fallbackTestSystem();
        }
      } else {
        await _fallbackTestSystem();
      }
    } finally {
      if (mounted) setState(() => _testBusy = false);
    }
  }

  Future<void> _fallbackTestSystem() async {
    if (!mounted) return;
    await printPdfWithDirectFallback(
      context,
      lang: _lang,
      getPdf: PrinterService.buildTestPdfBytes,
      jobName: 'Test',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.policeScaffold,
      appBar: AppBar(
        backgroundColor: context.policeScaffold,
        elevation: 0,
        centerTitle: false,
        title: Text(
          _lang.printerSettingsTitle,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: context.policeTextPrimary),
          textDirection: _lang.textDirection,
        ),
        iconTheme: IconThemeData(color: context.policeTextPrimary),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_lang, _printer]),
        builder: (context, _) {
          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _sectionTitle(_lang.printerWifiTitle, Icons.wifi_rounded),
                      const SizedBox(height: 8),
                      _card(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _lang.printerWifiUseSystem,
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: context.policeTextPrimary,
                                    ),
                                    textDirection: _lang.textDirection,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _lang.printerWifiHelp,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: context.policeTextSecondary,
                                    ),
                                    textDirection: _lang.textDirection,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      _sectionTitle(_lang.printerBluetoothTitle, Icons.bluetooth_rounded),
                      const SizedBox(height: 8),
                      if (_printer.lastConnectedBluetoothName != null && _printer.lastConnectedBluetoothName!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${_lang.printerStatusLast} ${_printer.lastConnectedBluetoothName}',
                            style: GoogleFonts.inter(fontSize: 12, color: context.policeTextHint),
                            textDirection: _lang.textDirection,
                          ),
                        ),
                      FilledButton.icon(
                        onPressed: _printer.isScanningBluetooth
                            ? null
                            : () {
                                unawaited(_printer.scanForBluetoothDevices());
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _printer.isScanningBluetooth
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              )
                            : const Icon(Icons.radar_rounded, size: 20),
                        label: Text(
                          _lang.printerScanCta,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_printer.connectionType == PrinterConnectionType.bluetooth && _printer.isConnected) ...[
                        _card(
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _printer.connectedDeviceName ?? 'Bluetooth',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: context.policeTextPrimary,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => unawaited(_printer.disconnect()),
                                child: Text(
                                  _lang.printerDisconnectCta,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_printer.availableBluetoothDevices.isEmpty)
                        _card(
                          child: Text(
                            _printer.isScanningBluetooth
                                ? (_lang.isUrdu ? 'تلاش جاری...' : 'Scanning…')
                                : (_lang.isUrdu ? 'کوئی جوڑا ہوا آلہ نہیں ملا — پہلے بلیوٹوتھ میں جوڑیں۔' : 'No paired devices. Pair your printer in system Bluetooth first.'),
                            style: GoogleFonts.inter(fontSize: 13, color: context.policeTextSecondary),
                            textDirection: _lang.textDirection,
                          ),
                        )
                      else
                        ..._printer.availableBluetoothDevices.map((d) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _card(
                              child: Row(
                                children: [
                                  const Icon(Icons.print_rounded, color: AppColors.accent, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d.name?.isNotEmpty == true ? d.name! : 'Device',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: context.policeTextPrimary,
                                          ),
                                        ),
                                        if (d.address != null)
                                          Text(
                                            d.address!,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              color: context.policeTextHint,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => unawaited(_printer.connectBluetooth(d)),
                                    child: Text(
                                      _lang.printerConnectCta,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.accent),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 28),
                      _sectionTitle(_lang.printerUsbTitle, Icons.usb_rounded),
                      const SizedBox(height: 8),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _lang.printerUsbCta,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.policeTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _lang.printerUsbHelp,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.4,
                                color: context.policeTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _printer.usbDevice != null ? AppColors.success : context.policeTextHint,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _printer.usbDevice != null ? _lang.printerUsbDetected : _lang.printerUsbNone,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: context.policeTextPrimary,
                                    ),
                                  ),
                                ),
                                if (_printer.isAndroidUsbSupported && _printer.usbDevice != null)
                                  TextButton(
                                    onPressed: () => unawaited(_printer.connectUSB()),
                                    child: Text(
                                      _lang.printerConnectCta,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (_printer.connectionType == PrinterConnectionType.usb && _printer.isConnected) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _printer.connectedDeviceName ?? 'USB',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: context.policeTextSecondary,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => unawaited(_printer.disconnect()),
                                    child: Text(
                                      _lang.printerDisconnectCta,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.error),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(context).padding.bottom),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _testBusy ? null : _onTestPrint,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _testBusy
                          ? SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            )
                          : Text(
                              _lang.printerTestPrint,
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.policeTextHint,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.policeCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.policeBorder.withValues(alpha: 0.85), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: context.isPoliceDark
                ? Colors.black.withValues(alpha: 0.35)
                : AppColors.shadowLight,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
