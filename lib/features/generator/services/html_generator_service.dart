import '../models/article_metadata.dart';
import '../models/journal_settings.dart';

class HtmlGeneratorService {
  String buildFileName(ArticleMetadata metadata) {
    final vol = metadata.volume.trim();
    final iss = metadata.issue.trim();
    final auth = metadata.author.trim().replaceAll(' ', '+');

    String title = metadata.title.split(':').first.trim();
    title = _clean(title)
        .replaceAll("'", '')
        .replaceAll('"', '')
        .replaceAll(' ', '+');

    return 'Vol+$vol+No+${iss}_${auth}_$title.html';
  }

  String _getMonth(String date) {
    if (date.isEmpty) return '';
    final parts = date.split('-');
    if (parts.length < 2) return '';
    const months = ['Jan.', 'Feb.', 'Mar.', 'Apr.', 'May', 'Jun.', 'Jul.', 'Aug.', 'Sep.', 'Oct.', 'Nov.', 'Dec.'];
    final m = int.tryParse(parts[1]);
    if (m != null && m >= 1 && m <= 12) return months[m - 1];
    return '';
  }

  String buildHtml(ArticleMetadata metadata, JournalSettings settings) {
    String baseUrl = settings.baseUrl.trim();
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    final path = settings.journalPath.trim();
    
    final title = _clean(metadata.title);
    final shortTitle = title.split(':').first.trim();
    final articleId = metadata.articleId.trim();
    final publicationId = metadata.publicationId.trim();
    final issueViewId = metadata.issueViewId.trim();
    final pdfGalleyId = metadata.pdfGalleyId.trim();
    final authorFullName = _clean(metadata.authorFullName);
    final authorOrcid = metadata.authorOrcid.trim();
    final authorAffiliation = _clean(metadata.authorAffiliation);
    final volume = metadata.volume.trim();
    final issue = metadata.issue.trim();
    final publishedDate = metadata.publishedDate.trim();
    final submittedDate = metadata.submittedDate.trim();
    final modifiedDate = metadata.modifiedDate.trim();
    final publishedDateSlash = publishedDate.replaceAll('-', '/');
    final publishedYear = publishedDate.isNotEmpty ? publishedDate.split("-").first : DateTime.now().year.toString();
    
    final abstractHtml = metadata.abstract_.isEmpty ? '' : '<p>${_clean(metadata.abstract_)}</p>';
    final keywords = _clean(metadata.keywords);
    final articleBodyHtml = metadata.articleBodyHtml;
    
    // authorBio now contains HTML from the Quill editor.
    // We prepend the author name to the first paragraph or block.
    String authorBioHtml = '';
    if (metadata.authorBio.isNotEmpty) {
      if (metadata.authorBio.startsWith('<p>')) {
        authorBioHtml = metadata.authorBio.replaceFirst('<p>', '<p><strong>$authorFullName</strong> ');
      } else {
        authorBioHtml = '<p><strong>$authorFullName</strong> ${metadata.authorBio}</p>';
      }
    }

    // Generate dynamic subject tags
    final keywordList = keywords.split(RegExp(r'[,;]')).map((k) => k.trim()).where((k) => k.isNotEmpty);
    final dcSubjectTags = keywordList.map((k) => '<meta name="DC.Subject" xml:lang="en" content="$k"/>').join('\n');
    final citationKeywordTags = keywordList.map((k) => '<meta name="citation_keywords" xml:lang="en" content="$k"/>').join('\n');

    return '''<!DOCTYPE html>
<html lang="en-US" xml:lang="en-US">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<title>
		$shortTitle
							| Transnational Asia
			</title>
<link rel="icon" href="https://transnationalasia.rice.edu/public/journals/3/favicon_en_US.png">
<meta name="generator" content="Open Journal Systems 3.3.0.14">
<link rel="schema.DC" href="http://purl.org/dc/elements/1.1/" />
<meta name="DC.Creator.PersonalName" content="$authorFullName"/>
<meta name="DC.Date.created" scheme="ISO8601" content="$publishedDate"/>
<meta name="DC.Date.dateSubmitted" scheme="ISO8601" content="$submittedDate"/>
<meta name="DC.Date.issued" scheme="ISO8601" content="$publishedDate"/>
<meta name="DC.Date.modified" scheme="ISO8601" content="$publishedDate"/>
<meta name="DC.Description" xml:lang="en" content="${metadata.abstract_.replaceAll('"', '&quot;')}"/>
<meta name="DC.Format" scheme="IMT" content="application/pdf"/>
<meta name="DC.Identifier" content="$articleId"/>
<meta name="DC.Identifier.DOI" content="10.25615/ta.v${volume}i$issue.$articleId"/>
<meta name="DC.Identifier.URI" content="https://transnationalasia.rice.edu/index.php/ta/article/view/$articleId"/>
<meta name="DC.Language" scheme="ISO639-1" content="en"/>
<meta name="DC.Rights" content="Copyright (c) $publishedYear Transnational Asia"/>
<meta name="DC.Rights" content="https://creativecommons.org/licenses/by-nc-nd/4.0"/>
<meta name="DC.Source" content="Transnational Asia"/>
<meta name="DC.Source.ISSN" content="2474-476X"/>
<meta name="DC.Source.Issue" content="$issue"/>
<meta name="DC.Source.Volume" content="$volume"/>
<meta name="DC.Source.URI" content="https://transnationalasia.rice.edu/index.php/ta"/>
$dcSubjectTags
<meta name="DC.Title" content="$title"/>
<meta name="DC.Type" content="Text.Serial.Journal"/>
<meta name="DC.Type.articleType" content="Articles"/>
<meta name="gs_meta_revision" content="1.1"/>
<meta name="citation_journal_title" content="Transnational Asia"/>
<meta name="citation_journal_abbrev" content="TA"/>
<meta name="citation_issn" content="2474-476X"/> 
<meta name="citation_author" content="$authorFullName"/>
<meta name="citation_author_institution" content="$authorAffiliation"/>
<meta name="citation_title" content="$title"/>
<meta name="citation_language" content="en"/>
<meta name="citation_date" content="$publishedDateSlash"/>
<meta name="citation_volume" content="$volume"/>
<meta name="citation_issue" content="$issue"/>
<meta name="citation_doi" content="10.25615/ta.v${volume}i$issue.$articleId"/>
<meta name="citation_abstract_html_url" content="https://transnationalasia.rice.edu/index.php/ta/article/view/$articleId"/>
$citationKeywordTags
<meta name="citation_pdf_url" content="https://transnationalasia.rice.edu/index.php/ta/article/download/$articleId/$pdfGalleyId"/>
	<link rel="stylesheet" href="https://transnationalasia.rice.edu/plugins/themes/healthSciences/libs/bootstrap.min.css?v=3.3.0.14" type="text/css" /><link rel="stylesheet" href="https://transnationalasia.rice.edu/index.php/ta/\$\$\$call\$\$\$/page/page/css?name=stylesheet" type="text/css" /><link rel="stylesheet" href="https://transnationalasia.rice.edu/plugins/generic/orcidProfile/css/orcidProfile.css?v=3.3.0.14" type="text/css" /><link rel="stylesheet" href="https://transnationalasia.rice.edu/public/journals/3/styleSheet.css?d=2023-03-28+06%3A28%3A43" type="text/css" />
</head>
<body dir="ltr">
<style>
a {overflow-wrap: break-word;}
@media (min-width: 992px) {
	body {
		max-width: 100%;
		margin: auto;
	}
}

@media (min-width: 768px) and (max-width: 991px) {
	body {
		max-width: 100%;
		margin: auto;
	}
}

@media (max-width: 767px) {
	body {
		padding-left: 5px;
		padding-right: 5px;
	}
}</style>
<header class="main-header">
	<div class="container">

		<div class="sr-only">$shortTitle</div>

	<div class="navbar-logo">
		<a href="	https://transnationalasia.rice.edu/index.php/ta/index
"><img src="https://transnationalasia.rice.edu/public/journals/3/pageHeaderLogoImage_en_US.png"alt="Journal logo"class="img-fluid"></a>
	</div>

		<nav class="navbar navbar-expand-lg navbar-light">
		<a class="navbar-brand" href="	https://transnationalasia.rice.edu/index.php/ta/index
"><img src="https://transnationalasia.rice.edu/public/journals/3/pageHeaderLogoImage_en_US.png"alt="Journal logo"class="img-fluid"></a>
		<button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#main-navbar"
		        aria-controls="main-navbar" aria-expanded="false"
		        aria-label="Toggle Navigation">
			<span class="navbar-toggler-icon"></span>
		</button>

		<div class="collapse navbar-collapse justify-content-md-center" id="main-navbar">
																		<ul id="primaryNav" class="navbar-nav">
														<li class="nav-item nmi_type_current">
				<a target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/issue/current"
					class="nav-link"
									>
					Current
				</a>
							</li>
														<li class="nav-item nmi_type_archives">
				<a target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/issue/archive"
					class="nav-link"
									>
					Archives
				</a>
							</li>
														<li class="nav-item nmi_type_search">
				<a target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/search/search"
					class="nav-link"
									>
					Search
				</a>
							</li>
														<li class="nav-item nmi_type_announcements">
				<a target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/announcement"
					class="nav-link"
									>
					Announcements
				</a>
							</li>
																					<li class="nav-item nmi_type_about dropdown">
				<a target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/about"
					class="nav-link dropdown-toggle"
											id="navMenuDropdown4"
						data-toggle="dropdown"
						aria-haspopup="true"
						aria-expanded="false"
									>
					About
				</a>
									<div class="dropdown-menu" aria-labelledby="navMenuDropdown4">
																					<a class="dropdown-item" target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/about">
									About the Journal
								</a>
																												<a class="dropdown-item" target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/editorial-statement">
									Editorial Statement
								</a>
																												<a class="dropdown-item" target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/about/editorialTeam">
									Editorial Team
								</a>
																												<a class="dropdown-item" target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/abstractingindexing">
									Abstracting & Indexing
								</a>
																												<a class="dropdown-item" target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/about/submissions">
									Submissions
								</a>
																												<a class="dropdown-item" target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/about/privacy">
									Privacy Statement
								</a>
																												<a class="dropdown-item" target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/about/contact">
									Contact
								</a>
																		</div>
							</li>
			</ul>

			
										<ul id="primaryNav-userNav" class="navbar-nav">
														<li class="nav-item nmi_type_user_register">
				<a target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/user/register"
					class="nav-link"
									>
					Register
				</a>
							</li>
														<li class="nav-item nmi_type_user_login">
				<a target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/login"
					class="nav-link"
									>
					Login
				</a>
							</li>
										</ul>

					</div>
	</nav>

			<ul id="userNav" class="navbar-nav">
														<li class="nav-item nmi_type_user_register">
				<a target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/user/register"
					class="nav-link"
									>
					Register
				</a>
							</li>
														<li class="nav-item nmi_type_user_login">
				<a target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/login"
					class="nav-link"
									>
					Login
				</a>
							</li>
										</ul>


		
	</div>
</header>

<div class="container page-article">
	<div class="article-details">
	<div class="page-header row">
		<div class="col-lg article-meta-mobile">
						<div class="article-details-issue-section small-screen">
				<a target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/issue/view/$issueViewId">Vol. $volume No. $issue ($publishedYear)</a>, Articles			</div>

			<div class="article-details-issue-identifier large-screen">
				<a target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/issue/view/$issueViewId">Vol. $volume No. $issue ($publishedYear)</a>
			</div>

			<h1 class="article-details-fulltitle">
				$title
			</h1>

							<div class="article-details-issue-section large-screen">Articles</div>
			
																																<div class="article-details-doi large-screen">
						<a target="_parent" href="https://doi.org/10.25615/ta.v${volume}i$issue.$articleId">https://doi.org/10.25615/ta.v${volume}i$issue.$articleId</a>
					</div>
							
										<div class="article-details-published">
					Published
																$publishedDate
										</div>
			
							<ul class="authors-string">
											<li><a class="author-string-href" href="#author-1"><span>$authorFullName</span><sup class="author-symbol author-plus">&plus;</sup><sup class="author-symbol author-minus hide">&minus;</sup></a><a class="orcidImage" href="https://orcid.org/$authorOrcid"><svg class="orcid_icon" viewBox="0 0 256 256" aria-hidden="true"><style type="text/css">.st0{fill:#A6CE39;}.st1{fill:#FFFFFF;}</style><path class="st0" d="M256,128c0,70.7-57.3,128-128,128C57.3,256,0,198.7,0,128C0,57.3,57.3,0,128,0C198.7,0,256,57.3,256,128z"/><g><path class="st1" d="M86.3,186.2H70.9V79.1h15.4v48.4V186.2z"/><path class="st1" d="M108.9,79.1h41.6c39.6,0,57,28.3,57,53.6c0,27.5-21.5,53.6-56.8,53.6h-41.8V79.1z M124.3,172.4h24.5c34.9,0,42.9-26.5,42.9-39.7c0-21.5-13.7-39.7-43.7-39.7h-23.7V172.4z"/><path class="st1" d="M88.7,56.8c0,5.5-4.5,10.1-10.1,10.1c-5.6,0-10.1-4.6-10.1-10.1c0-5.6,4.5-10.1,10.1-10.1C84.2,46.7,88.7,51.3,88.7,56.8z"/></g></svg></a></li>
									</ul>

																<div class="article-details-authors">
											<div class="article-details-author hideAuthor" id="author-1">
							<div class="article-details-author-name small-screen">
								$authorFullName
							</div>
															<div class="article-details-author-affiliation">
									$authorAffiliation
																	</div>
																						<div class="article-details-author-orcid">
									<a href="https://orcid.org/$authorOrcid" target="_blank">
										<svg class="orcid_icon" viewBox="0 0 256 256" aria-hidden="true">
	<style type="text/css">
		.st0{fill:#A6CE39;}
		.st1{fill:#FFFFFF;}
	</style>
	<path class="st0" d="M256,128c0,70.7-57.3,128-128,128C57.3,256,0,198.7,0,128C0,57.3,57.3,0,128,0C198.7,0,256,57.3,256,128z"/>
	<g>
		<path class="st1" d="M86.3,186.2H70.9V79.1h15.4v48.4V186.2z"/>
		<path class="st1" d="M108.9,79.1h41.6c39.6,0,57,28.3,57,53.6c0,27.5-21.5,53.6-56.8,53.6h-41.8V79.1z M124.3,172.4h24.5
			c34.9,0,42.9-26.5,42.9-39.7c0-21.5-13.7-39.7-43.7-39.7h-23.7V172.4z"/>
		<path class="st1" d="M88.7,56.8c0,5.5-4.5,10.1-10.1,10.1c-5.6,0-10.1-4.6-10.1-10.1c0-5.6,4.5-10.1,10.1-10.1
			C84.2,46.7,88.7,51.3,88.7,56.8z"/>
	</g>
</svg>
										https://orcid.org/$authorOrcid
									</a>
																	</div>
																													<button type="button" class="article-details-bio-toggle" data-toggle="modal" data-target="#authorBiographyModal1">
									Bio
								</button>
																													</div>
									</div>

					</div>
	</div><!-- .page-header -->

	<div class="row justify-content-md-center" id="mainArticleContent">
		<div class="col-lg-3 order-lg-2" id="articleDetailsWrapper">
			<div class="article-details-sidebar" id="articleDetails">

				
								

													<div class="article-details-block article-details-galleys article-details-galleys-sidebar">
													<div class="article-details-galley">
								
	
		

<a class="btn btn-primary" target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/article/view/$articleId/$pdfGalleyId">

		
	PDF
</a>
							</div>
											</div>
				
								

											
													<div class="article-details-block article-details-how-to-cite">
						<h2 class="article-details-heading">
							How to Cite
						</h2>
						<div id="citationOutput" class="article-details-how-to-cite-citation" role="region" aria-live="polite">
							<div class="csl-bib-body">
  <div class="csl-entry">${metadata.authorFullName.split(' ').last}, ${metadata.authorFullName.split(' ').first}. “$title”. <i>Transnational Asia</i>, vol. $volume, no. $issue, ${_getMonth(publishedDate)} $publishedYear, doi:10.25615/ta.v${volume}i$issue.$articleId.</div>
							</div>
						</div>
						<div class="dropdown">
							<button class="btn dropdown-toggle" type="button" id="cslCitationFormatsButton" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false" data-csl-dropdown="true">
								More Citation Formats
							</button>
							<div class="dropdown-menu" aria-labelledby="cslCitationFormatsButton">
																	<a
										class="dropdown-item"
										aria-controls="citationOutput"
										target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/acm-sig-proceedings?submissionId=$articleId&amp;publicationId=$publicationId"
										data-load-citation
										data-json-href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/acm-sig-proceedings?submissionId=$articleId&amp;publicationId=$publicationId&amp;return=json"
									>
										ACM
									</a>
																	<a
										class="dropdown-item"
										aria-controls="citationOutput"
										target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/acs-nano?submissionId=$articleId&amp;publicationId=$publicationId"
										data-load-citation
										data-json-href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/acs-nano?submissionId=$articleId&amp;publicationId=$publicationId&amp;return=json"
									>
										ACS
									</a>
																	<a
										class="dropdown-item"
										aria-controls="citationOutput"
										target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/apa?submissionId=$articleId&amp;publicationId=$publicationId"
										data-load-citation
										data-json-href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/apa?submissionId=$articleId&amp;publicationId=$publicationId&amp;return=json"
									>
										APA
									</a>
																	<a
										class="dropdown-item"
										aria-controls="citationOutput"
										target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/associacao-brasileira-de-normas-tecnicas?submissionId=$articleId&amp;publicationId=$publicationId"
										data-load-citation
										data-json-href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/associacao-brasileira-de-normas-tecnicas?submissionId=$articleId&amp;publicationId=$publicationId&amp;return=json"
									>
										ABNT
									</a>
																	<a
										class="dropdown-item"
										aria-controls="citationOutput"
										target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/chicago-author-date?submissionId=$articleId&amp;publicationId=$publicationId"
										data-load-citation
										data-json-href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/chicago-author-date?submissionId=$articleId&amp;publicationId=$publicationId&amp;return=json"
									>
										Chicago
									</a>
																	<a
										class="dropdown-item"
										aria-controls="citationOutput"
										target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/harvard-cite-them-right?submissionId=$articleId&amp;publicationId=$publicationId"
										data-load-citation
										data-json-href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/harvard-cite-them-right?submissionId=$articleId&amp;publicationId=$publicationId&amp;return=json"
									>
										Harvard
									</a>
																	<a
										class="dropdown-item"
										aria-controls="citationOutput"
										target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/ieee?submissionId=$articleId&amp;publicationId=$publicationId"
										data-load-citation
										data-json-href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/ieee?submissionId=$articleId&amp;publicationId=$publicationId&amp;return=json"
									>
										IEEE
									</a>
																	<a
										class="dropdown-item"
										aria-controls="citationOutput"
										target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/modern-language-association?submissionId=$articleId&amp;publicationId=$publicationId"
										data-load-citation
										data-json-href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/modern-language-association?submissionId=$articleId&amp;publicationId=$publicationId&amp;return=json"
									>
										MLA
									</a>
																	<a
										class="dropdown-item"
										aria-controls="citationOutput"
										target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/turabian-fullnote-bibliography?submissionId=$articleId&amp;publicationId=$publicationId"
										data-load-citation
										data-json-href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/turabian-fullnote-bibliography?submissionId=$articleId&amp;publicationId=$publicationId&amp;return=json"
									>
										Turabian
									</a>
																	<a
										class="dropdown-item"
										aria-controls="citationOutput"
										target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/vancouver?submissionId=$articleId&amp;publicationId=$publicationId"
										data-load-citation
										data-json-href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/get/vancouver?submissionId=$articleId&amp;publicationId=$publicationId&amp;return=json"
									>
										Vancouver
									</a>
																									<h3 class="dropdown-header">
										Download Citation
									</h3>
																			<a class="dropdown-item" target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/download/ris?submissionId=$articleId&amp;publicationId=$publicationId">
											Endnote/Zotero/Mendeley (RIS)
										</a>
																			<a class="dropdown-item" target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/citationstylelanguage/download/bibtex?submissionId=$articleId&amp;publicationId=$publicationId">
											BibTeX
										</a>
																								</div>
						</div>
					</div>
				
																			
				
			</div>
		</div>
		<div class="col-lg-9 order-lg-1" id="articleMainWrapper">
			<div class="article-details-main" id="articleMain">

													<div class="article-details-block article-details-abstract">
<div>
<h2>Abstract</h2>
$abstractHtml
<h2>Keywords</h2>
<p>$keywords</p>
$articleBodyHtml

																									<div class="article-details-block article-details-doi small-screen">
							<a target="_parent" href="https://doi.org/10.25615/ta.v${volume}i$issue.$articleId">https://doi.org/10.25615/ta.v${volume}i$issue.$articleId</a>
						</div>
									
													<div class="article-details-block article-details-galleys article-details-galleys-btm">
													<div class="article-details-galley">
								
	
		

<a class="btn btn-primary" target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/article/view/$articleId/$pdfGalleyId">

		
	PDF
</a>
							</div>
											</div>
				
								
													<div class="article-details-block article-details-license">
																					<a rel="license" target="_parent" href="https://creativecommons.org/licenses/by-nc-nd/4.0/"><img alt="Creative Commons License" src="//i.creativecommons.org/l/by-nc-nd/4.0/88x31.png" /></a><p>This work is licensed under a <a rel="license" target="_parent" href="https://creativecommons.org/licenses/by-nc-nd/4.0/">Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License</a>.</p>
																																								<p>Copyright (c) $publishedYear Transnational Asia</p>
																		</div>
				
				

			</div>
		</div>

		<div class="col-lg-12 order-lg-3 article-footer-hook">
			
		</div>

	</div>
</div>
</div><!-- .page -->

<footer class="site-footer">
	<div class="container site-footer-sidebar" role="complementary"
	     aria-label="Sidebar">
		<div class="row">
			<div class="pkp_block block_information">
	<span class="title">Information</span>
	<div class="content">
		<ul>
							<li>
					<a target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/information/readers">
						For Readers
					</a>
				</li>
										<li>
					<a target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/information/authors">
						For Authors
					</a>
				</li>
										<li>
					<a target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/information/librarians">
						For Librarians
					</a>
				</li>
					</ul>
	</div>
</div>

		</div>
	</div>
	<div class="container site-footer-content">
		<div class="row">
			<div class="col-md site-footer-content align-self-center">
				<p>ISSN: 2474-476X</p>
				<p><a href="https://chaocenter.rice.edu/" target="parent" target="_blank" rel="noopener"><img style="width: 40vw; min-width: 250px; max-width: 500px;" src="https://chaocenter.rice.edu/sites/g/files/bxs3531/files/2020-09/Chao%20Center%20for%20Asian%20Studies%20center%20level%20logo%20formal%20White%20reversed%20horiz.png" alt="CCAS logo" data-entity-type="file"></a></p>
				<p>Journal hosting supported by Fondren Library, Rice University.</p>
								</div>
			
			<div class="col-md col-md-2 align-self-center text-right" role="complementary">
				<a target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/about/aboutThisPublishingSystem">
					<img class="footer-brand-image" alt="More information about the publishing system, Platform and Workflow by OJS/PKP."
					     src="https://transnationalasia.rice.edu/templates/images/ojs_brand_white.png">
				</a>
			</div>
		</div>
	</div>
</footer><!-- pkp_structure_footer_wrapper -->

																					<div
											class="modal fade"
											id="authorBiographyModal1"
											tabindex="-1"
											role="dialog"
											aria-labelledby="authorBiographyModalTitle1"
											aria-hidden="true"
									>
										<div class="modal-dialog" role="document">
											<div class="modal-content">
												<div class="modal-header">
													<div class="modal-title" id="authorBiographyModalTitle1">
														$authorFullName
													</div>
													<button type="button" class="close" data-dismiss="modal" aria-label="Close">
														<span aria-hidden="true">&times;</span>
													</button>
												</div>
												<div class="modal-body">
													$authorBioHtml
												</div>
											</div>
										</div>
									</div>
								
									

<div id="loginModal" class="modal fade" tabindex="-1" role="dialog">
	<div class="modal-dialog" role="document">
		<div class="modal-content">
			<div class="modal-body">
				<button type="button" class="close" data-dismiss="modal" aria-label="Close">
					<span aria-hidden="true">&times;</span>
				</button>
							<form class="form-login" method="post" action="https://transnationalasia.rice.edu/index.php/ta/login/signIn">
	<input type="hidden" name="csrfToken" value="520732b7deada58d4c424bedd5900f34">
								<input type="hidden" name="source" value=""/>

	<fieldset>
		<div class="form-group form-group-username">
			<label for="usernameModal">
				Username
				<span class="required" aria-hidden="true">*</span>
				<span class="sr-only">
					Required
				</span>
			</label>
			<input type="text" class="form-control" name="username" id="usernameModal" value=""
			       maxlength="32" autocomplete="username" required>
		</div>
		<div class="form-group form-group-password">
			<label for="passwordModal">
				Password
				<span class="required" aria-hidden="true">*</span>
				<span class="sr-only">
					Required
				</span>
			</label>
			<input type="password" class="form-control" name="password" id="passwordModal" value=""
			       maxlength="32" autocomplete="current-password" required>
		</div>
		<div class="row">
			<div class="col-md-6">
				<div class="form-group form-group-forgot">
					<small class="form-text">
						<a target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/login/lostPassword">
							Forgot your password?
						</a>
					</small>
				</div>
			</div>
			<div class="col-md-6">
				<div class="form-group form-check form-group-remember">
					<input type="checkbox" class="form-check-input" name="remember" id="rememberModal" value="1"
					       checked="\$remember">
					<label for="rememberModal" class="form-check-label">
						<small class="form-text">
							Keep me logged in
						</small>
					</label>
				</div>
			</div>
		</div>
		<div class="form-group form-group-buttons">
			<button class="btn btn-primary" type="submit">
				Login
			</button>
		</div>
					<div class="form-group form-group-register">
				No account?
								<a target="_parent" href="https://transnationalasia.rice.edu/index.php/ta/user/register?source=">
					Register here
				</a>
			</div>
			</fieldset>
</form>
			</div>
		</div>
	</div>
</div>

<script src="https://transnationalasia.rice.edu/plugins/themes/healthSciences/libs/jquery.min.js?v=3.3.0.14" type="text/javascript"></script><script src="https://transnationalasia.rice.edu/plugins/themes/healthSciences/libs/popper.min.js?v=3.3.0.14" type="text/javascript"></script><script src="https://transnationalasia.rice.edu/plugins/themes/healthSciences/libs/bootstrap.min.js?v=3.3.0.14" type="text/javascript"></script><script src="https://transnationalasia.rice.edu/plugins/themes/healthSciences/js/main.js?v=3.3.0.14" type="text/javascript"></script><script src="https://transnationalasia.rice.edu/plugins/themes/healthSciences/libs/jquery-ui.min.js?v=3.3.0.14" type="text/javascript"></script><script src="https://transnationalasia.rice.edu/plugins/themes/healthSciences/libs/tag-it.min.js?v=3.3.0.14" type="text/javascript"></script><script src="https://transnationalasia.rice.edu/plugins/generic/citationStyleLanguage/js/articleCitation.js?v=3.3.0.14" type="text/javascript"></script>


</body>
</html>
    '''.replaceAll('https://transnationalasia.rice.edu', baseUrl).replaceAll('/ta/', '/$path/');
  }

  String _clean(String text) {
    if (text.isEmpty) return '';
    return text.trim()
        .replaceAll('\uFFFD', "'")
        .replaceAll(RegExp(r'[\u2018\u2019\u201A\u201B\u2032\u2035\u02BC\u02BD\u02C8\u02CA\u02CB\u00B4\u0060\u0090\u0091\u0092]'), "'")
        .replaceAll(RegExp(r'[\u201C\u201D\u201E\u201F\u2033\u2036\u0093\u0094\u00AB\u00BB]'), '"')
        .replaceAll(RegExp(r'[\u2010\u2011\u2012\u2013\u2014\u2015\u2212]'), '-')
        .replaceAll('\uFB01', 'fi')
        .replaceAll('\uFB02', 'fl')
        .replaceAll(RegExp(r'[\u00A0\u1680\u2000-\u200A\u202F\u205F\u3000\uFEFF]'), ' ')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
