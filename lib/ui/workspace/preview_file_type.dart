import '../../core/ui_kit.dart' show Ic;

/// The glyph used for a file in the browser and preview.
class FileTypeStyle {
  const FileTypeStyle(this.icon);
  final Ic icon;
}

const _images = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.bmp',
  '.heic',
  '.heif',
  '.svg',
  '.ico'
};
const _archives = {'.zip', '.tar', '.gz', '.bz2', '.xz', '.7z', '.rar', '.tgz'};
const _audioExt = {
  '.mp3',
  '.m4a',
  '.aac',
  '.ogg',
  '.opus',
  '.wav',
  '.flac',
  '.amr'
};
const _videoExt = {'.mp4', '.webm', '.mkv', '.mov', '.avi', '.3gp'};
const _fonts = {'.ttf', '.otf', '.woff', '.woff2'};
const _docExt = {'.pdf', '.doc', '.docx', '.odt', '.rtf', '.epub'};
const _sheetExt = {'.xls', '.xlsx', '.ods', '.csv', '.tsv', '.numbers'};
const _slideExt = {'.ppt', '.pptx', '.odp', '.key'};
const _executables = {'.apk', '.exe', '.so', '.dll', '.dylib', '.bin', '.elf'};

/// Extension only, no content sniffing. The browser calls this for a row it is
/// about to draw and must not read the file to do it.
FileTypeStyle fileTypeStyle(String path) {
  final e = _ext(path);
  if (_docExt.contains(e)) return const FileTypeStyle(Ic.file);
  if (_sheetExt.contains(e)) return const FileTypeStyle(Ic.list);
  if (_slideExt.contains(e)) return const FileTypeStyle(Ic.image);
  if (_archives.contains(e)) return const FileTypeStyle(Ic.storage);
  if (_audioExt.contains(e)) return const FileTypeStyle(Ic.music);
  if (_videoExt.contains(e)) return const FileTypeStyle(Ic.video);
  if (_images.contains(e)) return const FileTypeStyle(Ic.image);
  if (_fonts.contains(e)) return const FileTypeStyle(Ic.textSize);
  if (_executables.contains(e)) return const FileTypeStyle(Ic.gear);
  if (_isTexty(e, path)) return const FileTypeStyle(Ic.fileCode);
  return const FileTypeStyle(Ic.file);
}

/// True for anything the code preview will try to render, plus the dotfiles a
/// model writes often enough to deserve an icon.
bool _isTexty(String e, String path) {
  if (e == '.md' ||
      e == '.markdown' ||
      e == '.html' ||
      e == '.htm' ||
      e == '.xml' ||
      e == '.css' ||
      e == '.dart' ||
      e == '.js' ||
      e == '.ts' ||
      e == '.py' ||
      e == '.java' ||
      e == '.kt' ||
      e == '.go' ||
      e == '.rs' ||
      e == '.c' ||
      e == '.h' ||
      e == '.cpp' ||
      e == '.hpp' ||
      e == '.sh' ||
      e == '.bash' ||
      e == '.json' ||
      e == '.yaml' ||
      e == '.yml' ||
      e == '.toml' ||
      e == '.ini' ||
      e == '.sql' ||
      e == '.log' ||
      e == '.txt' ||
      e == '.lock' ||
      e == '.conf' ||
      e == '.cfg' ||
      e == '.env' ||
      e == '.properties') {
    return true;
  }
  final slash = path.lastIndexOf('/');
  final name = (slash < 0 ? path : path.substring(slash + 1)).toLowerCase();
  return const {
    '.bashrc',
    '.zshrc',
    '.profile',
    '.gitignore',
    '.editorconfig',
    '.dockerignore',
    '.npmrc',
    '.env',
    'dockerfile',
    'makefile',
    'license',
    'readme'
  }.contains(name);
}

String _ext(String path) {
  final slash = path.lastIndexOf('/');
  final dot = path.lastIndexOf('.');
  return dot > slash && dot > 0 ? path.substring(dot).toLowerCase() : '';
}

/// The glyph the browser draws in the icon column.
Ic fileTypeIcon(String path) => fileTypeStyle(path).icon;
