const main = document.querySelector('main');
const pages = new Map([...main.querySelectorAll(':scope > article')].map(page => [page.id, page]));
const links = [...document.querySelectorAll('[data-page-link]')];
let current;
let diagramCount = 0;

globalThis.mermaid?.initialize({ startOnLoad: false, securityLevel: 'strict', flowchart: { htmlLabels: false } });

async function drawDiagrams(page) {
  if (!globalThis.mermaid) return;
  for (const diagram of page.querySelectorAll('.diagram')) {
    if (diagram.dataset.rendered) continue;
    diagram.dataset.rendered = 'true';
    const source = diagram.querySelector('pre');
    try {
      const { svg } = await globalThis.mermaid.render('diagram-' + ++diagramCount, source.textContent);
      const picture = document.createElement('div');
      picture.innerHTML = svg;
      diagram.replaceChildren(picture);
    } catch {
      const caption = document.createElement('figcaption');
      caption.textContent = '图表未能渲染，下面是原始定义。';
      diagram.prepend(caption);
    }
  }
}

function showPage() {
  const [id, heading] = location.hash.slice(1).split('/', 2);
  const page = pages.get(id) ?? pages.get(main.dataset.initial);
  if (current !== page) {
    if (current) current.hidden = true;
    page.hidden = false;
    current = page;
    for (const link of links) {
      if (link.dataset.pageLink === page.id) {
        link.setAttribute('aria-current', 'page');
        const group = link.closest('details');
        if (group) group.open = true;
      } else {
        link.removeAttribute('aria-current');
      }
    }
  }
  let anchor;
  try {
    if (heading && id === page.id) anchor = document.getElementById(id + '/' + decodeURIComponent(heading));
  } catch {
    // Invalid bookmarks still open the note.
  }
  if (anchor) anchor.scrollIntoView();
  else window.scrollTo(0, 0);
  drawDiagrams(page);
}

window.addEventListener('hashchange', showPage);
showPage();
