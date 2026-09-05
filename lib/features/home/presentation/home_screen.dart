import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/repositories/project_repository_impl.dart';
import '../../../../domain/configuration/product_configuration.dart';
import '../../../../domain/repositories/i_project_repository.dart';
import '../../configurator_3d/presentation/configurator_screen.dart';
import '../../product_select/presentation/product_select_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const HomeScreen({super.key, required this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final IProjectRepository _repository = ProjectRepositoryImpl();
  List<ProductConfiguration> _recentProjects = [];
  List<ProductConfiguration> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final projects = await _repository.getAllProjects();
    final templates = await _repository.getTemplates();
    if (mounted) {
      setState(() {
        _recentProjects = projects;
        _templates = templates;
        _isLoading = false;
      });
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) {
      return 'Edited ${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return 'Edited ${diff.inHours}h ago';
    } else {
      return 'Edited ${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good ${_getTimeGreeting()}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              AppConstants.appName,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.0,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.accentSuccess.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.accentSuccess.withOpacity(0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off_rounded, size: 14, color: AppTheme.accentSuccess),
                              SizedBox(width: 6),
                              Text(
                                'Offline Mode',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accentSuccess,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // LARGE PRIMARY ACTION CARD: "+ New Design"
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ProductSelectScreen()),
                          ).then((_) => _loadData());
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0284C7).withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.add_rounded, size: 36, color: Colors.white),
                              ),
                              const SizedBox(width: 20),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '+ New Design',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Replace paper sketch with interactive 3D in 30 seconds',
                                      style: TextStyle(fontSize: 13, color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // FACTORY TEMPLATES / PRESETS
                    const Text(
                      'QUICK TEMPLATES',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _templates.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final template = _templates[index];
                          return _buildTemplateCard(template);
                        },
                      ),
                    ),

                    const SizedBox(height: 36),

                    // RECENT DESIGNS HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'RECENT DESIGNS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => widget.onNavigateTab(1), // Go to projects tab
                          child: const Text('View All', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // RECENT DESIGNS LIST
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(color: AppTheme.primary),
                        ),
                      )
                    else if (_recentProjects.isEmpty)
                      _buildEmptyRecentCard()
                    else
                      ..._recentProjects.take(4).map((p) => _buildRecentProjectCard(p)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard(ProductConfiguration template) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final now = DateTime.now();
          final cloned = template.copyWith(
            id: 'design_${now.millisecondsSinceEpoch}',
            projectName: '${template.projectName} Copy',
            createdAt: now,
            updatedAt: now,
          );
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ConfiguratorScreen(initialConfig: cloned)),
          ).then((_) => _loadData());
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(template.style.icon, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      template.projectName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                template.formattedDimensions(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary),
              ),
              const SizedBox(height: 2),
              Text(
                '${template.sections} Sections • ${template.frameColor.label}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentProjectCard(ProductConfiguration project) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ConfiguratorScreen(initialConfig: project)),
          ).then((_) => _loadData());
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Thumbnail Box
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: project.thumbnailBase64 != null
                    ? _buildThumbnailImage(project.thumbnailBase64!)
                    : Center(
                        child: Icon(Icons.view_in_ar_rounded, size: 28, color: AppTheme.primary.withOpacity(0.8)),
                      ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.projectName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.formattedDimensions(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          project.summaryDescription,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${_formatTimeAgo(project.updatedAt)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Continue Button
              FilledButton.tonal(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ConfiguratorScreen(initialConfig: project)),
                  ).then((_) => _loadData());
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.surfaceElevated,
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnailImage(String base64String) {
    try {
      final clean = base64String.contains(',') ? base64String.split(',')[1] : base64String;
      final bytes = base64Decode(clean);
      return Image.memory(bytes, fit: BoxFit.cover);
    } catch (_) {
      return const Center(child: Icon(Icons.image_not_supported_rounded, color: AppTheme.textMuted));
    }
  }

  Widget _buildEmptyRecentCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.draw_outlined, size: 40, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text(
              'No designs created yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            SizedBox(height: 4),
            Text(
              'Tap "+ New Design" above to configure your first product',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}
