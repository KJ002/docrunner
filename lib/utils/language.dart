import 'dart:io';
import '../constants/language_abbrev.dart';
import '../exceptions/docrunner_error.dart';
import '../exceptions/docrunner_warning.dart';
import '../models/options.dart';
import '../models/snippet.dart';
import 'file.dart';
import 'general.dart';
import 'package:dotenv/dotenv.dart' as dotenv show load;

final LANGUAGE_TO_EXTENSION = {
  'python': 'py',
  'javascript': 'js',
  'typescript': 'ts',
  'dart': 'dart',
};

Future<String> createLanguageDirectory({
  required String language,
  required String markdownPath,
  String? directoryPath,
}) async {
  if (directoryPath == null) {
    final markdownFileName = File(markdownPath).pathWithoutExtension;
    final languageExtension = LANGUAGE_TO_EXTENSION[language];

    directoryPath = './docrunner-build-$languageExtension/$markdownFileName';
    var directory = Directory(directoryPath);
    final directoryExists = await directory.exists();

    if (directoryExists == false) {
      directory = await directory.create(recursive: true);
    }
  }

  return directoryPath;
}

Future<List<String>> getLanguageFiles({required Options options}) async {
  final codeFilepaths = await createLanguageFiles(options: options);
  return codeFilepaths.keys.toList();
}

Future<Map<String, int>> createLanguageFiles({required Options options}) async {
  final language = options.language!;
  final markdownPaths = options.markdownPaths!;
  final multiFile = options.multiFile!;
  final recursive = options.recursive;

  // ignore: omit_local_variable_types
  Map<String, int> codeFilepaths = {};

  // ignore: omit_local_variable_types
  List<String> noRun = [];

  for (var markdownPath in markdownPaths) {
    final isDirectory = await Directory(markdownPath).exists();
    if (isDirectory) {
      final pathsFromDirectory = await createLanguageFiles(
        options: Options(
          language: options.language,
          markdownPaths: getAllFilePaths(
            directoryPath: markdownPath,
            fileExtensions: ['.md'],
            recursive: recursive ?? false,
          ),
          directoryPath: options.directoryPath,
          startupCommand: options.startupCommand,
          multiFile: options.multiFile,
          dotenv: options.dotenv,
        ),
      );

      codeFilepaths = mergeMapWithAdditions(maps: [
        codeFilepaths,
        pathsFromDirectory,
      ]);

      return codeFilepaths;
    }

    final codeSnippets = await getSnippetsFromMarkdown(
      language: language,
      markdownPath: markdownPath,
    );

    final tempDirectoryPath = await createLanguageDirectory(
      language: language,
      markdownPath: markdownPath,
      directoryPath: options.directoryPath,
    );

    String? filepath;

    if (multiFile) {
      for (var i = 0; i < codeSnippets.length; i++) {
        filepath =
            '$tempDirectoryPath/file${i + 1}.${LANGUAGE_TO_EXTENSION[language]}';

        if (codeSnippets[i].options.filename != null) {
          filepath = '$tempDirectoryPath/${codeSnippets[i].options.filename}';
        }

        filepath = File(filepath).absolute.path;

        if (codeFilepaths.containsKey(filepath)) {
          codeFilepaths[filepath] = codeFilepaths[filepath]! + 1;
        } else {
          codeFilepaths[filepath] = 1;
        }

        if (codeSnippets[i].options.noRun) {
          noRun.add(filepath);
        }

        await writeFile(
          filepath: filepath,
          content: codeSnippets[i].code,
          overwrite: true,
          append: codeFilepaths[filepath]! > 1 ? true : false,
        );
      }
    } else {
      final allLines =
          codeSnippets.map((snippet) => snippet.code).toList().join('');

      filepath = '$tempDirectoryPath/main.${LANGUAGE_TO_EXTENSION[language]}';
      filepath = File(filepath).absolute.path;

      if (codeFilepaths.containsKey(filepath)) {
        codeFilepaths[filepath] = codeFilepaths[filepath]! + 1;
      } else {
        codeFilepaths[filepath] = 1;
      }

      await writeFile(
        filepath: filepath,
        content: allLines,
        overwrite: true,
      );
    }
  }

  codeFilepaths.removeWhere((key, value) {
    return noRun.contains(key);
  });

  if (options.dotenv != null) {
    final dotenvFile = File(options.dotenv!);
    final dotenvFileExists = await dotenvFile.exists();
    if (dotenvFileExists) {
      dotenv.load(dotenvFile.path);
    }
  }

  return codeFilepaths;
}

