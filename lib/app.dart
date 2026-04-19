import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/custom_lists_screen.dart';
import 'package:spellbee/screens/dashboard_screen.dart';
import 'package:spellbee/screens/practice_screen.dart';
import 'package:spellbee/screens/settings_screen.dart';
import 'package:spellbee/screens/stats_screen.dart';

class SpellBeeApp extends ConsumerStatefulWidget {
  const SpellBeeApp({super.key});

  @override
  ConsumerState<SpellBeeApp> createState() => _SpellBeeAppState();
}

class _SpellBeeAppState extends ConsumerState<SpellBeeApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(iapServiceProvider).onPurchaseSuccess = (productId) {
        ref.read(premiumProvider.notifier).activate(productId);
        final ctx = _scaffoldMessenger.currentContext;
        if (ctx != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text('Premium unlocked. Thank you!')),
          );
        }
      };
      ref.read(iapServiceProvider).onPurchaseError = (msg) {
        final ctx = _scaffoldMessenger.currentContext;
        if (ctx != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      };
    });
  }

  final _scaffoldMessenger = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpellBee',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scaffoldMessengerKey: _scaffoldMessenger,
      home: const _AppShell(),
    );
  }
}

class _AppShell extends ConsumerWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabProvider);
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(tab),
          child: _screenFor(tab),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _BannerAdSlot(),
          _BottomNav(),
        ],
      ),
    );
  }

  Widget _screenFor(AppTab t) {
    switch (t) {
      case AppTab.home:
        return const DashboardScreen();
      case AppTab.practice:
        return const PracticeScreen();
      case AppTab.lists:
        return const CustomListsScreen();
      case AppTab.stats:
        return const StatsScreen();
      case AppTab.settings:
        return const SettingsScreen();
    }
  }
}

class _BannerAdSlot extends ConsumerWidget {
  const _BannerAdSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    if (isPremium) return const SizedBox.shrink();
    final ad = ref.watch(adServiceProvider).buildBanner();
    if (ad == null) return const SizedBox.shrink();
    return Center(child: ad);
  }
}

class _BottomNav extends ConsumerWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabProvider);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.outline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: tab == AppTab.home,
              onTap: () => ref.read(tabProvider.notifier).go(AppTab.home),
            ),
            _NavItem(
              icon: Icons.auto_awesome_rounded,
              label: 'Practice',
              selected: tab == AppTab.practice,
              onTap: () =>
                  ref.read(tabProvider.notifier).go(AppTab.practice),
            ),
            _NavItem(
              icon: Icons.library_books_rounded,
              label: 'Lists',
              selected: tab == AppTab.lists,
              onTap: () => ref.read(tabProvider.notifier).go(AppTab.lists),
            ),
            _NavItem(
              icon: Icons.timeline_rounded,
              label: 'Stats',
              selected: tab == AppTab.stats,
              onTap: () => ref.read(tabProvider.notifier).go(AppTab.stats),
            ),
            _NavItem(
              icon: Icons.settings_rounded,
              label: 'You',
              selected: tab == AppTab.settings,
              onTap: () =>
                  ref.read(tabProvider.notifier).go(AppTab.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.honeyDark : AppTheme.mute;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? AppTheme.honey.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
