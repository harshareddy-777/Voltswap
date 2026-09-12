import 'package:flutter/material.dart';

import '../models/station.dart';
import '../models/station_slot.dart';
import '../services/station_service.dart';

class ManageStationScreen extends StatefulWidget {
  const ManageStationScreen({super.key, required this.station});
  final Station station;

  @override
  State<ManageStationScreen> createState() => _ManageStationScreenState();
}

class _ManageStationScreenState extends State<ManageStationScreen> {
  final _service = StationService();
  final _slotIdController = TextEditingController();
  final _chargeController = TextEditingController();
  final _slotFormKey = GlobalKey<FormState>();
  bool _batteryPresent = true;
  String? _selectedBatteryType;
  late String _status;
  List<StationSlot>? _slots;

  @override
  void initState() {
    super.initState();
    _status = widget.station.status;
    _fetchSlots();
  }

  @override
  void dispose() {
    _slotIdController.dispose();
    _chargeController.dispose();
    super.dispose();
  }

  Future<void> _toggleStatus() async {
    try {
      final next = _status == 'active' ? 'offline' : 'active';
      await _service.setStationStatus(
        stationId: widget.station.stationId,
        status: next,
      );
      if (!mounted) return;
      setState(() => _status = next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  Future<void> _addSlot() async {
    try {
      final slotId = _slotIdController.text.trim();
      final charge = int.tryParse(_chargeController.text.trim());
      if (!_slotFormKey.currentState!.validate()) {
        return;
      }
      await _service.addSlot(
        stationId: widget.station.stationId,
        slotId: slotId,
        chargePercentage: charge!,
        batteryPresent: _batteryPresent,
        batteryType: _selectedBatteryType,
      );
      _slotIdController.clear();
      _chargeController.clear();
      _selectedBatteryType = null;
      await _fetchSlots();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add slot: $e')));
    }
  }

  Future<void> _fetchSlots() async {
    try {
      final stationId = widget.station.stationId.trim();
      // ignore: avoid_print
      print('Fetching slots for: $stationId');
      final fetchedSlots = await _service.getSlots(widget.station.stationId);
      debugPrint(
        'ManageStation fetched ${fetchedSlots.length} slots for ${widget.station.stationId}',
      );
      if (!mounted) return;
      setState(() {
        _slots = fetchedSlots;
      });
    } catch (e) {
      debugPrint('ManageStation _fetchSlots error: $e');
      if (!mounted) return;
      setState(() {
        _slots = <StationSlot>[];
      });
    }
  }

  Future<void> _deleteSlot(String slotId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Slot'),
        content: Text('Are you sure you want to delete slot $slotId?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await _service.deleteSlot(
        stationId: widget.station.stationId,
        slotId: slotId,
      );
      await _fetchSlots();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slot deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete slot: $e')));
    }
  }

  Future<void> _showEditSlotDialog(StationSlot slot) async {
    final slotIdController = TextEditingController(text: slot.slotId);
    final chargeController = TextEditingController(
      text: slot.chargePercentage.toString(),
    );
    bool batteryPresent = slot.batteryPresent;
    String? selectedBatteryType = slot.batteryType;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Slot'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: slotIdController,
                decoration: const InputDecoration(labelText: 'Slot ID'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Slot ID required'
                    : null,
              ),
              TextFormField(
                controller: chargeController,
                decoration: const InputDecoration(labelText: 'Charge %'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  final number = int.tryParse(text);
                  if (text.isEmpty || number == null) {
                    return 'Valid charge required';
                  }
                  if (number < 0 || number > 100) {
                    return '0-100 only';
                  }
                  return null;
                },
              ),
              CheckboxListTile(
                title: const Text('Battery Present'),
                value: batteryPresent,
                onChanged: (val) => batteryPresent = val ?? false,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              StatefulBuilder(
                builder: (context, setState) => DropdownButtonFormField<String>(
                  initialValue: selectedBatteryType,
                  decoration: const InputDecoration(
                    labelText: 'Battery Type',
                    prefixIcon: Icon(Icons.battery_std_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('None')),
                    DropdownMenuItem(value: 'LFP', child: Text('LFP')),
                    DropdownMenuItem(value: 'NMC', child: Text('NMC')),
                    DropdownMenuItem(value: 'NMA', child: Text('NMA')),
                  ],
                  onChanged: (value) => selectedBatteryType = value,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              final newSlotId = slotIdController.text.trim();
              final newCharge = int.parse(chargeController.text.trim());
              try {
                await _service.updateSlot(
                  stationId: widget.station.stationId,
                  oldSlotId: slot.slotId,
                  newSlotId: newSlotId,
                  chargePercentage: newCharge,
                  batteryPresent: batteryPresent,
                  batteryType: selectedBatteryType,
                );
                Navigator.pop(context);
                await _fetchSlots();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Slot updated successfully')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update slot: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Manage ${widget.station.stationId}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              value: _status == 'active',
              title: const Text('Station Status'),
              subtitle: Text(_status.toUpperCase()),
              onChanged: (_) => _toggleStatus(),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Add Slot', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Form(
            key: _slotFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _slotIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'slot_id'),
                  validator: (value) {
                    final input = value?.trim() ?? '';
                    if (input.isEmpty) {
                      return 'Slot ID is required';
                    }
                    if (int.tryParse(input) == null) {
                      return 'slot_id must be an integer';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _chargeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'charge_percentage',
                  ),
                  validator: (value) {
                    final input = value?.trim() ?? '';
                    if (input.isEmpty) {
                      return 'Charge percentage is required';
                    }
                    final charge = int.tryParse(input);
                    if (charge == null) {
                      return 'charge_percentage must be an integer';
                    }
                    if (charge < 0 || charge > 100) {
                      return 'charge_percentage must be between 0 and 100';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          CheckboxListTile(
            value: _batteryPresent,
            onChanged: (value) =>
                setState(() => _batteryPresent = value ?? false),
            title: const Text('battery_present'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedBatteryType,
            decoration: const InputDecoration(
              labelText: 'Battery Type',
              prefixIcon: Icon(Icons.battery_std_outlined),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('None')),
              DropdownMenuItem(value: 'LFP', child: Text('LFP')),
              DropdownMenuItem(value: 'NMC', child: Text('NMC')),
              DropdownMenuItem(value: 'NMA', child: Text('NMA')),
            ],
            onChanged: (value) => setState(() => _selectedBatteryType = value),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _addSlot,
            child: const Text('Add / Update Slot'),
          ),
          const SizedBox(height: 14),
          const Text(
            'Current Slots',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_slots == null)
            const Center(child: CircularProgressIndicator())
          else if (_slots!.isEmpty)
            const Text('No slots found')
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _slots!.length,
              itemBuilder: (context, index) {
                final slot = _slots![index];
                return Card(
                  child: ListTile(
                    title: Text('slot_id: ${slot.slotId}'),
                    subtitle: Text(
                      'charge_percentage: ${slot.chargePercentage}\n'
                      'battery_present: ${slot.batteryPresent}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit Slot',
                          onPressed: () => _showEditSlotDialog(slot),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: 'Delete Slot',
                          onPressed: () => _deleteSlot(slot.slotId),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _fetchSlots,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Slots'),
          ),
        ],
      ),
    );
  }
}
