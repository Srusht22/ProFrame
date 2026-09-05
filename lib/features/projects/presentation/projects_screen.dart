import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../../data/repositories/project_repository_impl.dart';
import '../../../../domain/configuration/product_configuration.dart';
import '../../../../domain/repositories/i_project_repository.dart';
import '../../configurator_3d/presentation/configurator_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final IProjectRepository _repository = ProjectRepositoryImpl();
  List<ProductConfiguration> _projects = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    final list = await _repository.getAllProjects();
    if (mounted) {
      setState(() {
        _projects = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _duplicateProject(ProductConfiguration project) async {
    final dup = await _repository.duplicateProject(project.id);
    await _loadProjects();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Duplicated "${project.projectName}"'),
          backgroundColor: AppTheme.accentSuccess,
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ConfiguratorScreen(initialConfig: dup)),
      ).then((_) => _loadProjects());
    }
  }

  Future<void> _renameProject(ProductConfiguration project) async {
    final controller = TextEditingController(text: project.projectName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Rename Design'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Project Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != project.projectName) {
      final updated = project.copyWith(projectName: newName);
      await _repository.saveProject(updated);
      _loadProjects();
    }
  }

  Future<void> _deleteProject(ProductConfiguration project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Delete Design?'),
        content: Text('Are you sure you want to delete "${project.projectName}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentDanger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.deleteProject(project.id);
      _loadProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _projects.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.projectName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.style.label.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.frameColor.label.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Saved Projects'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              // Search Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by client, style, or color...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

              // Project List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                    : filtered.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              return _buildProjectCard(filtered[index]);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.folder_open_rounded, size: 48, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          const Text(
            'No projects found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create your first design to replace paper sketches',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(ProductConfiguration project) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ConfiguratorScreen(initialConfig: project)),
          ).then((_) => _loadProjects());
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 3D Thumbnail / Preview Box
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: project.thumbnailBase64 != null
                    ? _buildThumbnailImage(project.thumbnailBase64!)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.view_in_ar_rounded, size: 30, color: AppTheme.primary.withOpacity(0.7)),
                            const SizedBox(height: 4),
                            Text(
                              '${project.sections} Panel',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 16),

              // Project Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.projectName,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.formattedDimensions(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.summaryDescription,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Actions Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
                color: AppTheme.surfaceElevated,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (action) {
                  if (action == 'open') {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ConfiguratorScreen(initialConfig: project)),
                    ).then((_) => _loadProjects());
                  } else if (action == 'duplicate') {
                    _duplicateProject(project);
                  } else if (action == 'rename') {
                    _renameProject(project);
                  } else if (action == 'delete') {
                    _deleteProject(project);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'open', child: Row(children: [Icon(Icons.open_in_new, size: 18), SizedBox(width: 10), Text('Open in 3D')])),
                  const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy_rounded, size: 18), SizedBox(width: 10), Text('Duplicate')])),
                  const PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 10), Text('Rename')])),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.accentDanger),
                      SizedBox(width: 10),
                      Text('Delete', style: TextStyle(color: AppTheme.accentDanger)),
                    ]),
                  ),
                ],
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
}
