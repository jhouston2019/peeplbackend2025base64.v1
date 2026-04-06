import 'package:flutter/material.dart';

import '../../services/merchant_service.dart';
import 'merchant_step_indicator.dart';
import 'merchant_setup_step3_screen.dart';

class MerchantSetupStep2Screen extends StatefulWidget {
  const MerchantSetupStep2Screen({
    super.key,
    this.offerText = '',
    this.venueName = '',
  });

  final String offerText;
  final String venueName;

  @override
  State<MerchantSetupStep2Screen> createState() =>
      _MerchantSetupStep2ScreenState();
}

class _MerchantSetupStep2ScreenState
    extends State<MerchantSetupStep2Screen> {
  static const Color _blue = Color(0xFF1565C0);

  String _tier = 'basic';
  String _slot = 'tonight'; // 'tonight' | 'tomorrow' | 'custom'

  DateTime? _customStart;
  DateTime? _customEnd;

  // ── Derived values ────────────────────────────────────────────────────────

  DateTime get _slotStart {
    if (_slot == 'custom' && _customStart != null) return _customStart!;
    final now = DateTime.now();
    if (_slot == 'tomorrow') {
      return DateTime(now.year, now.month, now.day + 1, 19, 0);
    }
    // tonight 8PM
    return DateTime(now.year, now.month, now.day, 20, 0);
  }

  DateTime get _slotEnd {
    if (_slot == 'custom' && _customEnd != null) return _customEnd!;
    final now = DateTime.now();
    if (_slot == 'tomorrow') {
      return DateTime(now.year, now.month, now.day + 1, 21, 0);
    }
    // tonight 10PM
    return DateTime(now.year, now.month, now.day, 22, 0);
  }

  double get _durationHours {
    final diff = _slotEnd.difference(_slotStart);
    return diff.inMinutes / 60.0;
  }

  double get _totalCost {
    final hours = _durationHours.ceil();
    return MerchantService.estimateFlatRate(_tier, hours);
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
  }

  String get _slotLabel {
    if (_slot == 'custom') {
      if (_customStart != null && _customEnd != null) {
        return '${_formatTime(_customStart!)} – ${_formatTime(_customEnd!)}';
      }
      return 'Custom';
    }
    if (_slot == 'tomorrow') return 'Tomorrow 7–9PM';
    return 'Tonight 8–10PM';
  }

  // ── Time pickers ──────────────────────────────────────────────────────────

  Future<void> _pickCustomTime() async {
    final now = DateTime.now();
    final startDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (startDate == null || !mounted) return;

    final startTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
    );
    if (startTime == null || !mounted) return;

    final endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (startTime.hour + 2) % 24,
        minute: startTime.minute,
      ),
      helpText: 'Select end time',
    );
    if (endTime == null || !mounted) return;

    setState(() {
      _customStart = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        startTime.hour,
        startTime.minute,
      );
      _customEnd = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        endTime.hour,
        endTime.minute,
      );
      // Ensure end is after start.
      if (!_customEnd!.isAfter(_customStart!)) {
        _customEnd = _customStart!.add(const Duration(hours: 1));
      }
    });
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  bool get _canProceed =>
      _slot != 'custom' ||
      (_customStart != null && _customEnd != null);

  void _next() {
    if (!_canProceed) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MerchantSetupStep3Screen(
          offerText: widget.offerText,
          venueName: widget.venueName,
          tier: _tier,
          startTime: _slotStart,
          endTime: _slotEnd,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Choose Time Slot',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: _blue,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: merchantStepIndicator(2),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTierSection(),
                  const SizedBox(height: 24),
                  _buildSlotSection(),
                  const SizedBox(height: 24),
                  _buildSummaryCard(),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canProceed ? _blue : Colors.grey[300],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _canProceed ? _next : null,
                      child: const Text(
                        'Next: Review →',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('SELECT TIER'),
        const SizedBox(height: 10),
        Column(
          children: [
            _tierCard('basic', 'Basic', '\$9.99/hr',
                'Peepl feed placements · 30 min refresh'),
            const SizedBox(height: 10),
            _tierCard('standard', 'Standard', '\$19.99/hr',
                'Feed + Discover · 15 min refresh · Priority'),
            const SizedBox(height: 10),
            _tierCard('premium', 'Premium', '\$39.99/hr',
                'All placements · Real-time · Top priority · Badge'),
          ],
        ),
      ],
    );
  }

  Widget _tierCard(
    String value,
    String label,
    String price,
    String description,
  ) {
    final selected = _tier == value;
    final borderColor = selected ? _blue : Colors.grey.shade200;
    final bgColor = selected
        ? const Color(0xFFE3F2FD)
        : Colors.white;

    return GestureDetector(
      onTap: () => setState(() => _tier = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _blue.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? _blue : Colors.grey.shade400,
                  width: selected ? 2 : 1.5,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: _blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: selected ? _blue : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: selected ? _blue : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('TIME SLOT'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: [
            _slotChip('tonight', 'Tonight 8–10PM'),
            _slotChip('tomorrow', 'Tomorrow 7–9PM'),
            _slotChip('custom', 'Custom'),
          ],
        ),
        if (_slot == 'custom') ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickCustomTime,
            icon: const Icon(Icons.schedule),
            label: Text(
              _customStart != null
                  ? 'Change: $_slotLabel'
                  : 'Pick start & end time',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _blue,
              side: const BorderSide(color: _blue),
            ),
          ),
        ],
      ],
    );
  }

  Widget _slotChip(String value, String label) {
    final selected = _slot == value;
    return GestureDetector(
      onTap: () {
        setState(() => _slot = value);
        if (value == 'custom') _pickCustomTime();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _blue : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? _blue : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          _summaryRow('Venue', widget.venueName),
          const SizedBox(height: 8),
          _summaryRow('Tier', MerchantService.tierLabel(_tier)),
          const SizedBox(height: 8),
          _summaryRow('Slot', _slotLabel),
          const SizedBox(height: 8),
          _summaryRow(
            'Duration',
            '${_durationHours.toStringAsFixed(1)} hrs',
          ),
          const Divider(height: 20),
          _summaryRow(
            'Estimated total',
            '\$${_totalCost.toStringAsFixed(2)}',
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: bold ? const Color(0xFF1B5E20) : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey[500],
        letterSpacing: 1.2,
      ),
    );
  }
}
