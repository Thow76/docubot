import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/document_provider.dart';
import '../services/ai_service.dart';
import '../services/notification_service.dart'; // DEBUG: REMOVE BEFORE RELEASE
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _aiService = AiService();
  bool _aiSearchEnabled = false;
  bool _aiSearching = false;
  String? _aiSearchResult;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query, DocumentProvider provider) {
    provider.setSearchQuery(query);
    // Dismiss stale AI result when query changes
    if (_aiSearchResult != null) {
      setState(() => _aiSearchResult = null);
    }
  }

  Future<void> _runAiSearch(DocumentProvider provider) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _aiSearching = true;
      _aiSearchResult = null;
    });

    try {
      final summaries = provider.documents
          .map((d) => {
                'title': d.title,
                'aiSummary': d.aiSummary,
                'aiTags': d.aiTags.join(', '),
              })
          .toList();

      final result = await _aiService.searchDocumentsWithAI(query, summaries);

      if (!mounted) return;

      if (result.startsWith('AI search unavailable') ||
          result.startsWith('AI search is unavailable')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI search unavailable, using local search'),
          ),
        );
      } else {
        setState(() => _aiSearchResult = result);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI search unavailable, using local search'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _aiSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final documentProvider = Provider.of<DocumentProvider>(context);

    if (documentProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (documentProvider.errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: AppColors.actionRequiredBadgeText),
              const SizedBox(height: 16),
              Text(
                documentProvider.errorMessage!,
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  documentProvider.clearError();
                  documentProvider.loadDocuments();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DocuBot'),
              Text(
                '${documentProvider.documents.length} documents',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            // DEBUG: REMOVE BEFORE RELEASE
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Test immediate notification',
              onPressed: () => NotificationService.instance.showTestNotification(),
            ),
            // DEBUG: REMOVE BEFORE RELEASE
            IconButton(
              icon: const Icon(Icons.schedule),
              tooltip: 'Test scheduled notification',
              onPressed: () => NotificationService.instance.showScheduledTestNotification(),
            ),
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {},
              tooltip: 'Notifications',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {},
              tooltip: 'Settings',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Documents'),
              Tab(text: 'Reminders'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDocumentsTab(context, documentProvider),
            _buildRemindersTab(context, documentProvider),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, '/camera');
          },
          tooltip: 'Capture document',
          child: const Icon(Icons.camera_alt),
        ),
      ),
    );
  }

  Widget _buildDocumentsTab(BuildContext context, DocumentProvider provider) {
    return Column(
      children: [
        // ── Search bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: _aiSearchEnabled
                        ? 'Ask AI about your documents…'
                        : 'Search documents…',
                    hintStyle:
                        const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.searchBarBackground,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                color: AppColors.textSecondary, size: 18),
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('', provider);
                            },
                          )
                        : null,
                  ),
                  onChanged: (q) => _onSearchChanged(q, provider),
                  textInputAction: _aiSearchEnabled
                      ? TextInputAction.search
                      : TextInputAction.done,
                  onSubmitted: _aiSearchEnabled
                      ? (_) => _runAiSearch(provider)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              // AI toggle button
              Material(
                color: _aiSearchEnabled
                    ? AppColors.accentColor
                    : AppColors.searchBarBackground,
                borderRadius: BorderRadius.circular(12),
                child: Tooltip(
                message: _aiSearchEnabled ? 'Disable AI search' : 'Enable AI search',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _aiSearchEnabled = !_aiSearchEnabled;
                      _aiSearchResult = null;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 22,
                      color: _aiSearchEnabled
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                ),
              ),
            ],
          ),
        ),

        // ── AI search loading indicator ──
        if (_aiSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),

        // ── AI search result panel ──
        if (_aiSearchResult != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.accentColor.withAlpha(100)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          size: 16, color: AppColors.accentColor),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'AI Search Results',
                          style: TextStyle(
                            color: AppColors.accentColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _aiSearchResult = null),
                        child: Semantics(
                          label: 'Dismiss AI search results',
                          child: const Icon(Icons.close,
                              size: 16,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _aiSearchResult!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Document list ──
        Expanded(
          child: provider.documents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.description_outlined,
                          size: 64, color: AppColors.textSecondary),
                      SizedBox(height: 16),
                      Text(
                        'No documents yet',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap the camera button to capture\nyour first document',
                        style: TextStyle(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : provider.filteredDocuments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.search_off,
                              size: 64, color: AppColors.textSecondary),
                          SizedBox(height: 16),
                          Text(
                            'No matching documents',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      children: ['Financial', 'Medical', 'Bills', 'Other'].map((
                        category,
                      ) {
                        final documents = provider.categoryDocuments(category);
                        final categoryAccent =
                            CategoryStyles.styleFor(category);
                        return ExpansionTile(
                          leading: Icon(
                            CategoryStyles.iconFor(category),
                            color: categoryAccent.foreground,
                          ),
                          title: Text(category),
                          subtitle: Text('${documents.length} documents'),
                          children: documents.map((doc) {
                            return ListTile(
                              title: Text(
                                doc.title,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              subtitle: Text(
                                'Captured ${DateFormat('MMM d, yyyy').format(doc.captureDate)}'
                                '${doc.letterDate != null ? ' · Dated ${DateFormat('MMM d, yyyy').format(doc.letterDate!)}' : ''}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(
                                    label: Text(doc.priority),
                                    backgroundColor: BadgeStyles.getBadgeStyle(
                                      doc.priority,
                                    )['background'],
                                    labelStyle: TextStyle(
                                      color: BadgeStyles.getBadgeStyle(
                                        doc.priority,
                                      )['text'],
                                    ),
                                  ),
                                  if (provider.getReminderForDocument(doc.id) !=
                                      null)
                                    Semantics(
                                      label: 'Has reminder',
                                      child: const Icon(
                                        Icons.notifications,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/view',
                                  arguments: doc,
                                );
                              },
                            );
                          }).toList(),
                        );
                      }).toList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildRemindersTab(BuildContext context, DocumentProvider provider) {
    final reminders = provider.upcomingReminders;

    if (reminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.calendar_today,
              size: 64,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'No upcoming reminders',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: reminders.length,
      itemBuilder: (context, index) {
        final reminder = reminders[index];
        return ListTile(
          title: Text(
            reminder.contextReason,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          subtitle: Text(
            '${DateFormat('MMM d, yyyy').format(reminder.actionableDate)}'
            ' · ${reminder.notifyDaysBefore == 0 ? 'On the day' : '${reminder.notifyDaysBefore} days before'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          trailing: Checkbox(
            value: reminder.isCompleted,
            onChanged: (value) {
              provider.markReminderCompleted(reminder.id);
            },
          ),
          onTap: () {
            final doc = provider.documents
                .where((d) => d.id == reminder.documentId)
                .firstOrNull;
            if (doc != null) {
              Navigator.pushNamed(context, '/view', arguments: doc);
            }
          },
        );
      },
    );
  }
}
