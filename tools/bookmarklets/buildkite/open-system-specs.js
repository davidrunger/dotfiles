// Paste this into e.g. https://caiorss.github.io/bookmarklet-maker/ to convert
// this to bookmarklet code.

text = "System Spec";

[...$(".job-name")].forEach((jobBar) => {
  if (jobBar.innerText.includes(text)) {
    jobBar.click();
  }
});
