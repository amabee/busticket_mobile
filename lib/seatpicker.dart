// seatpicker.dart
import 'package:flutter/material.dart';

class SeatPicker extends StatefulWidget {
  final int numberOfSeats;
  final int seatsPerRow;
  final int maxSelectableSeats;
  final List<int> reservedSeats;
  final Function(List<int>) onSeatSelected;

  const SeatPicker({
    Key? key,
    this.numberOfSeats = 20,
    this.seatsPerRow = 4,
    required this.maxSelectableSeats,
    required this.onSeatSelected,
    required this.reservedSeats,
  }) : super(key: key);

  @override
  State<SeatPicker> createState() => _SeatPickerState();
}

class _SeatPickerState extends State<SeatPicker> {
  Set<int> selectedSeats = {};

  @override
  void didUpdateWidget(SeatPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reservedSeats != widget.reservedSeats) {
      setState(() {
        selectedSeats
            .removeWhere((seat) => widget.reservedSeats.contains(seat));
        widget.onSeatSelected(selectedSeats.toList());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Select Seats",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                _SeatIndicator(
                  color: Colors.grey,
                  label: "Reserved",
                ),
                const SizedBox(width: 16),
                _SeatIndicator(
                  color: Colors.red,
                  label: "Selected",
                ),
                const SizedBox(width: 16),
                _SeatIndicator(
                  color: Colors.white,
                  label: "Available",
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              for (int row = 0;
                  row < (widget.numberOfSeats / widget.seatsPerRow).ceil();
                  row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (int seat = 0; seat < widget.seatsPerRow; seat++)
                        if (row * widget.seatsPerRow + seat <
                            widget.numberOfSeats)
                          _buildSeat(row * widget.seatsPerRow + seat + 1),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeat(int seatNumber) {
    bool isSelected = selectedSeats.contains(seatNumber);
    bool isReserved = widget.reservedSeats.contains(seatNumber);

    return GestureDetector(
      onTap: () {
        if (!isReserved) {
          setState(() {
            if (isSelected) {
              selectedSeats.remove(seatNumber);
            } else {
              if (selectedSeats.length < widget.maxSelectableSeats) {
                selectedSeats.add(seatNumber);
              }
            }
            widget.onSeatSelected(selectedSeats.toList());
          });
        }
      },
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isReserved
              ? Colors.grey
              : isSelected
                  ? Colors.red
                  : Colors.white,
          border: Border.all(
            color: Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            seatNumber.toString(),
            style: TextStyle(
              color: isSelected || isReserved ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// Add the _SeatIndicator widget class
class _SeatIndicator extends StatelessWidget {
  final Color color;
  final String label;

  const _SeatIndicator({
    Key? key,
    required this.color,
    required this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}
