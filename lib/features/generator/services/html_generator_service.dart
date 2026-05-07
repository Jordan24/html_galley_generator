import '../models/article_metadata.dart';
import '../models/journal_settings.dart';

/// Generates the HTML galley content and suggested output filename.
class HtmlGeneratorService {
  /// Builds the suggested output filename from [metadata].
  String buildFileName(ArticleMetadata metadata) {
    final vol = metadata.volume.trim();
    final iss = metadata.issue.trim();
    final auth = metadata.author.trim().replaceAll(' ', '+');

    // Use only the text before the first colon, strip apostrophes, replace spaces.
    String title = metadata.title.split(':').first.trim();
    title = title
        .replaceAll("'", '')
        .replaceAll('\u2019', '') // curly right apostrophe
        .replaceAll(' ', '+');

    return 'Vol+${vol}+No+${iss}_${auth}_$title.html'; // ignore: unnecessary_brace_in_string_interps
  }

  /// Generates the full HTML galley string from [metadata] and [settings].
  String buildHtml(ArticleMetadata metadata, JournalSettings settings) {
    String baseUrl = settings.baseUrl.trim();
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    final path = settings.journalPath.trim();
    final articleId = metadata.articleId.trim();
    final title = metadata.title.trim();

    return '''<!DOCTYPE html>
<html lang="en-US" xml:lang="en-US">
<head>
\t<meta charset="utf-8">
\t<meta name="viewport" content="width=device-width, initial-scale=1.0">
\t<title>
\t\tView of $title
\t\t\t\t\t\t\t| Transnational Asia
\t\t\t</title>

\t
<link rel="icon" href="$baseUrl/public/journals/3/favicon_en_US.png">
<meta name="generator" content="Open Journal Systems">
\t<link rel="stylesheet" href="$baseUrl/plugins/themes/healthSciences/libs/bootstrap.min.css" type="text/css" />
\t<link rel="stylesheet" href="$baseUrl/index.php/$path/\$\$\$call\$\$\$/page/page/css?name=stylesheet" type="text/css" />
\t<link rel="stylesheet" href="$baseUrl/plugins/generic/orcidProfile/css/orcidProfile.css" type="text/css" />
\t<link rel="stylesheet" href="$baseUrl/public/journals/3/styleSheet.css" type="text/css" />
</head>
<body class="pkp_page_article pkp_op_view">

<header class="header_view">

\t
\t<a href="$baseUrl/index.php/$path/article/view/$articleId" class="return">
\t\t<span class="pkp_screen_reader">
\t\t\tReturn to Article Details
\t\t</span>
\t</a>
\t\t\t<a href="$baseUrl/index.php/$path/article/view/$articleId" class="title">
\t\t\t$title
\t\t</a>
\t\t\t</header>

<div id="htmlContainer" class="galley_view" style="overflow:visible;-webkit-overflow-scrolling:touch">
\t<iframe id="htmlGalleyFrame" name="htmlFrame" src="\t\t\t$baseUrl/index.php/$path/article/download/$articleId/GALLEY_ID?inline=1
\t\t" allowfullscreen webkitallowfullscreen></iframe>
</div>

</body>
</html>
''';
  }
}
