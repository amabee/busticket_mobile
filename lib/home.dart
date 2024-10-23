// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:busticket_mobile/login.dart';
import 'package:busticket_mobile/receipt.dart';
import 'package:busticket_mobile/seatpicker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool tripType = false;
  String? selectedFrom;
  String? selectedTo;
  String? selectedPaymentType;
  List<Map<String, dynamic>> destinationsData = [];
  List<String> paymentTypes = ['Cash', 'Gcash'];
  List<int> selectedSeats = [];
  List<int> reservedSeats = [];
  List<int> availableSeats = [];
  int totalSeatCount = 0;
  int? currentTripId;
  DateTime? selectedDate;
  double farePrice = 0.0;
  double totalFare = 0.0;
  int busDriverID = 0;
  int busNumber = 0;

  List<String> passengerTypes = ['Regular', 'Student', 'Senior Citizen'];
  String? selectedPassengerType;

  final TextEditingController _numberOfPassenger = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    getDestinations();
    _numberOfPassenger.text = '1';
    // Set default date to tomorrow
    selectedDate = DateTime.now().add(const Duration(days: 1));
    _dateController.text = DateFormat('MMM dd, yyyy').format(selectedDate!);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.red,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        _dateController.text = DateFormat('MMM dd, yyyy').format(picked);

        if (currentTripId != null && currentTripId != 0) {
          getBusSeats(currentTripId!);
        }
      });
    }
  }

  void _logout() async {
    final authBox = Hive.box('authBox');
    await authBox.delete('passenger_id');

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> getDestinations() async {
    var url = Uri.parse('http://192.168.56.1/apibus/passenger/api.php');
    final query = {"operation": "getDestinations", "json": jsonEncode({})};
    final response = await http.get(url.replace(queryParameters: query));

    try {
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        List<dynamic> fetchedDestinations = jsonResponse['success'];

        setState(() {
          destinationsData = fetchedDestinations
              .map<Map<String, dynamic>>((item) => {
                    'trip_id': item['tid'],
                    'display': '${item['from_loc']} -> ${item['to_loc']}',
                    'fare': (item['fare_price'] is int)
                        ? item['fare_price'].toDouble()
                        : double.parse(item['fare_price'] ?? '0.0'),
                    'driverID': item["driver_id"],
                    'busNumberData': item['bus_assigned']
                  })
              .toList();
        });
      } else {
        throw Exception('Failed to load destinations');
      }
    } catch (error) {
      print("Error: $error");
      throw error;
    }
  }

  Future<void> getBusSeats(int tripId) async {
    var url = Uri.parse('http://192.168.56.1/apibus/passenger/api.php');
    final query = {
      "operation": "getBusSeats",
      "json": jsonEncode({
        "trip_id": tripId,
        "reservation_time": selectedDate != null
            ? DateFormat('yyyy-MM-dd').format(selectedDate!)
            : null
      })
    };
    final response = await http.get(url.replace(queryParameters: query));

    try {
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['success'] == true) {
          List<int> availableSeatsList =
              List<int>.from(jsonResponse['available_seats']);

          List<int> reservedSeatsList =
              List<int>.from(jsonResponse['reserved_seats']);

          int totalSeats = jsonResponse['seat_capacity'];

          var farePriceData = jsonResponse['fare_price'];
          double farePrice;

          if (farePriceData is int) {
            farePrice = farePriceData.toDouble();
          } else if (farePriceData is String) {
            farePrice = double.tryParse(farePriceData) ?? 0.0;
          } else {
            farePrice = 0.0;
          }

          setState(() {
            availableSeats = availableSeatsList;
            totalSeatCount = totalSeats;
            reservedSeats = reservedSeatsList;
            farePrice = farePrice;
          });
        } else {
          print("No seat data available.");
          reservedSeats = [];
        }
      } else {
        throw Exception('Failed to load bus seats');
      }
    } catch (error) {
      print("Error: $error");
      throw error;
    }
  }

  void onDestinationChanged(String? newValue) async {
    if (newValue != null) {
      var selectedDestination = destinationsData.firstWhere(
        (dest) => dest['display'] == newValue,
        orElse: () => {'trip_id': null, 'display': '', 'fare': 0.0},
      );
      print(selectedDestination);
      setState(() {
        selectedFrom = newValue;
        currentTripId = selectedDestination['trip_id'];
        farePrice = selectedDestination['fare'];
        totalFare = farePrice * selectedSeats.length;
        busNumber = selectedDestination['busNumberData'];
      });

      if (currentTripId != null) {
        await getBusSeats(currentTripId!);
      }
    }
  }

  Future<void> createReservation(
      int tripID,
      String paymentMode,
      String passengerType,
      int numOfPass,
      double totalAmount,
      int driverID,
      int seatNumber,
      DateTime reserveDate) async {
    var link = "http://192.168.56.1/apibus/passenger/api.php";
    final authBox = Hive.box('authBox');
    final token = authBox.get('passenger_id');
    try {
      final jsonData = {
        "trip_id": tripID,
        "paymentMode": paymentMode,
        "passengerType": passengerType,
        "numOfPassenger": numOfPass,
        "totalAmount": totalAmount,
        "driverId": driverID,
        "passengerId": token,
        "seatNumber": seatNumber,
        "reservationDate": DateFormat('yyyy-MM-dd').format(reserveDate)
      };

      print(jsonData);
      final query = {
        "operation": "createReservation",
        "json": jsonEncode(jsonData)
      };

      final response =
          await http.get(Uri.parse(link).replace(queryParameters: query));

      var result = jsonDecode(response.body);

      if (result['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      } else {
        showDialog(
          context: context,
          builder: (context) => ReceiptDialog(
            busNumber: busNumber,
            reservedTime: DateFormat('yyyy-MM-dd').format(reserveDate),
            selectedSeats:
                selectedSeats.map((seat) => seat.toString()).toList(),
            totalPrice: totalAmount,
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Successfully booked the ticket"),
            duration: Duration(seconds: 3),
          ),
        );
        getDestinations();
        setState(() {
          paymentMode = "";
          _numberOfPassenger.text = "1";
          passengerType = "";
          reserveDate = DateTime.now();
        });
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'GoBus',
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Book tickets for your",
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "next trip",
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Destination Dropdown
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "Select Destination",
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedFrom,
                          items: destinationsData.map((dest) {
                            return DropdownMenuItem<String>(
                              value: dest['display'],
                              child: Text(dest['display']),
                            );
                          }).toList(),
                          onChanged: onDestinationChanged,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Payment Type Dropdown
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "Payment Method",
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedPaymentType,
                          hint: const Text("Select payment method"),
                          items: paymentTypes.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedPaymentType = newValue;
                            });
                          },
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Number of Passengers TextField
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "Number of Passengers",
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _numberOfPassenger,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "Enter number",
                            contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "Passenger Type",
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedPassengerType,
                          items: passengerTypes.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedPassengerType = newValue;
                              // You can add logic here to adjust the fare based on passenger type
                              // For example, apply discounts for students or senior citizens
                            });
                          },
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Date Picker
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "Travel Date",
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context),
                          child: IgnorePointer(
                            child: TextField(
                              controller: _dateController,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: "Select date",
                                contentPadding:
                                    EdgeInsets.symmetric(horizontal: 10),
                                suffixIcon: Icon(Icons.calendar_today,
                                    color: Colors.red),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Seat Picker and Total Fare
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SeatPicker(
                              numberOfSeats: totalSeatCount,
                              seatsPerRow: 4,
                              maxSelectableSeats:
                                  int.parse(_numberOfPassenger.text),
                              reservedSeats: reservedSeats,
                              onSeatSelected: (List<int> seats) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  setState(() {
                                    selectedSeats = seats;
                                    totalFare = farePrice *
                                        seats
                                            .length; // Update total fare when seats change
                                  });
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Total Fare: ₱${totalFare.toStringAsFixed(2)}',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                Center(
                  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () {
                        if (selectedFrom == null ||
                            selectedPaymentType == null ||
                            selectedPassengerType == null ||
                            selectedSeats.isEmpty ||
                            selectedDate == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "Please fill in all required fields and select seats"),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        var selectedDestination = destinationsData.firstWhere(
                          (dest) => dest['display'] == selectedFrom,
                          orElse: () => {'trip_id': null, 'driverID': null},
                        );

                        for (int seatNumber in selectedSeats) {
                          createReservation(
                            selectedDestination['trip_id'],
                            selectedPaymentType!,
                            selectedPassengerType!,
                            int.parse(_numberOfPassenger.text),
                            totalFare,
                            selectedDestination['driverID'],
                            seatNumber,
                            selectedDate!,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        backgroundColor: Colors.red,
                      ),
                      child: const Text(
                        "Book Now",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
