/* WiFiChallenge by r4ulcl · copy recovered key off the device */

/* Fallback for insecure contexts (plain HTTP, where navigator.clipboard is
   undefined). Returns true only if the copy actually succeeded. */
function copyLegacy(text) {
  try {
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.setAttribute('readonly', '');
    ta.style.position = 'fixed';
    ta.style.top = '-1000px';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    ta.setSelectionRange(0, ta.value.length);
    var ok = document.execCommand('copy');
    document.body.removeChild(ta);
    return ok;
  } catch (err) {
    return false;
  }
}

function copyFlagToClipboard(flag, btn) {
  function done(ok) {
    if (!btn) return;
    var label = btn.getAttribute('data-label') || btn.textContent;
    btn.setAttribute('data-label', label);
    btn.classList.remove('copied', 'failed');
    btn.classList.add(ok ? 'copied' : 'failed');
    btn.textContent = ok ? 'COPIED' : 'SELECT + CTRL-C';
    setTimeout(function () {
      btn.classList.remove('copied', 'failed');
      btn.textContent = label;
    }, 1500);
  }

  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(flag).then(
      function () { done(true); },
      function () { done(copyLegacy(flag)); }
    );
  } else {
    done(copyLegacy(flag));
  }
}

/* Delegated: the flag text lives in .flag > .flag-text so it stays selectable
   with the mouse, and the COPY button never carries the key inline. */
document.addEventListener('click', function (ev) {
  var btn = ev.target && ev.target.closest ? ev.target.closest('.flag-copy') : null;
  if (!btn) return;

  var wrap = btn.closest('.flag');
  var text = wrap ? wrap.querySelector('.flag-text') : null;
  if (!text) return;

  copyFlagToClipboard(text.textContent.trim(), btn);
});
