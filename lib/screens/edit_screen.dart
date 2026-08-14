import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/document.dart';
import '../models/reminder.dart';
import '../providers/document_provider.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

class EditScreen extends StatefulWidget {
  const EditScreen({super.key});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _contextReasonController = TextEditingController();

  late Document _document;
  String? _selectedCategory;
  String _selectedPriority = 'Informational';
  DateTime? _letterDate;
  DateTime? _actionableDate;
  bool _isAnalysing = false;
  bool _isSaving = false;
  bool _reminderEnabled = false;
  int _notifyDaysBefore = 1;
  String _aiSummary = '';
  List<String> _aiTags = [];

  Reminder? _existingReminder;
  bool _reminderDeleted = false;
  bool _didInit = false;
  bool _hasUnsavedChanges = false;

  final AiService _aiService = AiService();

  static const _priorities = [
    ('Action Required', AppColors.actionRequiredBadgeText),
    ('Completed', AppColors.completedBadgeText),
    ('Informational', AppColors.informationalBadgeText),
  ];

  static const _categories = [
    ('Financial', Icons.account_balance),
    ('Medical', Icons.local_hospital),
    ('Bills', Icons.receipt_long),
    ('Other', Icons.folder),
  ];

  static const _notifyOptions = [
    (0, 'On the day'),
    (1, '1 day before'),
    (3, '3 days before'),
    (7, '1 week before'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _document = ModalRoute.of(context)!.settings.arguments as Document;
      _titleController.text = _document.title;
      _notesController.text = _document.notes;
      _selectedCategory = _document.category;
      _selectedPriority = _document.priority;
      _letterDate = _document.letterDate;
      _aiSummary = _document.aiSummary;
      _aiTags = List<String>.from(_document.aiTags);

      // Pre-fill actionable date from document
      _actionableDate = _document.actionableDate;
      _contextReasonController.text = _document.actionableDateContext;

      final provider = Provider.of<DocumentProvider>(context, listen: false);
      _existingReminder = provider.getReminderForDocument(_document.id);
      if (_existingReminder != null) {
        _reminderEnabled = true;
        _notifyDaysBefore = _existingReminder!.notifyDaysBefore;
      }

      // Track unsaved changes
      _titleController.addListener(_markChanged);
      _notesController.addListener(_markChanged);
      _contextReasonController.addListener(_markChanged);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _contextReasonController.dispose();
    super.dispose();
  }

  // ──────────────────── AI ANALYSIS ────────────────────

  Future<void> _runAiAnalysis() async {
    setState(() => _isAnalysing = true);

    try {
      final result = await _aiService.analyseDocument(_document.imagePath);

      if (!mounted) return;

      setState(() {
        // Title
        final title = result['suggestedTitle'] as String?;
        if (title != null && title.isNotEmpty) {
          _titleController.text = title;
        }

        // Category
        final category = result['suggestedCategory'] as String?;
        if (category != null && _categories.any((c) => c.$1 == category)) {
          _selectedCategory = category;
        }

        // Priority
        final priority = result['suggestedPriority'] as String?;
        if (priority != null && _priorities.any((p) => p.$1 == priority)) {
          _selectedPriority = priority;
        }

        // Letter date
        final letterDateStr = result['letterDate'] as String?;
        if (letterDateStr != null) {
          _letterDate = DateTime.tryParse(letterDateStr);
        }

        // Actionable date → enable reminder section
        final actionableDateStr = result['actionableDate'] as String?;
        if (actionableDateStr != null) {
          final parsed = DateTime.tryParse(actionableDateStr);
          if (parsed != null) {
            _actionableDate = parsed;
            _reminderEnabled = true;
            _reminderDeleted = false;
          }
        }

        // Actionable date context
        final actionableDateContext = result['actionableDateContext'] as String?;
        if (actionableDateContext != null && actionableDateContext.isNotEmpty) {
          _contextReasonController.text = actionableDateContext;
        }

        // Notes
        final notes = result['notes'] as String?;
        if (notes != null && notes.isNotEmpty) {
          _notesController.text = notes;
        }
      });

      _markChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI analysis complete')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI analysis failed — enter details manually'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalysing = false);
    }
  }

