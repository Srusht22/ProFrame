import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/product_select/presentation/product_select_screen.dart';
import '../features/projects/presentation/projects_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({super.key});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    final screens = [
      HomeScreen(onNavigateTab: (index) => setState(() => _currentIndex = index)),
      const ProjectsScreen(),
      const ProductSelectScreen(),
      const SettingsScreen(),
    ];

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: AppTheme.surface,
              selectedIndex: _currentIndex,
              onDestinationSelected: (val) => setState(() => _currentIndex = val),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'PF',
                          style: TextStyle(
                            color: AppTheme.onPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded, color: AppTheme.primary),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder_rounded, color: AppTheme.primary),
                  label: Text('Projects'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.category_outlined),
                  selectedIcon: Icon(Icons.category_rounded, color: AppTheme.primary),
                  label: Text('Products'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded, color: AppTheme.primary),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppTheme.surfaceBorder),
            Expanded(child: screens[_currentIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.surfaceBorder, width: 1)),
        ),
        child: NavigationBar(
          backgroundColor: AppTheme.surface,
          selectedIndex: _currentIndex,
          onDestinationSelected: (val) => setState(() => _currentIndex = val),
          indicatorColor: AppTheme.primary.withOpacity(0.18),
          destinations: const [
            NavigationRequestDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: AppTheme.primary),
              label: 'Home',
            ),
            NavigationRequestDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder_rounded, color: AppTheme.primary),
              label: 'Projects',
            ),
            NavigationRequestDestination(
              icon: Icon(Icons.category_outlined),
              selectedIcon: Icon(Icons.category_rounded, color: AppTheme.primary),
              label: 'Products',
            ),
            NavigationRequestDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded, color: AppTheme.primary),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationRequestDestination extends NavigationDestination {
  const NavigationRequestDestination({
    super.key,
    required super.icon,
    super.selectedIcon,
    required super.label,
  });
}
