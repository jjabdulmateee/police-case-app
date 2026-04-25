import 'dart:async';
import 'dart:io';

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' show PdfColor, PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usb_serial/usb_serial.dart' as uio;

import '../core/theme/app_colors.dart';
import 'language_service.dart';

enum PrinterConnectionType { none, wifi, bluetooth, usb }

const _kLastBtName = 'printer_last_bt_name';
const _kLastBtAddress = 'printer_last_bt_address';
const _kLastUsbDeviceId = 'printer_last_usb_device_id';
const _kLastUsbName = 'printer_last_usb_name';

class PrinterService extends ChangeNotifier {
  PrinterService._();
  static final PrinterService instance = PrinterService._();
  factory PrinterService() => instance;

  final BlueThermalPrinter _bt = BlueThermalPrinter.instance;
  uio.UsbPort? _usbPort;
  uio.UsbDevice? _usbDevice;
  String? _lastBtName;
  String? _lastBtAddress;
  bool _scanning = false;
  List<BluetoothDevice> _btDevices = [];
  String? _connectedDeviceName;
  PrinterConnectionType _connectionType = PrinterConnectionType.none;
  StreamSubscription<dynamic>? _usbSub;
  String? _lastUsbLabel;
  bool? _isBtConnectedCache;

  /// True when a direct (BT/USB) print session can be attempted.
  bool get isDirectPrintReady {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      if (_connectionType == PrinterConnectionType.bluetooth) {
        return _isBtConnected;
      }
      if (_connectionType == PrinterConnectionType.usb) {
        return _usbPort != null;
      }
    }
    if (!kIsWeb && Platform.isIOS && _connectionType == PrinterConnectionType.bluetooth) {
      return _isBtConnected;
    }
    return false;
  }

  bool get _isBtConnected => _isBtConnectedCache == true;

  bool get isConnected {
    if (_connectionType == PrinterConnectionType.bluetooth) {
      return _isBtConnected;
    }
    if (_connectionType == PrinterConnectionType.usb) {
      return _usbPort != null;
    }
    return false;
  }

  PrinterConnectionType get connectionType => _connectionType;
  String? get connectedDeviceName => _connectedDeviceName;
  String? get lastConnectedBluetoothName => _lastBtName;
  List<BluetoothDevice> get availableBluetoothDevices => List.unmodifiable(_btDevices);
  bool get isScanningBluetooth => _scanning;
  uio.UsbDevice? get usbDevice => _usbDevice;

  bool get isAndroidUsbSupported => !kIsWeb && Platform.isAndroid;

  String statusLine(LanguageService lang) {
    if (isDirectPrintReady && _connectedDeviceName != null) {
      return _connectedDeviceName!;
    }
    if (_lastBtName != null && _lastBtName!.isNotEmpty) {
      return '${lang.printerStatusLast} $_lastBtName';
    }
    return lang.printerStatusNone;
  }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _lastBtName = p.getString(_kLastBtName);
    _lastBtAddress = p.getString(_kLastBtAddress);
    _lastUsbLabel = p.getString(_kLastUsbName);
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _bt.onStateChanged().listen((s) {
        if (s == BlueThermalPrinter.CONNECTED) {
          _isBtConnectedCache = true;
          _connectionType = PrinterConnectionType.bluetooth;
        } else if (s == BlueThermalPrinter.DISCONNECTED ||
            s == BlueThermalPrinter.DISCONNECT_REQUESTED ||
            s == BlueThermalPrinter.STATE_OFF) {
          _isBtConnectedCache = false;
          if (_connectionType == PrinterConnectionType.bluetooth) {
            _connectionType = PrinterConnectionType.none;
            _connectedDeviceName = null;
          }
        }
        notifyListeners();
      });
    }
    if (isAndroidUsbSupported) {
      _usbSub = uio.UsbSerial.usbEventStream?.listen((_) {
        unawaited(_probeUsbList());
      });
    }
    await _refreshBluetoothConnectedFlag();
    if (isAndroidUsbSupported) {
      unawaited(_probeUsbList());
    }
    unawaited(_tryReconnectLastBluetooth());
  }

  Future<void> _tryReconnectLastBluetooth() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_lastBtAddress == null || _lastBtAddress!.isEmpty) return;
    if (isConnected && _connectionType == PrinterConnectionType.bluetooth) return;
    try {
      final list = await _bt.getBondedDevices();
      for (final d in list) {
        if (d.address == _lastBtAddress) {
          await connectBluetooth(d);
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _refreshBluetoothConnectedFlag() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      final c = await _bt.isConnected;
      _isBtConnectedCache = c == true;
      if (c == true && _connectionType == PrinterConnectionType.none) {
        _connectionType = PrinterConnectionType.bluetooth;
      }
    } catch (_) {
      _isBtConnectedCache = false;
    }
  }

  Future<void> _probeUsbList() async {
    if (!isAndroidUsbSupported) return;
    try {
      final list = await uio.UsbSerial.listDevices();
      if (list.isEmpty) {
        if (_usbPort == null) {
          _usbDevice = null;
          if (_connectionType == PrinterConnectionType.usb) {
            _connectionType = PrinterConnectionType.none;
            _connectedDeviceName = null;
          }
        }
        notifyListeners();
        return;
      }
      uio.UsbDevice? d;
      final id = (await SharedPreferences.getInstance()).getInt(_kLastUsbDeviceId);
      if (id != null) {
        for (final e in list) {
          if (e.deviceId == id) {
            d = e;
            break;
          }
        }
      }
      d ??= list.first;
      _usbDevice = d;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> scanForBluetoothDevices() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    _scanning = true;
    notifyListeners();
    try {
      await _refreshBluetoothConnectedFlag();
      _btDevices = await _bt.getBondedDevices();
    } catch (_) {
      _btDevices = [];
    }
    _scanning = false;
    notifyListeners();
  }

  Future<bool> connectBluetooth(BluetoothDevice device) async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      await _bt.disconnect();
      final r = await _bt.connect(device);
      if (r == true || r == null) {
        _connectionType = PrinterConnectionType.bluetooth;
        _connectedDeviceName = device.name?.isNotEmpty == true ? device.name! : (device.address ?? 'Bluetooth');
        _isBtConnectedCache = true;
        _lastBtName = _connectedDeviceName;
        _lastBtAddress = device.address;
        final p = await SharedPreferences.getInstance();
        if (_lastBtName != null) await p.setString(_kLastBtName, _lastBtName!);
        if (_lastBtAddress != null) await p.setString(_kLastBtAddress, _lastBtAddress!);
        if (_usbPort != null) {
          unawaited(_closeUsb());
        }
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _closeUsb() async {
    try {
      await _usbPort?.close();
    } catch (_) {}
    _usbPort = null;
    if (_connectionType == PrinterConnectionType.usb) {
      _connectionType = PrinterConnectionType.none;
      _connectedDeviceName = null;
    }
  }

  Future<bool> connectUSB() async {
    if (!isAndroidUsbSupported) return false;
    try {
      unawaited(_closeUsb());
      final list = await uio.UsbSerial.listDevices();
      if (list.isEmpty) return false;
      uio.UsbDevice? d = _usbDevice;
      d ??= list.first;
      final port = await d.create();
      if (port == null) return false;
      if (!await port.open()) {
        await port.close();
        return false;
      }
      await port.setPortParameters(115200, uio.UsbPort.DATABITS_8, uio.UsbPort.STOPBITS_1, uio.UsbPort.PARITY_NONE);
      _usbPort = port;
      _usbDevice = d;
      _connectionType = PrinterConnectionType.usb;
      _connectedDeviceName = d.productName?.isNotEmpty == true
          ? d.productName!
          : (d.manufacturerName ?? 'USB ${(d.vid ?? 0).toRadixString(16)}');
      _lastUsbLabel = _connectedDeviceName;
      final p = await SharedPreferences.getInstance();
      if (d.deviceId != null) {
        await p.setInt(_kLastUsbDeviceId, d.deviceId!);
      }
      if (_lastUsbLabel != null) await p.setString(_kLastUsbName, _lastUsbLabel!);
      try {
        await _bt.disconnect();
        _isBtConnectedCache = false;
      } catch (_) {}
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_connectionType == PrinterConnectionType.bluetooth) {
      try {
        await _bt.disconnect();
      } catch (_) {}
      _isBtConnectedCache = false;
      _connectedDeviceName = null;
      _connectionType = PrinterConnectionType.none;
    } else {
      unawaited(_closeUsb());
    }
    notifyListeners();
  }

  Future<bool> printPdf(Uint8List pdfBytes) async {
    if (pdfBytes.isEmpty) return false;
    if (_connectionType == PrinterConnectionType.bluetooth && _isBtConnected) {
      try {
        final r = await _bt.writeBytes(pdfBytes);
        return r == true || r == null;
      } catch (_) {
        return false;
      }
    }
    if (_connectionType == PrinterConnectionType.usb && _usbPort != null) {
      try {
        await _usbPort!.write(pdfBytes);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  static Future<Uint8List> buildTestPdfBytes() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (c) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'Police Case Docs — test print',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF0A1929),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'If you see this, your direct printer link is working.',
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
    return Uint8List.fromList(await doc.save());
  }

  Future<bool> testPrint() async {
    return printPdf(await buildTestPdfBytes());
  }

  @override
  void dispose() {
    _usbSub?.cancel();
    super.dispose();
  }
}

/// Direct print when [PrinterService.isDirectPrintReady], else (or on failure) system dialog.
Future<void> printPdfWithDirectFallback(
  BuildContext? context, {
  required LanguageService? lang,
  required Future<Uint8List> Function() getPdf,
  String jobName = 'Case',
}) async {
  final ps = PrinterService();
  final bytes = await getPdf();
  if (ps.isDirectPrintReady) {
    final ok = await ps.printPdf(bytes);
    if (ok) return;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang?.printDirectFailedFallback ?? 'Direct printing failed. Opening system print dialog.',
            textDirection: lang?.textDirection,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
  final printed = await Printing.layoutPdf(
    onLayout: (f) => Future<Uint8List>.value(bytes),
    name: jobName,
  );
  if (!printed && context != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lang?.isUrdu == true
              ? 'کوئی پرنٹر نہیں ملا — دوبارہ کوشش کریں۔'
              : 'No printer found — please try again or check system print.',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
