import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
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

/// Wi‑Fi / default: [Printing.layoutPdf]. Direct: Bluetooth serial (Android) or USB when connected.
class PrinterService extends ChangeNotifier {
  PrinterService._();
  static final PrinterService instance = PrinterService._();
  factory PrinterService() => instance;

  final _fbs = FlutterBluetoothSerial.instance;

  uio.UsbPort? _usbPort;
  uio.UsbDevice? _usbDevice;
  BluetoothConnection? _btConnection;
  StreamSubscription<Uint8List>? _btInputSub;

  bool _scanning = false;
  List<BluetoothDevice> _btDevices = [];
  String? _lastBtName;
  String? _lastBtAddress;
  String? _connectedDeviceName;
  PrinterConnectionType _connectionType = PrinterConnectionType.none;
  StreamSubscription<dynamic>? _usbSub;
  String? _lastUsbLabel;

  bool get _isBtLinkOk =>
      _btConnection != null && (_btConnection!.isConnected) && _connectionType == PrinterConnectionType.bluetooth;

  /// True when USB port is open or an active Bluetooth serial link exists.
  bool get isDirectPrintReady {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      if (_connectionType == PrinterConnectionType.bluetooth) {
        return _isBtLinkOk;
      }
      if (_connectionType == PrinterConnectionType.usb) {
        return _usbPort != null;
      }
    }
    return false;
  }

  bool get _isBtConnected => _isBtLinkOk;

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
  static bool get _isAndroidSerialBt => !kIsWeb && Platform.isAndroid;

  String statusLine(LanguageService lang) {
    if (isDirectPrintReady && _connectedDeviceName != null) {
      return _connectedDeviceName!;
    }
    if (_lastBtName != null && _lastBtName!.isNotEmpty) {
      return '${lang.printerStatusLast} $_lastBtName';
    }
    if (_lastUsbLabel != null && _lastUsbLabel!.isNotEmpty) {
      return '${lang.printerStatusLast} $_lastUsbLabel';
    }
    return lang.printerStatusNone;
  }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _lastBtName = p.getString(_kLastBtName);
    _lastBtAddress = p.getString(_kLastBtAddress);
    _lastUsbLabel = p.getString(_kLastUsbName);
    if (isAndroidUsbSupported) {
      _usbSub = uio.UsbSerial.usbEventStream?.listen((_) {
        unawaited(_probeUsbList());
      });
    }
    if (isAndroidUsbSupported) {
      unawaited(_probeUsbList());
    }
    if (_isAndroidSerialBt) {
      unawaited(_tryReconnectLastBluetooth());
    }
  }

  Future<void> _tryReconnectLastBluetooth() async {
    if (!_isAndroidSerialBt) return;
    if (_lastBtAddress == null || _lastBtAddress!.isEmpty) return;
    if (isConnected && _connectionType == PrinterConnectionType.bluetooth) return;
    try {
      final list = await _fbs.getBondedDevices();
      for (final d in list) {
        if (d.address == _lastBtAddress) {
          await connectBluetooth(d);
          return;
        }
      }
    } catch (_) {}
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
    if (!_isAndroidSerialBt) return;
    _scanning = true;
    notifyListeners();
    try {
      _btDevices = await _fbs.getBondedDevices();
    } catch (_) {
      _btDevices = [];
    }
    _scanning = false;
    notifyListeners();
  }

  Future<void> _closeBluetooth() async {
    await _btInputSub?.cancel();
    _btInputSub = null;
    if (_btConnection != null) {
      try {
        await _btConnection!.close();
      } catch (_) {}
      _btConnection = null;
    }
    if (_connectionType == PrinterConnectionType.bluetooth) {
      _connectionType = PrinterConnectionType.none;
      _connectedDeviceName = null;
    }
  }

  Future<bool> connectBluetooth(BluetoothDevice device) async {
    if (!_isAndroidSerialBt) return false;
    try {
      await _closeUsb();
      await _closeBluetooth();
      final conn = await BluetoothConnection.toAddress(device.address);
      _btInputSub = conn.input?.listen(
        (_) {},
        onError: (_) {},
        onDone: () {
          if (_connectionType == PrinterConnectionType.bluetooth) {
            unawaited(_closeBluetooth());
            notifyListeners();
          }
        },
        cancelOnError: false,
      );
      _btConnection = conn;
      _connectionType = PrinterConnectionType.bluetooth;
      _connectedDeviceName = device.name?.isNotEmpty == true ? device.name! : device.address;
      _lastBtName = _connectedDeviceName;
      _lastBtAddress = device.address;
      final p = await SharedPreferences.getInstance();
      if (_lastBtName != null) await p.setString(_kLastBtName, _lastBtName!);
      if (_lastBtAddress != null) await p.setString(_kLastBtAddress, _lastBtAddress!);
      notifyListeners();
      return true;
    } catch (_) {
      await _closeBluetooth();
      notifyListeners();
      return false;
    }
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
      await _closeBluetooth();
      await _closeUsb();
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
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_connectionType == PrinterConnectionType.bluetooth) {
      await _closeBluetooth();
    } else {
      await _closeUsb();
    }
    notifyListeners();
  }

  static const _btChunk = 512;

  Future<void> _writeAllToBluetooth(Uint8List pdfBytes) async {
    final out = _btConnection!.output;
    for (var i = 0; i < pdfBytes.length; i += _btChunk) {
      final end = (i + _btChunk < pdfBytes.length) ? i + _btChunk : pdfBytes.length;
      out.add(pdfBytes.sublist(i, end));
    }
    await out.allSent;
  }

  Future<bool> printPdf(Uint8List pdfBytes) async {
    if (pdfBytes.isEmpty) return false;
    if (_connectionType == PrinterConnectionType.bluetooth && _isBtConnected) {
      try {
        await _writeAllToBluetooth(pdfBytes);
        return true;
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
    unawaited(_closeBluetooth());
    _usbSub?.cancel();
    super.dispose();
  }
}

/// Direct print (Bluetooth/USB) when [PrinterService.isDirectPrintReady], else [Printing.layoutPdf].
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
