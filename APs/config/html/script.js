function copyFlagToClipboard(flag) {
  navigator.clipboard.writeText(flag).then(() => alert('Flag copied to clipboard!'));
}