bool _isSnippetDecorator({required String string}) {
  final isMarkdownComment = ({required String string}) {
    return string.length >= 4 &&
        string.substring(0, 4) == '<!--' &&
        string.substring(string.length - 3) == '-->';
  };

  if (isMarkdownComment(string: string)) {
    if (string.contains('docrunner')) {
      return true;
    }
  }

  return false;
}

String _getCompleteSnippet({
  required String language,
  required List<String> lines,
  required int lineNumber,
}) {
  var code = '';
  var foundClosed = false;
  for (var i = lineNumber + 1; i < lines.length; i++) {
    if (lines[i].length > 3 &&
        lines[i].substring(0, 3) == '```' &&
        LANGUAGE_ABBREV_MAPPING[language]!.contains(lines[i]) == false) {
      throw DocrunnerError(
        message: 'Found opening ``` before closing ```',
      );
    } else if (lines[i] == '```') {
      foundClosed = true;
      break;
    } else {
      code += '${lines[i]}\n';
    }
  }
  if (foundClosed == false) {
    throw DocrunnerError(message: 'No closing ```');
  }

  return code;
}

bool _isAnyLanguageOpening({required String string}) {
  for (var language in LANGUAGE_ABBREV_MAPPING.keys) {
    if (LANGUAGE_ABBREV_MAPPING[language]!.contains(string)) {
      return true;
    }
  }
  return false;
}

Future<List<Snippet>> getSnippetsFromMarkdown({
  required String language,
  required String markdownPath,
}) async {
  final markdownLines = await readFile(filepath: markdownPath);
  // ignore: omit_local_variable_types
  List<Snippet> codeSnippets = [];

  int? lastCodeSnippetAt;
  int? lastDecoratorLine;

  for (var i = 0; i < markdownLines.length - 2; i++) {
    // ignore: omit_local_variable_types
    List<String> snippetDecorators = [];

    if (LANGUAGE_ABBREV_MAPPING[language]!.contains(markdownLines[i])) {
      if (lastCodeSnippetAt == i) {
        continue;
      }

      lastCodeSnippetAt = i;
      final code = _getCompleteSnippet(
        language: language,
        lines: markdownLines,
        lineNumber: i,
      );

      codeSnippets.add(Snippet.create(
        code: code,
        decorators: [],
      ));
    } else if (_isSnippetDecorator(string: markdownLines[i])) {
      lastDecoratorLine = i;
      snippetDecorators.add(markdownLines[i]);

      for (var j = i + 1; j < markdownLines.length; j++) {
        if (LANGUAGE_ABBREV_MAPPING[language]!.contains(markdownLines[j])) {
          if (lastCodeSnippetAt == j) {
            continue;
          }
          if (!_isSnippetDecorator(string: markdownLines[j - 1])) {
            snippetDecorators = [];
          }

          lastCodeSnippetAt = j;
          final code = _getCompleteSnippet(
            language: language,
            lines: markdownLines,
            lineNumber: j,
          );

          codeSnippets.add(
            Snippet.create(
              code: code,
              decorators: snippetDecorators,
            ),
          );
          break;
        } else if (_isSnippetDecorator(string: markdownLines[j])) {
          lastDecoratorLine = j;
          snippetDecorators.add(markdownLines[j]);
        } else if (!_isSnippetDecorator(string: markdownLines[j]) &&
            !_isAnyLanguageOpening(string: markdownLines[j])) {
          if (lastDecoratorLine == j - 1) {
            final commentWarning = DocrunnerWarning(
              message:
                  'Docrunner comment found without code snippet at line $j in `$markdownPath`',
            );

            stdout.writeln(commentWarning.coloredMessage);
          }
        }
      }
    }
  }

  codeSnippets = codeSnippets.where((snippet) {
    return snippet.options.ignore == false;
  }).toList();

  if (codeSnippets.isEmpty) {
    final nothingToRun = DocrunnerWarning(
      message: 'Nothing to run in `$markdownPath`',
    );
    stdout.writeln(nothingToRun.coloredMessage);
  }

  return codeSnippets;
}
