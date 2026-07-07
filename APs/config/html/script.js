/* WiFiChallenge by r4ulcl · copy recovered key off the device */
function copyFlagToClipboard(flag) {
  var e = window.event;
  var btn = e && e.target && e.target.closest ? e.target.closest('button') : null;

  function done() {
    if (!btn) return;
    btn.classList.add('copied');
    setTimeout(function () { btn.classList.remove('copied'); }, 1500);
  }

  /* Fallback for insecure contexts (plain HTTP, where navigator.clipboard
     is undefined). Returns true only if the copy actually succeeded. */
  function legacy() {
    try {
      var ta = document.createElement('textarea');
      ta.value = flag;
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

  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(flag).then(done, function () { if (legacy()) done(); });
  } else if (legacy()) {
    done();
  }
}
