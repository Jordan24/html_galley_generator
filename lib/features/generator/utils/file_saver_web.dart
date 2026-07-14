import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
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
    final bytes = utf8.encode(fullHtml);
    final blob = web.Blob(
      [Uint8List.fromList(bytes).buffer.toJS].toJS,
      web.BlobPropertyBag(type: 'text/html'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = suggestedName;
    web.document.body!.appendChild(anchor);
    anchor.click();
    web.document.body!.removeChild(anchor);
    web.URL.revokeObjectURL(url);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('HTML Galley downloaded successfully!')),
      );
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
