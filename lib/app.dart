import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spellbee/core/constants/theme.dart';
import 'package:spellbee/core/data/words_catalog.dart';
import 'package:spellbee/core/utils/responsive.dart';
import 'package:spellbee/providers/providers.dart';
import 'package:spellbee/screens/custom_lists_screen.dart';
import 'package:spellbee/screens/dashboard_screen.dart';
import 'package:spellbee/screens/practice_screen.dart';
import 'package:spellbee/screens/paywall_screen.dart';
import 'package:spellbee/screens/settings_screen.dart';
import 'package:spellbee/screens/stats_screen.dart';
import 'package:spellbee/screens/test_screen.dart';

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
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
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
      routes: {'/paywall': (_) => const PaywallScreen()},
      home: _screenshotHome() ?? const _AppShell(),
    );
  }

  Widget? _screenshotHome() {
    if (Uri.base.queryParameters['screenshot'] != '1') return null;
    final shot = Uri.base.queryParameters['shot'] ?? 'home';
    switch (shot) {
      case 'practice':
        return const _AppShell(forcedTab: AppTab.practice);
      case 'lists':
        return const _AppShell(forcedTab: AppTab.lists);
      case 'stats':
        return const _AppShell(forcedTab: AppTab.stats);
      case 'settings':
        return const _AppShell(forcedTab: AppTab.settings);
      case 'test':
        return TestScreen(
          words: (kWordsCatalog[3] ?? const []).take(5).toList(),
          title: 'Level 3 trial',
          savesStats: false,
        );
      case 'paywall':
        return const PaywallScreen(screenshotMode: true);
      case 'home':
      default:
        return const _AppShell(forcedTab: AppTab.home);
    }
  }
}

class _AppShell extends ConsumerWidget {
  final AppTab? forcedTab;
  const _AppShell({this.forcedTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTab tab = forcedTab ?? ref.watch(tabProvider);
    final screen = KeyedSubtree(key: ValueKey(tab), child: _screenFor(tab));
    if (Uri.base.queryParameters['screenshot'] == '1') {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
          child: screen,
        ),
        bottomNavigationBar: _BottomNav(forcedTab: forcedTab),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.pageGradient),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
              child: child,
            ),
          ),
          child: screen,
        ),
      ),
      bottomNavigationBar: const _BottomNav(),
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

class _BottomNav extends ConsumerWidget {
  final AppTab? forcedTab;

  const _BottomNav({this.forcedTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = forcedTab ?? ref.watch(tabProvider);
    final nav = Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        gradient: AppTheme.navGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outline),
        boxShadow: AppTheme.liftedShadow,
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
            onTap: () => ref.read(tabProvider.notifier).go(AppTab.practice),
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
            onTap: () => ref.read(tabProvider.notifier).go(AppTab.settings),
          ),
        ],
      ),
    );

    if (Uri.base.queryParameters['screenshot'] == '1') {
      return SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          widthFactor: 1,
          heightFactor: 1,
          child: SizedBox(width: responsiveViewportWidth(context), child: nav),
        ),
      );
    }

    return SafeArea(top: false, child: nav);
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
    final color = selected ? AppTheme.ink : AppTheme.mute;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minWidth: 58),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.honey : Colors.transparent,
          gradient: selected ? AppTheme.selectedNavGradient : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected ? AppTheme.softShadow : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
