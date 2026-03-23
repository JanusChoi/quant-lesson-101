const fs = require('fs');
const path = require('path');

const books = ['主动投资组合管理', '打开量化投资的黑箱'];
const cards = [];
const navigation = {};

function extractMetadata(content, filepath) {
  const bookMatch = filepath.match(/(主动投资组合管理|打开量化投资的黑箱)/);
  const chapterMatch = filepath.match(/第(\d+)章_([^/]+)/);
  const typeMatch = filepath.match(/(概念卡|反常识卡|金句卡|人名卡)/);
  const filenameMatch = filepath.match(/([^/]+)\.md$/);

  const book = bookMatch ? bookMatch[1] : '';
  const chapter = chapterMatch ? `第${chapterMatch[1]}章_${chapterMatch[2]}` : '';
  const type = typeMatch ? typeMatch[1] : '';
  const filename = filenameMatch ? filenameMatch[1] : '';

  return { book, chapter, type, filename };
}

function parseMarkdown(content) {
  const lines = content.split('\n');
  let front = '';
  let back = '';
  let inFront = true;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    if (line.startsWith('## 详解') || line.startsWith('## 实际真相') ||
        line.startsWith('## 贡献') || line.startsWith('## 解读')) {
      inFront = false;
    }

    if (inFront && i > 0) {
      front += line + '\n';
    } else if (!inFront) {
      back += line + '\n';
    }
  }

  return {
    front: front.trim(),
    back: back.trim()
  };
}

function scanDirectory(dir) {
  const files = fs.readdirSync(dir);

  files.forEach(file => {
    const filepath = path.join(dir, file);
    const stat = fs.statSync(filepath);

    if (stat.isDirectory()) {
      scanDirectory(filepath);
    } else if (file.endsWith('.md')) {
      const content = fs.readFileSync(filepath, 'utf-8');
      const meta = extractMetadata(content, filepath);
      const { front, back } = parseMarkdown(content);

      const title = content.match(/^#\s+(.+)$/m)?.[1] || meta.filename;

      cards.push({
        title,
        type: meta.type,
        book: meta.book,
        chapter: meta.chapter,
        filename: meta.filename,
        front,
        back,
        topic: meta.chapter
      });
    }
  });
}

books.forEach(book => {
  const bookPath = path.join(__dirname, book);
  if (fs.existsSync(bookPath)) {
    scanDirectory(bookPath);
  }
});

cards.forEach((card, index) => {
  if (!navigation[card.book]) navigation[card.book] = {};
  if (!navigation[card.book][card.chapter]) navigation[card.book][card.chapter] = [];
  navigation[card.book][card.chapter].push(index);
});

const output = { cards, navigation };
const outputJson = JSON.stringify(output, null, 2);

fs.writeFileSync(
  path.join(__dirname, 'deploy', 'cards_data.json'),
  outputJson
);

fs.writeFileSync(
  path.join(__dirname, 'cards_data.json'),
  outputJson
);

console.log(`✅ 生成 ${cards.length} 张卡片`);
