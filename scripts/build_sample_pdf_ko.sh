#!/usr/bin/env bash
# Builds the Korean-only demo sample PDF:
#   app/pageblink_server/web/samples/pageblink-guide-ko.pdf
#
# The text below MUST equal `SamplePacks.demoPdfKo.pages` in
# app/pageblink_server/lib/src/sample/sample_pack.dart (one \pg per page),
# and its numbers must equal lib/src/demo/demo_config.dart
# (demoCreateLimit = 5, demoRetention = 24 h, demoAskDailyLimit = 50).
# Change the text -> change the Dart pages (the pack hash changes with them).
#
# Needs XeLaTeX (TeX Live, packages fontspec geometry fancyhdr xcolor) and the
# Pretendard OTF files (SIL OFL 1.1, same family as the app): set
# PRETENDARD_DIR to the folder that holds Pretendard-Regular.otf and
# Pretendard-SemiBold.otf (default ~/Library/Fonts). Fonts are embedded as
# subset CID fonts, so the text stays extractable (not outlines).
# No network. The PDF date is pinned, so a rebuild only differs when the text does.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/app/pageblink_server/web/samples/pageblink-guide-ko.pdf"
fonts="${PRETENDARD_DIR:-$HOME/Library/Fonts}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cat > "$work/guide.tex" <<'TEX'
\documentclass[12pt]{article}
\usepackage[a4paper,left=62pt,right=62pt,top=64pt,bottom=64pt,headheight=14pt,headsep=14pt]{geometry}
\usepackage{xcolor,fontspec,fancyhdr}
\setmainfont{Pretendard-Regular.otf}[Path=FONTDIR/,BoldFont=Pretendard-SemiBold.otf]
\definecolor{gray}{gray}{0.45}
\pagestyle{fancy}\fancyhf{}\renewcommand{\headrulewidth}{0pt}
\fancyhead[L]{\color{gray}\footnotesize PageBlink 가이드 \quad·\quad \thepage\ / 3}
\setlength{\parindent}{0pt}\setlength{\parskip}{8pt}\linespread{1.25}\raggedright
% A wider word space: PDF readers rebuild spaces from gaps, and the narrow
% default one is lost between wide Hangul glyphs (words run together).
\spaceskip=0.40em plus 0.08em minus 0.03em
\newcommand{\pg}[1]{\vspace*{4pt}{\bfseries\fontsize{17.2}{22}\selectfont #1}\par\vspace{2pt}}
\begin{document}

\pg{문서 추가하기}

직접 쓴 노트와 올린 PDF에 질문할 수 있도록 PageBlink가 내용을 정리해 둡니다.

노트 쓰기: 새 노트를 누르고 마크다운으로 쓴 뒤 저장하세요. 저장하고 몇 초 뒤부터 검색됩니다.

PDF 올리기: PDF 올리기를 누르고 파일을 고르세요. 페이지별로 글자를 읽기 때문에 답변이 정확한 페이지를 가리킵니다. 글자가 없는 스캔본 PDF는 검색할 수 없습니다.

\newpage
\pg{질문하기}

질문 탭을 열고 평소 말투로 질문을 적어 보세요. 예: 가이드에서 PDF 올리기는 어떻게 설명하나요?

PageBlink는 내 노트와 PDF에서 가장 관련 있는 부분을 찾아 그 내용만으로 답변을 만듭니다. 관련 내용이 없으면 지어내지 않고 못 찾았다고 알려 줍니다.

팁: 질문에 주제나 문서 이름을 넣으면 더 정확한 답변을 받을 수 있습니다.

\newpage
\pg{출처와 데모 계정}

답변마다 작은 번개 모양 표시가 붙습니다. 누르면 답변의 근거가 된 노트나 PDF 페이지로 바로 이동하니 직접 확인해 보세요.

데모 계정 안내: 데모를 체험하는 모든 사람이 하나의 계정을 함께 쓰므로 개인정보는 넣지 마세요. 직접 만들 수 있는 노트와 PDF는 최대 5개이며, 24시간 뒤에 삭제됩니다. 샘플 항목은 수정하거나 삭제할 수 없습니다. 질문은 데모 방문자 전체가 하루 50회까지 할 수 있습니다. 가입하면 계속 쓸 수 있어요.

\end{document}
TEX
sed -i.bak "s|FONTDIR|$fonts|" "$work/guide.tex"

cd "$work"
# Pinned dates: identical input gives a byte-identical PDF.
SOURCE_DATE_EPOCH=1792110000 FORCE_SOURCE_DATE=1 \
  xelatex -interaction=nonstopmode -halt-on-error guide.tex >/dev/null
mkdir -p "$(dirname "$out")"
cp guide.pdf "$out"
echo "wrote $out ($(wc -c < "$out") bytes)"
