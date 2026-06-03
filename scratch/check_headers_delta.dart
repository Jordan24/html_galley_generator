import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';

void main() {
  final html = '<h2>Header 1</h2><p>Para 1</p><blockquote>Quote 1</blockquote><p>Para 2</p>';
  print(HtmlToDelta().convert(html).toString());
}
