import 'dart:io';
import 'dart:typed_data';
import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/services/currency/currency_controller.dart';
import 'package:billbuddy/data/entities/receipt.dart';
import 'package:billbuddy/processes/receipt/receipt_scan_pipeline.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final ReceiptScanPipeline _pipeline;
  final ImagePicker _picker = ImagePicker();

  bool _isOpeningScanner = true;
  bool _isProcessing = false;
  bool _scannerOpened = false;
  Receipt? _receipt;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pipeline = getIt<ReceiptScanPipeline>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openDocumentScanner());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _openDocumentScanner() async {
    if (_scannerOpened || !mounted) return;
    _scannerOpened = true;
    try {
      final paths = await CunningDocumentScanner.getPictures(
        scannerSource: ScannerSource.cameraAndGallery,
        noOfPages: 10,
      );
      if (paths == null || paths.isEmpty) return;
      await _processImages([
        for (final path in paths) await File(path).readAsBytes(),
      ]);
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Could not open the receipt scanner: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningScanner = false);
    }
  }

  Future<void> _chooseFromGallery() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      await _processImage(await picked.readAsBytes());
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Could not open the selected photo: $error',
        );
      }
    }
  }

  Future<void> _processImage(Uint8List imageBytes) async {
    await _processImages([imageBytes]);
  }

  Future<void> _processImages(List<Uint8List> imageBytesList) async {
    if (imageBytesList.isEmpty) {
      if (mounted) {
        setState(() => _errorMessage = 'No receipt image was selected.');
      }
      return;
    }
    setState(() {
      _errorMessage = null;
      _isProcessing = true;
    });

    try {
      final result = await _pipeline.runMany(
        imageBytesList,
        onNonFatalWarning: (message) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          }
        },
      );

      if (!mounted) return;
      result.fold(
        onSuccess: (receipt) => setState(() => _receipt = receipt),
        onFailure: (failure) => setState(() => _errorMessage = failure.message),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Could not process this receipt: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan a receipt'),
        centerTitle: true,
      ),
      body: _receipt != null ? _buildReceipt() : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    if (_isOpeningScanner || _isProcessing) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.document_scanner_outlined, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Scan a receipt or choose one from your gallery.',
              textAlign: TextAlign.center,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                _scannerOpened = false;
                setState(() => _isOpeningScanner = true);
                _openDocumentScanner();
              },
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan receipt'),
            ),
            TextButton.icon(
              onPressed: _chooseFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from gallery'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceipt() {
    final receipt = _receipt!;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            Text(
              receipt.merchantName ?? 'Receipt saved',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Total  ${getIt<CurrencyController>().format(receipt.total, fallback: "0.00")}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            const Text(
              'Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...receipt.items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.name),
                subtitle: Text('Quantity: ${item.quantity ?? 1}'),
                trailing: Text(
                  getIt<CurrencyController>().format(
                    item.price,
                    fallback: "0.00",
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
