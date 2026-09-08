import 'package:flutter/material.dart';

/// There is currently nothing in the app that generates a notification
/// — no reminders, no push, no background jobs. Rather than fabricate
/// placeholder notifications to make this screen look "done," it shows
/// a real, honest empty state. When a real notification source exists
/// (e.g. "you have 3 unconfirmed drafts older than a week," or a
/// push-based "X added a receipt to your shared group" once cloud sync
/// lands), this becomes a normal list screen fed by whatever repository
/// stores those notifications — the empty state below is simply what
/// that same screen shows when the list is empty.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No notifications yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'You\'ll see updates about your bills and groups here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