  // ──────────────────── SAVE ────────────────────

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a document title')),
      );
      return;
    }
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final provider = Provider.of<DocumentProvider>(context, listen: false);

      final updatedDoc = Document(
        id: _document.id,
        title: _titleController.text.trim(),
        category: _selectedCategory!,
        captureDate: _document.captureDate,
        letterDate: _letterDate,
        priority: _selectedPriority,
        notes: _notesController.text.trim(),
        imagePath: _document.imagePath,
        aiSummary: _aiSummary,
        aiTags: _aiTags,
        actionableDate: _actionableDate,
        actionableDateContext: _contextReasonController.text.trim(),
      );

      await provider.updateDocument(updatedDoc);

      // Handle reminder changes
      if ((!_reminderEnabled || _reminderDeleted) && _existingReminder != null) {
        await provider.deleteReminder(_existingReminder!.id);
      } else if (_reminderEnabled && _actionableDate != null) {
        if (_existingReminder != null && !_reminderDeleted) {
          final updated = _existingReminder!.copyWith(
            actionableDate: _actionableDate,
            contextReason: _contextReasonController.text.trim(),
            notifyDaysBefore: _notifyDaysBefore,
          );
          await provider.updateReminder(updated, updatedDoc.title);
        } else {
          final newReminder = Reminder(
            documentId: _document.id,
            actionableDate: _actionableDate!,
            contextReason: _contextReasonController.text.trim(),
            notifyDaysBefore: _notifyDaysBefore,
          );
          await provider.addReminder(newReminder, updatedDoc.title);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document updated')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ──────────────────── DELETE DOCUMENT ────────────────────

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Delete Document',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Are you sure you want to delete this document? This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.actionRequiredBadgeText)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final provider = Provider.of<DocumentProvider>(context, listen: false);
      await provider.deleteDocument(_document.id, _document.imagePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  // ──────────────────── DATE PICKERS ────────────────────

  void _markChanged() {
    if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Discard changes?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'You have unsaved changes. Are you sure you want to go back?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard',
                style: TextStyle(color: AppColors.actionRequiredBadgeText)),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _pickLetterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _letterDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _letterDate = picked);
  }

  Future<void> _pickActionableDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _actionableDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _actionableDate = picked);
  }

  // ──────────────────── BUILD ────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          tooltip: 'Back',
          onPressed: () async {
            final shouldPop = await _onWillPop();
            if (shouldPop && context.mounted) Navigator.pop(context);
          },
        ),
        title: const Text(
          'Edit Document',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              avatar:
                  const Icon(Icons.check, size: 16, color: Colors.white),
              label: const Text('Save',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
              backgroundColor: AppColors.accentColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: _isSaving ? null : _save,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Document thumbnail ──
            _buildThumbnailSection(),
            const SizedBox(height: 24),

            // ── Title ──
            _sectionLabel('DOCUMENT TITLE'),
            const SizedBox(height: 8),
            _buildTextField(_titleController, 'Enter document title'),
            const SizedBox(height: 24),

            // ── Category ──
            _sectionLabel('CATEGORY'),
            const SizedBox(height: 8),
            _buildCategorySelector(),
            const SizedBox(height: 24),

            // ── Priority ──
            _sectionLabel('PRIORITY BADGE'),
            const SizedBox(height: 8),
            ..._priorities.map((p) => _buildPriorityOption(p.$1, p.$2)),
            const SizedBox(height: 24),

            // ── Letter date ──
            _sectionLabel('LETTER DATE'),
            const SizedBox(height: 8),
            _buildLetterDateField(),
            const SizedBox(height: 24),

            // ── Actionable date ──
            _sectionLabel('ACTIONABLE DATE'),
            const SizedBox(height: 8),
            _buildActionableDateField(),
            const SizedBox(height: 16),

            // ── Actionable date context ──
            _sectionLabel('CONTEXT'),
            const SizedBox(height: 8),
            _buildTextField(_contextReasonController,
                'e.g. Payment due for invoice #1234'),
            const SizedBox(height: 24),

            // ── Notes ──
            _sectionLabel('NOTES'),
            const SizedBox(height: 8),
            _buildTextField(_notesController, 'Add notes…',
                maxLines: 5, minLines: 3),
            const SizedBox(height: 24),

            // ── AI analysis button ──
            _buildAiButton(),
            const SizedBox(height: 24),

            // ── Reminder ──
            _sectionLabel('REMINDER'),
            const SizedBox(height: 8),
            _buildReminderSection(),
            const SizedBox(height: 32),

            // ── Delete document ──
            Center(
              child: TextButton.icon(
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.actionRequiredBadgeText, size: 18),
                label: const Text(
                  'Delete Document',
                  style: TextStyle(
                    color: AppColors.actionRequiredBadgeText,
                    fontSize: 14,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.actionRequiredBadgeText,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
    );
  }

  // ── Thumbnail ──

  Widget _buildThumbnailSection() {
    return Center(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(_document.imagePath),
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.broken_image,
                    color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'CAPTURED ON',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat('EEE, MMMM d, yyyy').format(_document.captureDate),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Original document image',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ──

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    int minLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: minLines,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ── Category selector ──

  Widget _buildCategorySelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat.$1;
            final categoryAccent = CategoryStyles.styleFor(cat.$1);
            return SizedBox(
              width: cardWidth,
              child: GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? categoryAccent.backgroundTint
                        : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? categoryAccent.foreground.withAlpha(82)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Icon(
                            cat.$2,
                            color: isSelected
                                ? categoryAccent.foreground
                                : AppColors.textSecondary,
                            size: 28,
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: categoryAccent.foreground,
                              size: 14,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat.$1,
                        style: TextStyle(
                          color: isSelected
                              ? categoryAccent.foreground
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ── Priority option ──

  Widget _buildPriorityOption(String label, Color dotColor) {
    final isSelected = _selectedPriority == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedPriority = label),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? dotColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? dotColor : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check, color: dotColor, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Letter date field ──

  Widget _buildLetterDateField() {
    return GestureDetector(
      onTap: _pickLetterDate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _letterDate != null
                    ? DateFormat('yyyy-MM-dd').format(_letterDate!)
                    : 'Select date (optional)',
                style: TextStyle(
                  color: _letterDate != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (_letterDate != null)
              GestureDetector(
                onTap: () => setState(() => _letterDate = null),
                child: const Icon(Icons.close,
                    color: AppColors.textSecondary, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  // ── AI button ──

  Widget _buildAiButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isAnalysing ? null : _runAiAnalysis,
        icon: _isAnalysing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.auto_awesome, color: Colors.white),
        label: Text(
          _isAnalysing ? 'Analysing...' : 'Analyse with AI',
          style: const TextStyle(color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3A3F5C),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  // ── Actionable date field ──

  Widget _buildActionableDateField() {
    return GestureDetector(
      onTap: _pickActionableDate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.event,
                color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _actionableDate != null
                    ? DateFormat('d MMMM yyyy').format(_actionableDate!)
                    : 'No actionable date',
                style: TextStyle(
                  color: _actionableDate != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (_actionableDate != null)
              GestureDetector(
                onTap: () => setState(() {
                  _actionableDate = null;
                  _reminderEnabled = false;
                }),
                child: const Icon(Icons.close,
                    color: AppColors.textSecondary, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  // ── Reminder section ──

  Widget _buildReminderSection() {
    final hasActionableDate = _actionableDate != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_outlined,
                  color: hasActionableDate
                      ? AppColors.textSecondary
                      : AppColors.textSecondary.withAlpha(100),
                  size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Set Reminder',
                    style: TextStyle(
                        color: hasActionableDate
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
              ),
              Switch(
                value: _reminderEnabled && !_reminderDeleted && hasActionableDate,
                onChanged: hasActionableDate
                    ? (v) => setState(() {
                          _reminderEnabled = v;
                          if (v) _reminderDeleted = false;
                          if (!v && _existingReminder != null) {
                            _reminderDeleted = true;
                          }
                        })
                    : null,
                activeThumbColor: AppColors.accentColor,
              ),
            ],
          ),
          if (!hasActionableDate)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Set an actionable date above to enable reminders',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          if (_reminderEnabled && !_reminderDeleted && hasActionableDate) ...[
            const SizedBox(height: 16),

            // Notify timing
            _sectionLabel('NOTIFY ME'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _notifyDaysBefore,
                  dropdownColor: AppColors.cardBackground,
                  style: const TextStyle(color: AppColors.textPrimary),
                  isExpanded: true,
                  items: _notifyOptions
                      .map((opt) => DropdownMenuItem(
                            value: opt.$1,
                            child: Text(opt.$2),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _notifyDaysBefore = v);
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
