import 'package:flutter/material.dart';

/// The viewer's choice from the sleep-timer sheet.
///
/// [minutes] is null when they turned the timer off, a positive count of
/// minutes, or `-1` when playback should stop at the end of this episode
/// instead of starting the next one.
class SleepTimerPick {
  final int? minutes;

  const SleepTimerPick(this.minutes);
}

/// Label for the player button. Shared so VLC and MediaKit read the same.
String sleepTimerLabel(int? minutes) {
  if (minutes == null) return 'Sleep timer';
  if (minutes < 0) return 'Sleep timer: end of episode';
  return 'Sleep timer: $minutes m';
}

/// Bottom sheet of sleep-timer choices.
///
/// Returns null when the sheet is dismissed, so the current timer stays.
/// [SleepTimerPick.minutes] is null when the viewer picks Off.
Future<SleepTimerPick?> showSleepTimerSheet(
  BuildContext context, {
  required int? selected,
  required bool allowEndOfEpisode,
}) {
  return showModalBottomSheet<SleepTimerPick>(
    context: context,
    backgroundColor: const Color(0xFF0D0F18),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Sleep timer',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
            _SleepOption(label: 'Off', minutes: null, selected: selected),
            _SleepOption(label: '15 minutes', minutes: 15, selected: selected),
            _SleepOption(label: '30 minutes', minutes: 30, selected: selected),
            _SleepOption(label: '45 minutes', minutes: 45, selected: selected),
            _SleepOption(label: '60 minutes', minutes: 60, selected: selected),
            if (allowEndOfEpisode)
              _SleepOption(
                label: 'End of this episode',
                minutes: -1,
                selected: selected,
              ),
          ],
        ),
      ),
    ),
  );
}

class _SleepOption extends StatelessWidget {
  final String label;
  final int? minutes;
  final int? selected;

  const _SleepOption({
    required this.label,
    required this.minutes,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == minutes;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFF818CF8) : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFF818CF8))
          : null,
      onTap: () => Navigator.pop(context, SleepTimerPick(minutes)),
    );
  }
}
