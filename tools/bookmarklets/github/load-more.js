// Paste this into e.g. https://caiorss.github.io/bookmarklet-maker/ to convert
// this to bookmarklet code.

const targetSelector = ".ajax-pagination-btn";
const targetText = "Load more";

function setButtonClickTimeouts() {
  const loadMoreButtons = [...document.querySelectorAll(targetSelector)].filter(
    (el) => el.innerText.includes(targetText)
  );

  [...loadMoreButtons, "setIntervalPlaceholder"].forEach((el, index) => {
    setTimeout(() => {
      if (el.click) {
        el.click();
      } else if (
        el === "setIntervalPlaceholder" &&
        !window.githubBookmarkletLoadMoreInterval
      ) {
        window.githubBookmarkletLoadMoreInterval = setInterval(
          setButtonClickTimeouts,
          1000
        );
      }
    }, index * 300);
  });
}

setButtonClickTimeouts();
