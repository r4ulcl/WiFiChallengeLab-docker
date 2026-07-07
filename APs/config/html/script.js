/* WiFiChallenge by r4ulcl · copy recovered key off the device */
function copyFlagToClipboard(flag) {
  var e = window.event;
  var btn = e && e.target && e.target.closest ? e.target.closest('button') : null;
  function ok() {
    if (!btn) return;
    btn.classList.add('copied');
    setTimeout(function () { btn.classList.remove('copied'); }, 1500);
  }
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(flag).then(ok).catch(ok);
  } else {
    ok();
  }
}
