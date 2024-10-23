import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class ReceiptDialog extends StatefulWidget {
  final int busNumber;
  final String reservedTime;
  final List<String> selectedSeats;
  final double totalPrice;

  const ReceiptDialog(
      {Key? key,
      required this.busNumber,
      required this.reservedTime,
      required this.selectedSeats,
      required this.totalPrice})
      : super(key: key);

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  final GlobalKey _receiptKey = GlobalKey();
  String? passengerName;

  @override
  void initState() {
    super.initState();
    _loadPassengerName();
  }

  Future<void> _loadPassengerName() async {
    final box = await Hive.openBox('authBox');
    setState(() {
      passengerName = box.get('passenger_name', defaultValue: 'Guest');
    });
  }

  Future<void> _captureAndSaveReceipt() async {
    try {
      // Request storage permission
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Storage permission is required to save the receipt')),
        );
        return;
      }

      // Capture the widget as an image
      RenderRepaintBoundary boundary = _receiptKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        // Get the downloads directory for Android or documents directory for iOS
        final Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        // Generate unique filename with timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final imagePath =
            '${directory.path}/bus_ticket_receipt_$timestamp.png';
        final File imageFile = File(imagePath);

        // Save the image
        await imageFile.writeAsBytes(byteData.buffer.asUint8List());

        // Show success message with file location
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt saved to: $imagePath'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () async {
                await Share.shareXFiles(
                  [XFile(imagePath)],
                  text: 'My Bus Ticket Receipt',
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save receipt: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Receipt Content
          RepaintBoundary(
            key: _receiptKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Icon(
                    Icons.directions_bus_rounded,
                    size: 48,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Bus Ticket Receipt',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Receipt Details
                  _buildReceiptRow('Passenger', passengerName ?? 'Loading...'),
                  const Divider(),
                  _buildReceiptRow('Bus Number', widget.busNumber.toString()),
                  const Divider(),
                  _buildReceiptRow('Reserved Date', widget.reservedTime),
                   const Divider(),
                  _buildReceiptRow('Total Price', widget.totalPrice.toString()),
                  const Divider(),
                  _buildReceiptRow(
                      'Selected Seats', widget.selectedSeats.join(', ')),
                  const Divider(),

                  // Footer
                  const Text(
                    'Thank you for choosing our service!',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  onPressed: _captureAndSaveReceipt,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Save Receipt'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
