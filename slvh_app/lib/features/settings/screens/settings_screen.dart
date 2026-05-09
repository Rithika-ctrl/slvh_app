import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../models/shop_settings_model.dart';
import '../services/settings_service.dart';

/// Admin Settings Screen — Phase 4, Step 22
///
/// Lets the admin configure shop timings, slot settings, UPI payment info,
/// operational toggles (holiday mode / order pause), and low-stock threshold
/// without any code changes.  All values are persisted to Firestore
/// `settings/default` and read in real-time by the customer app.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _service = SettingsService.instance;
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ───────────────────────────────────────────────
  late TextEditingController _upiIdCtrl;
  late TextEditingController _upiQrCtrl;
  late TextEditingController _lowStockCtrl;

  // ── State ─────────────────────────────────────────────────────
  ShopSettingsModel? _settings;
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  // Time / slot fields (stored as local int state)
  int _openTime = 9;
  int _closeTime = 21;
  int _pickupStart = 9;
  int _delayHours = 1;
  int _slotDuration = 30;
  int _slotCapacity = 5;
  bool _holidayMode = false;
  bool _orderPause = false;

  @override
  void initState() {
    super.initState();
    _upiIdCtrl = TextEditingController();
    _upiQrCtrl = TextEditingController();
    _lowStockCtrl = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _upiIdCtrl.dispose();
    _upiQrCtrl.dispose();
    _lowStockCtrl.dispose();
    super.dispose();
  }

  // ── Load ──────────────────────────────────────────────────────

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final s = await _service.getSettings();
      _applySettings(s);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load settings: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applySettings(ShopSettingsModel s) {
    setState(() {
      _settings = s;
      _openTime = s.openTime;
      _closeTime = s.closeTime;
      _pickupStart = s.pickupStart;
      _delayHours = s.delayHours;
      _slotDuration = s.slotDuration;
      _slotCapacity = s.slotCapacity;
      _holidayMode = s.holidayMode;
      _orderPause = s.orderPause;
      _upiIdCtrl.text = s.upiId;
      _upiQrCtrl.text = s.upiQrImage;
      _lowStockCtrl.text = s.lowStockThreshold.toString();
    });
  }

  // ── Save ──────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final updated = ShopSettingsModel(
        id: _settings?.id ?? 'default',
        openTime: _openTime,
        closeTime: _closeTime,
        pickupStart: _pickupStart,
        delayHours: _delayHours,
        slotDuration: _slotDuration,
        slotCapacity: _slotCapacity,
        upiId: _upiIdCtrl.text.trim(),
        upiQrImage: _upiQrCtrl.text.trim(),
        holidayMode: _holidayMode,
        orderPause: _orderPause,
        lowStockThreshold: int.tryParse(_lowStockCtrl.text) ?? 5,
      );
      await _service.saveSettings(updated);
      setState(() => _settings = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Save failed: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────

  String _formatHour(int hour) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour < 12 ? 'AM' : 'PM';
    return '$h:00 $suffix';
  }

  Future<void> _pickTime(
    String label,
    int current,
    ValueChanged<int> onPicked,
  ) async {
    final initialTime =
        TimeOfDay(hour: current, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Select $label',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.orange,
            onPrimary: Colors.white,
            onSurface: AppColors.textDark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked.hour);
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        backgroundColor: AppColors.bgCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Shop Settings',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: _saving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.orange,
                      ),
                    )
                  : FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppSpacing.buttonRadius),
                        ),
                      ),
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Save'),
                    ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.orange))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                children: [
                  if (_errorMessage != null) _buildErrorBanner(),
                  _buildSection(
                    icon: Icons.access_time_rounded,
                    title: 'Operating Hours',
                    children: [
                      _buildTimeRow(
                        label: 'Opening Time',
                        hour: _openTime,
                        onTap: () => _pickTime(
                          'Opening Time',
                          _openTime,
                          (h) => setState(() => _openTime = h),
                        ),
                      ),
                      const Divider(height: 1),
                      _buildTimeRow(
                        label: 'Closing Time',
                        hour: _closeTime,
                        onTap: () => _pickTime(
                          'Closing Time',
                          _closeTime,
                          (h) => setState(() => _closeTime = h),
                        ),
                      ),
                      const Divider(height: 1),
                      _buildTimeRow(
                        label: 'Pickup Start Time',
                        hour: _pickupStart,
                        onTap: () => _pickTime(
                          'Pickup Start',
                          _pickupStart,
                          (h) => setState(() => _pickupStart = h),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildSection(
                    icon: Icons.grid_view_rounded,
                    title: 'Slot Configuration',
                    children: [
                      _buildStepperRow(
                        label: 'Min Delay Before Pickup',
                        value: _delayHours,
                        unit: 'hrs',
                        min: 0,
                        max: 72,
                        onChanged: (v) => setState(() => _delayHours = v),
                      ),
                      const Divider(height: 1),
                      _buildStepperRow(
                        label: 'Slot Duration',
                        value: _slotDuration,
                        unit: 'min',
                        min: 15,
                        max: 120,
                        step: 15,
                        onChanged: (v) => setState(() => _slotDuration = v),
                      ),
                      const Divider(height: 1),
                      _buildStepperRow(
                        label: 'Slot Capacity',
                        value: _slotCapacity,
                        unit: 'orders',
                        min: 1,
                        max: 50,
                        onChanged: (v) => setState(() => _slotCapacity = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildSection(
                    icon: Icons.currency_rupee_rounded,
                    title: 'UPI Payment',
                    children: [
                      _buildTextField(
                        controller: _upiIdCtrl,
                        label: 'UPI ID',
                        hint: 'e.g. shop@okhdfcbank',
                        icon: Icons.alternate_email_rounded,
                        validator: (v) {
                          if (v != null && v.isNotEmpty && !v.contains('@')) {
                            return 'Enter a valid UPI ID (must contain @)';
                          }
                          return null;
                        },
                      ),
                      const Divider(height: 1),
                      _buildTextField(
                        controller: _upiQrCtrl,
                        label: 'UPI QR Image URL',
                        hint: 'https://... or leave blank',
                        icon: Icons.qr_code_2_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildSection(
                    icon: Icons.toggle_on_rounded,
                    title: 'Operational Toggles',
                    children: [
                      _buildToggleRow(
                        label: 'Holiday Mode',
                        subtitle:
                            'Disables all pickup slots when enabled',
                        icon: Icons.beach_access_rounded,
                        iconColor: AppColors.catBlue,
                        value: _holidayMode,
                        onChanged: (v) => setState(() => _holidayMode = v),
                      ),
                      const Divider(height: 1),
                      _buildToggleRow(
                        label: 'Pause Orders',
                        subtitle: 'Stops customers from placing new orders',
                        icon: Icons.pause_circle_rounded,
                        iconColor: AppColors.error,
                        value: _orderPause,
                        onChanged: (v) => setState(() => _orderPause = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildSection(
                    icon: Icons.inventory_2_rounded,
                    title: 'Inventory Alerts',
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: TextFormField(
                          controller: _lowStockCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: InputDecoration(
                            labelText: 'Low Stock Threshold',
                            hintText: '5',
                            helperText:
                                'Show alert when stock falls to or below this quantity',
                            prefixIcon: const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.warning,
                            ),
                            filled: true,
                            fillColor: AppColors.orangePale,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.inputRadius),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.inputRadius),
                              borderSide: const BorderSide(
                                  color: AppColors.orange, width: 1.5),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please enter a threshold';
                            }
                            final n = int.tryParse(v);
                            if (n == null || n < 0) {
                              return 'Enter a valid non-negative integer';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
    );
  }

  // ── Section wrapper ───────────────────────────────────────────

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.orange, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border.all(color: AppColors.cardBorder),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  // ── Row widgets ───────────────────────────────────────────────

  Widget _buildTimeRow({
    required String label,
    required int hour,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.orangePale,
                borderRadius:
                    BorderRadius.circular(AppSpacing.buttonRadius),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatHour(hour),
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more_rounded,
                      color: AppColors.orange, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperRow({
    required String label,
    required int value,
    required String unit,
    required int min,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _StepperControl(
            value: value,
            unit: unit,
            min: min,
            max: max,
            step: step,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: TextFormField(
        controller: controller,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.textMuted),
          filled: true,
          fillColor: AppColors.orangePale,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            borderSide:
                const BorderSide(color: AppColors.orange, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            borderSide:
                const BorderSide(color: AppColors.error, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        border: Border.all(color: AppColors.error.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.error),
            onPressed: () => setState(() => _errorMessage = null),
          ),
        ],
      ),
    );
  }
}

// ── Stepper control widget ────────────────────────────────────────

class _StepperControl extends StatelessWidget {
  const _StepperControl({
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  final int value;
  final String unit;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(
          icon: Icons.remove,
          enabled: value > min,
          onTap: () => onChanged((value - step).clamp(min, max)),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 64),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.orangePale,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Text(
            '$value $unit',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.orange,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        _btn(
          icon: Icons.add,
          enabled: value < max,
          onTap: () => onChanged((value + step).clamp(min, max)),
        ),
      ],
    );
  }

  Widget _btn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.orange.withOpacity(0.12)
              : AppColors.bgCreamLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.orange : AppColors.textHint,
        ),
      ),
    );
  }
}