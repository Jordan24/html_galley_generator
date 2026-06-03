import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

void main() {
  final deltaJson = [
    {"insert": "Para 1"},
    {"insert": "\n"},
    {"insert": "Para 2"},
    {"insert": "\n"}
  ];
  
  final options = ConverterOptions(
    multiLineParagraph: false,
    sanitizerOptions: OpAttributeSanitizerOptions(),
    converterOptions: OpConverterOptions(
      inlineStylesFlag: true,
      customCssStyles: (op) {
        if (op.isImage()) {
          return ['max-width: 100%', 'object-fit: contain'];
        }
        if (op.isBlockquote()) {
          return ['border-left: 4px solid #ccc', 'padding-left: 16px'];
        }
        return null;
      },
    ),
  );
  
  final converter = QuillDeltaToHtmlConverter(
    List<Map<String, dynamic>>.from(deltaJson),
    options,
  );
  
  print(converter.convert());
}
