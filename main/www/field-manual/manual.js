(function() {
  "use strict";

  var article = document.getElementById("manual-content");
  var input = document.getElementById("manual-search");
  var results = document.getElementById("manual-search-results");
  var status = document.getElementById("manual-search-status");
  var sections = Array.from(article.querySelectorAll("details"));
  var timer;

  function fragmentId(hash) {
    try { return decodeURIComponent(hash.slice(1)); }
    catch (error) { return ""; }
  }

  article.querySelectorAll("table").forEach(function(table) {
    table.dataset.columns = table.rows[0].cells.length;
  });

  function reveal(target, focus) {
    if (!target) return;
    var node = target;
    while (node && node !== article) {
      if (node.tagName === "DETAILS") node.open = true;
      node = node.parentElement;
    }
    if (target.nextElementSibling && target.nextElementSibling.tagName === "DETAILS") {
      target.nextElementSibling.open = true;
      target = target.nextElementSibling.querySelector("summary");
    }
    target.scrollIntoView({block: "start"});
    if (focus) {
      if (!target.hasAttribute("tabindex")) target.setAttribute("tabindex", "-1");
      target.focus({preventScroll: true});
    }
  }

  document.addEventListener("click", function(event) {
    var link = event.target.closest("a[href^='#']");
    if (!link) return;
    var target = document.getElementById(fragmentId(link.hash));
    if (!target) return;
    event.preventDefault();
    history.replaceState(null, "", link.hash);
    reveal(target, true);
  });
  window.addEventListener("hashchange", function() {
    reveal(document.getElementById(fragmentId(location.hash)), false);
  });
  if (location.hash) reveal(document.getElementById(fragmentId(location.hash)), false);

  document.getElementById("manual-expand").onclick = function() {
    sections.forEach(function(section) { section.open = true; });
  };
  document.getElementById("manual-collapse").onclick = function() {
    sections.forEach(function(section) { section.open = false; });
  };

  function normal(text) { return text.replace(/\s+/g, " ").trim().toLowerCase(); }
  // Index passages, not duplicate container text. No server request or analytics.
  var passages = Array.from(article.querySelectorAll("h1,h2,h3,summary,p,li,tr,pre"))
    .filter(function(node) {
      return !node.closest("#manual-contents") &&
        !(node.tagName === "P" && node.closest("li,td,th")) &&
        !(node.tagName === "LI" && node.querySelector("li"));
    }).map(function(node, index) {
      var text = node.textContent.replace(/\s+/g, " ").trim();
      if (!node.id) node.id = "manual-passage-" + index;
      var parent = node.closest("details");
      var context = parent ? parent.querySelector("summary").textContent.trim() : "Introduction and authorship";
      return {node: node, text: text, lower: normal(text), context: context};
    });

  function removeHighlights() {
    article.querySelectorAll("mark[data-search]").forEach(function(mark) {
      var parent = mark.parentNode;
      mark.replaceWith(document.createTextNode(mark.textContent));
      parent.normalize();
    });
  }

  function highlight(node, terms) {
    var walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT);
    var texts = [];
    while (walker.nextNode()) texts.push(walker.currentNode);
    texts.forEach(function(text) {
      var value = text.nodeValue;
      var lower = value.toLowerCase();
      var fragment = document.createDocumentFragment();
      var offset = 0;
      while (offset < value.length) {
        var start = -1;
        var length = 0;
        terms.forEach(function(term) {
          var found = lower.indexOf(term, offset);
          if (found !== -1 && (start === -1 || found < start)) {
            start = found;
            length = term.length;
          }
        });
        if (start === -1) { fragment.append(value.slice(offset)); break; }
        fragment.append(value.slice(offset, start));
        var mark = document.createElement("mark");
        mark.dataset.search = "true";
        mark.textContent = value.slice(start, start + length);
        fragment.append(mark);
        offset = start + length;
      }
      text.replaceWith(fragment);
    });
  }

  function search() {
    clearTimeout(timer);
    removeHighlights();
    results.replaceChildren();
    var query = normal(input.value);
    results.hidden = !query;
    status.textContent = "";
    if (!query) return;
    var terms = Array.from(new Set(query.split(" ")));
    var matches = passages.filter(function(passage) {
      return terms.every(function(term) { return passage.lower.includes(term); });
    });
    status.textContent = matches.length ? matches.length + " matching passages" +
      (matches.length > 80 ? " (first 80 shown)." : ".") :
      "No matching passages. Try fewer words or a field name such as nest_id.";
    var list = document.createElement("ol");
    matches.slice(0, 80).forEach(function(passage) {
      var item = document.createElement("li");
      var link = document.createElement("a");
      var first = passage.lower.indexOf(terms[0]);
      var start = Math.max(0, first - 55);
      link.href = "#" + passage.node.id;
      link.textContent = (start ? "…" : "") + passage.text.slice(start, start + 200) +
        (passage.text.length > start + 200 ? "…" : "");
      var context = document.createElement("span");
      context.className = "result-context";
      context.textContent = passage.context;
      item.append(link, context);
      list.append(item);
      highlight(passage.node, terms);
    });
    results.append(list);
  }

  input.addEventListener("input", function() { clearTimeout(timer); timer = setTimeout(search, 160); });
  input.addEventListener("keydown", function(event) {
    if (event.key === "Enter") {
      search();
      var first = results.querySelector("a");
      if (first) first.click();
    }
    if (event.key === "Escape") { input.value = ""; search(); }
  });
  document.getElementById("manual-clear").onclick = function() {
    input.value = ""; search(); input.focus();
  };
  var beforePrint = [];
  window.addEventListener("beforeprint", function() {
    beforePrint = sections.map(function(section) { return section.open; });
    sections.forEach(function(section) { section.open = true; });
  });
  window.addEventListener("afterprint", function() {
    sections.forEach(function(section, index) { section.open = beforePrint[index]; });
  });
})();
