import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';

void main() {
  final html = '<p>Para 1</p><p>Para 2</p>';
  final delta = HtmlToDelta(
    shouldInsertANewLine: (localName) => localName == 'p',
  ).convert(html);
  print(delta.toString());
}
