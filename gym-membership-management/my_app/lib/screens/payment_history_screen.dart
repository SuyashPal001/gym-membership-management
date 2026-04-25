import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/payment_models.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../constants/app_colors.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final String memberId;
  final String memberName;

  const PaymentHistoryScreen({
    Key? key,
    required this.memberId,
    required this.memberName,
  }) : super(key: key);

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  List<MemberPayment> _payments = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _payments = await ApiService.fetchMemberPayments(widget.memberId);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to load payment history';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "PAYMENT HISTORY",
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.secondaryText)),
                      TextButton(
                        onPressed: _loadHistory,
                        child: const Text('Retry', style: TextStyle(color: AppColors.accent)),
                      ),
                    ],
                  ),
                )
              : _payments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 48, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 16),
                          Text(
                            "No payment records found",
                            style: GoogleFonts.outfit(color: AppColors.secondaryText, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: _payments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildPaymentCard(_payments[index]);
                      },
                    ),
    );
  }

  Widget _buildPaymentCard(MemberPayment payment) {
    final dt = DateTime.tryParse(payment.paymentDate);
    final dateMonth = dt != null ? DateFormat('MMM').format(dt) : '—';
    final dateDay = dt != null ? DateFormat('d').format(dt) : '—';
    final yearStr = dt != null ? DateFormat('yyyy').format(dt) : '';
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Date Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.emerald.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.emerald.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Text(
                  dateMonth.toUpperCase(),
                  style: GoogleFonts.outfit(color: AppColors.emerald, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
                Text(
                  dateDay,
                  style: GoogleFonts.outfit(color: AppColors.emerald, fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.planName ?? "Membership Payment",
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      yearStr,
                      style: GoogleFonts.outfit(color: AppColors.secondaryText, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(
                      (payment.method ?? 'ONLINE').toUpperCase(),
                      style: GoogleFonts.outfit(color: AppColors.primaryBlue.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "₹${NumberFormat('#,###').format(payment.amount.toInt())}",
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              Text(
                "PAID",
                style: GoogleFonts.outfit(color: AppColors.emerald, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
