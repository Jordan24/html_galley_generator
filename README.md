# HTML Galley Generator

An open-source macOS and Windows Flutter desktop application that automates the creation of Open Journal Systems (OJS) HTML "Galley Wrapper" files from PDF inputs.

## Features
- **PDF Metadata Extraction**: Drag and drop a PDF file to automatically extract Title, Author, Volume, Issue, and DOI/Article ID.
- **Customizable Fields**: Edit any extracted fields before generating the HTML.
- **Journal Settings Persistence**: Remembers your Journal Base URL and Path across sessions so you don't have to re-enter them.
- **Automated File Naming**: Generates the output filename matching standard formatting (e.g. `Vol+7+No+1_2_COLLINS_Archives+as+Bridges.html`).
- **OJS Compatible**: Generates an HTML wrapper file ready for upload to Open Journal Systems.

## Building from Source

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed on your machine.
- To build for macOS, you need Xcode installed.
- To build for Windows, you need Visual Studio installed.

### Steps
1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/html_galley_generator.git
   cd html_galley_generator
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run -d macos  # or -d windows
   ```
4. Build release binary:
   ```bash
   flutter build macos   # or flutter build windows
   ```

## Contributing
We welcome contributions! Please see the [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to submit pull requests, bug reports, and feature requests.

## Code of Conduct
Please note that this project is released with a Contributor [Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
