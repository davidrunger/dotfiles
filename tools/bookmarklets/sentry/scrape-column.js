// Paste this into e.g. https://caiorss.github.io/bookmarklet-maker/ to convert
// this to bookmarklet code.

window.answer = [];
const columnIndex = parseInt(prompt('Zero-indexed column number?'), 10);

function scrapeColumn() {
  document
    .querySelectorAll('[data-test-id=grid-body-cell]')
    .forEach((element, index) => {
      if (index % 12 === columnIndex) answer.push(element.innerText);
    });

  console.log(answer);

  const nextButton = document.querySelector('[aria-label="Next"]:not([disabled])');

  if (nextButton) {
    nextButton.click();
  } else {
    clearInterval(interval);
    console.log('Done! Run `copy(window.answer)`.');
  }
}

const interval = setInterval(scrapeColumn, 5000);
scrapeColumn();
