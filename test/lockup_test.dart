import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html_galley_generator/features/generator/services/docx_parser_service.dart';
import 'package:html_galley_generator/features/generator/services/html_generator_service.dart';
import 'package:html_galley_generator/features/generator/models/journal_settings.dart';
import 'package:html_galley_generator/features/generator/models/article_metadata.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart' as vsc;

import 'test_utils.dart';

void main() {
  test('Full HTML to Delta conversion test (DOCX)', () async {
    final file = createMockDocxFile(
      title: 'Transnational Politics and Korean Evangelicalism: Affective Infrastructure and History',
      author: 'Minjung Noh',
      affiliation: 'Lehigh University',
      abstractText: 'This article examines the political resonance of contemporary Korean evangelicalism...',
      keywords: 'Korean Evangelicalism, religion',
      bodyText: 'By an ethos of existential revenge',
    );
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    final parser = DocxParserService();
    final metadata = await parser.parse(XFile(file.path));
    
    expect(metadata.title, isNotEmpty);
    expect(metadata.articleBody, isNotEmpty);
  });

  test('HtmlGeneratorService.buildFullHtml preserves footnote and citation IDs after editor simulation', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final htmlGenerator = HtmlGeneratorService();
    
    // Simulate edited HTML output from Quill editor (which lacks IDs and contains target="_blank")
    const simulatedEditorContent = '''
<p>This is a paragraph in the body<sup><a href="#fn1" target="_blank">1</a></sup>.</p>
<p>Another citation<sup><a href="#fn2">2</a></sup>.</p>
<h2>Notes</h2>
<p><sup><a href="#ref1" target="_blank">1</a></sup> Footnote 1 content.</p>
<p><sup><a href="#ref2">2</a></sup> Footnote 2 content.</p>
''';

    final metadata = ArticleMetadata(
      title: 'Test Title',
      author: 'Test Author',
      authorFullName: 'Test Author',
      authorFirstName: 'Test',
      authorLastName: 'Author',
      keywords: '',
      articleAbstract: '',
      articleBody: simulatedEditorContent,
      authorOrcid: '',
      authorAffiliation: '',
      authorBio: '',
      volume: '1',
      issue: '1',
      articleId: '101',
      submissionId: '101',
      issueViewId: '',
      pdfGalleyId: '',
      publishedDate: '',
      issuedDate: '',
      publishedDateMonYYYY: '',
      publishYear: '',
      submittedDate: '',
      modifiedDate: '',
      titleMain: 'Test Title',
    );
    
    const settings = JournalSettings(
      journalBaseUrl: 'https://transnationalasia.rice.edu',
      journalPath: 'journal',
      journalName: 'Transnational Asia',
      journalAbbrev: 'TA',
      journalIssn: '1234-5678',
    );

    final fullHtml = await htmlGenerator.buildFullHtml(simulatedEditorContent, metadata, settings);

    // Verify IDs are successfully restored and target="_blank" is stripped for internal links
    expect(fullHtml, contains('<sup id="ref1"><a href="#fn1" target="_self">[1]</a></sup>'));
    expect(fullHtml, contains('<sup id="ref2"><a href="#fn2" target="_self">[2]</a></sup>'));
    expect(fullHtml, contains('<p id="fn1"><a href="#ref1" target="_self">[1]</a>'));
    expect(fullHtml, contains('<p id="fn2"><a href="#ref2" target="_self">[2]</a>'));
    expect(fullHtml, isNot(contains('href="#fn1" target="_blank"')));
    expect(fullHtml, isNot(contains('target="_blank" href="#fn1"')));
    expect(fullHtml, isNot(contains('href="#ref1" target="_blank"')));
    expect(fullHtml, isNot(contains('target="_blank" href="#ref1"')));
  });

  test('Simulate Editor load and save preserves indentation', () async {
    // 1. Input HTML from DocxParserService (using blockquote for indented paragraph)
    const inputHtml = '<blockquote>This is indented paragraph.</blockquote>';
    
    // 2. Load into Delta (as in EditorScreen._loadContent)
    final delta = HtmlToDelta(
      shouldInsertANewLine: (localName) => localName == 'p' || localName == 'blockquote',
    ).convert(inputHtml);
    
    // 3. Save from Delta (as in EditorScreen._save)
    final deltaJson = delta.toJson();
    final converter = vsc.QuillDeltaToHtmlConverter(
      List<Map<String, dynamic>>.from(deltaJson),
      vsc.ConverterOptions(
        multiLineParagraph: false,
        sanitizerOptions: vsc.OpAttributeSanitizerOptions(),
        converterOptions: vsc.OpConverterOptions(
          inlineStylesFlag: true,
        ),
      ),
    );
    final editedHtml = converter.convert();
    expect(editedHtml, contains('<blockquote>'));
  });
}
