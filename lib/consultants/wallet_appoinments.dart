import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentDetailsPage extends StatelessWidget {
  final String appointmentId;

  const AppointmentDetailsPage({Key? key, required this.appointmentId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('consultant_appointments')
            .doc(appointmentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Appointment ID',
                            '#${appointmentId.padLeft(8, '0')}'),
                        const Divider(),
                        _buildDetailRow('Amount',
                            'R${data['amount']?.toString() ?? '0.00'}'),
                        const Divider(),
                        _buildDetailRow('Date', data['jobDate'] ?? 'N/A'),
                        const Divider(),
                        _buildDetailRow('Time', data['jobTime'] ?? 'N/A'),
                        const Divider(),
                        _buildDetailRow(
                            'Location', data['siteLocation'] ?? 'N/A'),
                        const Divider(),
                        _buildDetailRow(
                            'Client Name', data['clientName'] ?? 'N/A'),
                        const Divider(),
                        _buildDetailRow('Status', data['status'] ?? 'N/A'),
                        const Divider(),
                        _buildDetailRow(
                            'Payment Status', data['settled'] ?? 'N/A'),
                      ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF004AAD),
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
