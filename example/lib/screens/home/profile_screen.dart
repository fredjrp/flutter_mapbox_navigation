import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/trip_service.dart';
import '../../models/user_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.appUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => _confirmSignOut(context, auth),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: const Color(0xFF1A73E8),
                      backgroundImage: user?.photoUrl != null
                          ? NetworkImage(user!.photoUrl!)
                          : null,
                      child: user?.photoUrl == null
                          ? Text(
                              (user?.displayName ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 28,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Loading...',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          if (user?.createdAt != null)
                            Text(
                              'Joined ${DateFormat('MMM yyyy').format(user!.createdAt)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Stats
            Row(
              children: [
                Expanded(
                    child: _StatCard(
                        label: 'Total Trips',
                        value: '${user?.totalTrips ?? 0}',
                        icon: Icons.route)),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatCard(
                        label: 'Items Collected',
                        value: '${user?.totalItemsCollected ?? 0}',
                        icon: Icons.inventory_2)),
              ],
            ),
            const SizedBox(height: 20),
            // Trip History
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Trip History',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            if (user != null) _TripHistoryList(userId: user.uid),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AuthService auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                auth.signOut();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sign Out')),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF1A73E8), size: 32),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _TripHistoryList extends StatelessWidget {
  final String userId;
  const _TripHistoryList({required this.userId});

  @override
  Widget build(BuildContext context) {
    final tripService = TripService();
    return StreamBuilder<List<TripRecord>>(
      stream: tripService.userTripsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final trips = snapshot.data ?? [];
        if (trips.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('No trips yet.\nStart navigating to collect items!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: trips.length,
          itemBuilder: (context, i) => _TripTile(trip: trips[i]),
        );
      },
    );
  }
}

class _TripTile extends StatelessWidget {
  final TripRecord trip;
  const _TripTile({required this.trip});

  @override
  Widget build(BuildContext context) {
    final statusColor = trip.status == 'completed'
        ? Colors.green
        : trip.status == 'active'
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.15),
          child: Icon(
            trip.status == 'completed'
                ? Icons.check_circle
                : trip.status == 'active'
                    ? Icons.navigation
                    : Icons.cancel,
            color: statusColor,
          ),
        ),
        title: Text(trip.storeNames.join(' → '),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${trip.itemCount} items · ${trip.storeIds.length} stores'),
            Text(DateFormat('dd MMM yyyy, HH:mm').format(trip.startedAt),
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        trailing: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.4)),
          ),
          child: Text(trip.status.toUpperCase(),
              style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
        isThreeLine: true,
      ),
    );
  }
}
