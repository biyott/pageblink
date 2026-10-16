import '../rag/chunker.dart';

/// One sample note of the demo account.
class DemoSampleNote {
  final String title;
  final String body;

  const DemoSampleNote(this.title, this.body);

  /// Marker: the document's `contentHash` is the body hash (as `saveNote`
  /// stores it), so no extra column or table is needed (research 026 §9).
  String get hash => sha256Hex(body);
}

/// Sample content of the demo account (plan 014 §8), written for PageBlink;
/// no third-party text. Titles must not start with `Sample · ` / `샘플 · `:
/// the Ask screen would show to-do-list example questions (research 026 D6).
/// Each note body stays under one chunk (900 chars).
class DemoSamples {
  static const noteEn = DemoSampleNote('Getting started with PageBlink', r'''
# Getting started with PageBlink

PageBlink answers questions from your own notes and PDFs, and shows where every answer came from.

## Write a note
Tap New note, write in Markdown, and save. A note can be searched a few seconds after you save it.

## Upload a PDF
Tap Upload PDF and pick a file. PageBlink reads it page by page, so an answer can point to the exact page.

## Ask a question
Open the Ask tab and type a question in plain words. Answers are built only from your own documents.

## Follow the source
Tap a ⚡ marker next to an answer to open the note or PDF page it came from.
''');

  static const noteKo = DemoSampleNote('답변의 출처 따라가기', r'''
# 답변의 출처 따라가기

PageBlink는 답변마다 근거가 된 노트나 PDF 페이지를 함께 보여 줍니다.

## 질문하는 법
질문 탭을 열고 궁금한 것을 평소 말투로 적어 보세요. 답변은 내 노트와 PDF의 내용으로만 만들어집니다.

## ⚡ 출처 확인하기
답변 옆의 ⚡ 표시를 누르면 근거가 된 노트나 PDF 페이지가 바로 열립니다. 답변이 맞는지 직접 확인해 보세요.

## 더 정확한 답을 얻으려면
- 질문에 문서 이름이나 주제를 넣어 보세요.
- 노트는 짧은 문단으로 나누어 쓰면 찾기 쉬워요.
- 새 노트는 저장하고 몇 초 뒤부터 검색됩니다.
''');

  static const notes = [noteEn, noteKo];

  /// Title of the sample PDF (English; the pages carry both languages).
  static const pdfTitle = 'PageBlink guide';

  /// Where the original PDF ships (`web/` is the one folder the deploy bundle
  /// is known to contain; research 026 §10). Relative to the working dir.
  static const pdfAsset = 'web/samples/pageblink-guide.pdf';

  /// Per-page text, EN then KO. It must match [pdfAsset] (the same source
  /// produced both) or citation page numbers drift.
  static const pdfPages = [
    r'''
Adding your documents

PageBlink turns what you write and what you upload into something you can ask questions of.

Write a note: tap New note, write in Markdown, and save. A note can be searched a few seconds after saving.

Upload a PDF: tap Upload PDF and choose a file. PageBlink reads the text page by page, so an answer can point to the exact page. Scanned PDFs without text cannot be searched.

문서 추가하기

직접 쓴 노트와 올린 PDF에 질문할 수 있도록 PageBlink가 내용을 정리해 둡니다.

노트 쓰기: 새 노트를 누르고 마크다운으로 쓴 뒤 저장하세요. 저장하고 몇 초 뒤부터 검색됩니다.

PDF 올리기: PDF 올리기를 누르고 파일을 고르세요. 페이지별로 글자를 읽기 때문에 답변이 정확한 페이지를 가리킵니다. 글자가 없는 스캔본 PDF는 검색할 수 없습니다.''',
    r'''
Asking questions

Open the Ask tab and type a question in plain words, for example: What does the guide say about uploading a PDF?

PageBlink finds the most relevant passages in your notes and PDFs and writes an answer from them only. If nothing relevant is found, it tells you instead of guessing.

Tip: mention a topic or a document name in your question to get a more precise answer.

질문하기

질문 탭을 열고 평소 말투로 질문을 적어 보세요. 예: 가이드에서 PDF 올리기는 어떻게 설명하나요?

PageBlink는 내 노트와 PDF에서 가장 관련 있는 부분을 찾아 그 내용만으로 답변을 만듭니다. 관련 내용이 없으면 지어내지 않고 못 찾았다고 알려 줍니다.

팁: 질문에 주제나 문서 이름을 넣으면 더 정확한 답변을 받을 수 있습니다.''',
    r'''
Sources and the demo account

Every answer carries small lightning-bolt markers. Tap one to jump to the note or the PDF page that the answer came from, and check it yourself.

About the demo account: everyone who tries the demo shares one account, so please do not enter personal information. You can create up to 5 notes or PDFs of your own, and they are removed after 24 hours. The sample items cannot be edited or deleted. Questions are limited to 50 per day across all demo visitors. Sign up to keep your work.

출처와 데모 계정

답변마다 작은 번개 모양 표시가 붙습니다. 누르면 답변의 근거가 된 노트나 PDF 페이지로 바로 이동하니 직접 확인해 보세요.

데모 계정 안내: 데모를 체험하는 모든 사람이 하나의 계정을 함께 쓰므로 개인정보는 넣지 마세요. 직접 만들 수 있는 노트와 PDF는 최대 5개이며, 24시간 뒤에 삭제됩니다. 샘플 항목은 수정하거나 삭제할 수 없습니다. 질문은 데모 방문자 전체가 하루 50회까지 할 수 있습니다. 가입하면 계속 쓸 수 있어요.''',
  ];

  /// Marker hash of the sample PDF.
  static final pdfHash = sha256Hex(pdfPages.join('\u0000'));

  /// Every sample marker. A demo document with one of these hashes is a
  /// sample: protected, not counted, never purged.
  static final markers = <String>{...notes.map((n) => n.hash), pdfHash};

  static bool isSampleHash(String contentHash) => markers.contains(contentHash);
}
