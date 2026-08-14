import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/document.dart';
import '../models/reminder.dart';
import '../providers/document_provider.dart';
import '../theme/app_theme.dart';

class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({super.key});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final TransformationController _transformController =
      TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  static const _notifyLabels = {
    0: 'On the day',
    1: '1 day before',
    3: '3 days before',
    7: '1 week before',
  };

  @override
  Widget build(BuildContext context) {
    final document =
        ModalRoute.of(context)!.settings.arguments as Document;
    final provider = Provider.of<DocumentProvider>(context);
    final reminder = provider.getReminderForDocument(document.id);
    final badgeStyle = BadgeStyles.getBadgeStyle(document.priority);

    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                document.title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _categoryBadge(document.category),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppColors.textPrimary),
            onPressed: () {
              // Placeholder — share not yet implemented
            },
            tooltip: 'Share',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(Icons.edit, size: 16, color: Colors.white),
              label: const Text(
                'Edit',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              backgroundColor: AppColors.informationalBadgeText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/edit',
                  arguments: document,
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Zoomable document image ──
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 1.0,
                  maxScale: 5.0,
                  child: Center(
                    child: Image.file(
                      File(document.imagePath),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 64,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Image not available',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'zoom_reset',
                    tooltip: 'Reset zoom',
                    backgroundColor: AppColors.cardBackground.withAlpha(200),
                    onPressed: _resetZoom,
                    child: const Icon(
                      Icons.zoom_out_map,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Info panel ──
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle indicator
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Priority badge
                    _priorityBadge(document.priority, badgeStyle),
                    const SizedBox(height: 16),

                    // Dates
                    _infoRow(
                      Icons.camera_alt,
                      'Captured',
                      _formatDate(document.captureDate),
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      Icons.calendar_today,
                      'Letter date',
                      document.letterDate != null
                          ? _formatDate(document.letterDate!)
                          : 'Not set',
                    ),
                    const SizedBox(height: 10),

                    // Actionable date
                    if (document.actionableDate != null) ...[
                      Row(
                        children: [
                          const Icon(Icons.event, size: 16,
                              color: AppColors.actionRequiredBadgeText),
                          const SizedBox(width: 8),
                          Text(
                            'Actionable date: ',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _formatDate(document.actionableDate!),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (reminder != null) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.notifications_active,
                                size: 14,
                                color: AppColors.accentColor),
                          ],
                        ],
                      ),
                      if (document.actionableDateContext.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 24, top: 2),
                          child: Text(
                            document.actionableDateContext,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 16),

                    // AI tags
                    if (document.aiTags.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: document.aiTags
                            .map((tag) => Chip(
                                  label: Text(
                                    tag,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  backgroundColor:
                                      AppColors.searchBarBackground,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  side: BorderSide.none,
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Notes
                    const Divider(color: AppColors.divider),
                    const SizedBox(height: 12),
                    const Text(
                      'NOTES',
                      style: TextStyle(
                        color: AppColors.actionRequiredBadgeText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      document.notes.isNotEmpty
                          ? document.notes
                          : 'No notes',
                      style: TextStyle(
                        color: document.notes.isNotEmpty
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Reminder section
                    if (reminder != null)
                      _buildReminderCard(reminder, provider, document.title)
                    else
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'No reminder set',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper widgets ──

  Widget _categoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        category,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _priorityBadge(String priority, Map<String, Color> style) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: style['background'],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        priority,
        style: TextStyle(
          color: style['text'],
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEE, MMMM d, yyyy').format(date);
  }

  Widget _buildReminderCard(
    Reminder reminder,
    DocumentProvider provider,
    String documentTitle,
  ) {
    final notifyLabel =
        _notifyLabels[reminder.notifyDaysBefore] ?? 'Custom';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active,
                size: 18,
                color: reminder.isCompleted
                    ? AppColors.completedBadgeText
                    : AppColors.actionRequiredBadgeText,
              ),
              const SizedBox(width: 8),
              const Text(
                'REMINDER',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (reminder.isCompleted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.completedBadgeBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Completed',
                    style: TextStyle(
                      color: AppColors.completedBadgeText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow(
            Icons.event,
            'Date',
            _formatDate(reminder.actionableDate),
          ),
          const SizedBox(height: 8),
          if (reminder.contextReason.isNotEmpty) ...[
            _infoRow(Icons.info_outline, 'Reason', reminder.contextReason),
            const SizedBox(height: 8),
          ],
          _infoRow(Icons.alarm, 'Notify', notifyLabel),
          if (!reminder.isCompleted) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await provider.markReminderCompleted(reminder.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reminder marked as complete'),
                      ),
                    );
                  }
                },
                icon:
                    const Icon(Icons.check_circle, size: 18, color: Colors.white),
                label: const Text(
                  'Mark Complete',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
