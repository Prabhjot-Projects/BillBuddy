import 'dart:io';
import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/data/entities/receipt.dart';
import 'package:billbuddy/processes/receipt/receipt_scan_pipeline.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Lets the user pick an existing photo (from their gallery) instead of
/// taking a new one, and runs it through the exact same
/// ReceiptScanPipeline as ScanScreen — same OCR, same AI parsing, same
/// draft-save behavior. This is the payoff of extracting the pipeline:
/// this whole screen is ~1/3 the size ScanScreen would have needed to
/// be if it had duplicated the orchestration logic instead of sharing it.
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late final ReceiptScanPipeline _pipeline;
  final _picker = ImagePicker();

  bool _isLoading = false;
  Receipt? _receipt;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pipeline = getIt<ReceiptScanPipeline>();
  }

  Future<void> _pickAndProcess() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return; // user cancelled the picker

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final imageBytes = await File(picked.path).readAsBytes();

      final result = await _pipeline.run(
        imageBytes,
        onNonFatalWarning: (message) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
      );

      if (!mounted) return;

      result.fold(
        onSuccess: (receipt) => setState(() => _receipt = receipt),
        onFailure: (failure) => setState(() => _errorMessage = failure.message),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Could not read the selected image: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Receipt')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _receipt != null
            ? _buildSuccess()
            : _buildIdleState(),
      ),
    );
  }

  Widget _buildIdleState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_errorMessage != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ElevatedButton.icon(
          icon: const Icon(Icons.photo_library),
          onPressed: _pickAndProcess,
          label: Text(
            _errorMessage != null ? 'Choose Another Photo' : 'Choose Photo',
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    final receipt = _receipt!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 16),
          Text(
            '${receipt.merchantName ?? "Receipt"} saved as a pending bill.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
