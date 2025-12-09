import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/screens/shared_media_screen.dart';
import 'package:prism/widgets/gradient_scaffold.dart';
import 'package:prism/utils/theme.dart';

class ConfirmSharingScreen extends StatelessWidget {
  const ConfirmSharingScreen({super.key});

  Future<void> _confirmShare(BuildContext context) async {
    final sharingProvider = context.read<SharingProvider>();

    final success = await sharingProvider.confirmShare();

    if (!context.mounted) return;

    if (success) {
      // Navigate to shared media screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SharedMediaScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sharingProvider.error ?? 'Failed to share images'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sharingProvider = Provider.of<SharingProvider>(context);
    final batchStatus = sharingProvider.batchStatus;
    final recipients = batchStatus?.recipients ?? [];
    final selectedRecipients = sharingProvider.selectedRecipients;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Confirm Sharing'),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Success banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Personalized Sharing Applied!',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Everyone in your content will receive relevant photos and videos.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Auto-Clean Toggle
                SwitchListTile(
                  value: sharingProvider.autoClean,
                  onChanged: (_) => sharingProvider.toggleAutoClean(),
                  title: const Text('Auto-Clean Media'),
                  subtitle: const Text(
                    'Automatically move media to the recipient if you or your faces aren\'t detected.',
                  ),
                  secondary: const Icon(Icons.auto_awesome),
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 24),

                // Recipients section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recipients',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Badge(
                      label: Text('${selectedRecipients.length} selected'),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Recipients list
                if (recipients.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No recipients detected',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...recipients.map((recipient) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: CheckboxListTile(
                        value: recipient.isSelected,
                        onChanged: (_) =>
                            sharingProvider.toggleRecipient(recipient.userId),
                        title: Text(recipient.username),
                        subtitle: Text(
                          '${recipient.count} ${recipient.count == 1 ? 'item' : 'items'}',
                        ),
                        secondary: CircleAvatar(
                          backgroundImage:
                              recipient.profilePictureUrl.isNotEmpty
                              ? CachedNetworkImageProvider(
                                  recipient.profilePictureUrl,
                                )
                              : null,
                          child: recipient.profilePictureUrl.isEmpty
                              ? Text(recipient.username[0].toUpperCase())
                              : null,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),

          // Footer info
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Recipients',
                        style: theme.textTheme.bodyLarge,
                      ),
                      Text(
                        '${selectedRecipients.length} People',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Content', style: theme.textTheme.bodyLarge),
                      Text(
                        '${batchStatus?.images.length ?? 0} items',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Unknown Faces',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.help_outline,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      Text(
                        '${batchStatus?.unknowns.length ?? 0}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: (batchStatus?.unknowns.length ?? 0) > 0
                              ? theme.colorScheme.tertiary
                              : null,
                          fontWeight: (batchStatus?.unknowns.length ?? 0) > 0
                              ? FontWeight.bold
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: sharingProvider.isProcessing
                          ? null
                          : () => _confirmShare(context),
                      icon: sharingProvider.isProcessing
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: Text(
                        sharingProvider.isProcessing
                            ? 'Processing...'
                            : 'Prism Share',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
