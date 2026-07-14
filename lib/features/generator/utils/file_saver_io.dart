import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../models/article_metadata.dart';
import '../models/journal_settings.dart';

Future<void> saveHtmlGalley({
  required BuildContext context,
  required String fullHtml,
  required ArticleMetadata metadata,
  required JournalSettings settings,
  required String suggestedName,
  required void Function(bool) onSavingStateChanged,
}) async {
  onSavingStateChanged(true);
  try {
    final saveLocation = await getSaveLocation(suggestedName: suggestedName);
    if (saveLocation != null) {
      await File(saveLocation.path).writeAsString(fullHtml);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('HTML Galley saved successfully!')),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  } finally {
    onSavingStateChanged(false);
  }
}
