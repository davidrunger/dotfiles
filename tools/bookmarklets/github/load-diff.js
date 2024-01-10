const targetSelector = ".js-button-text";
const targetText = "Load diff";

function setButtonClickTimeouts() {
  console.log("running setButtonClickTimeouts");

  const loadDiffButtons = [...document.querySelectorAll(targetSelector)].filter(
    (el) => el.innerText.includes(targetText)
  );

  [...loadDiffButtons, "setIntervalPlaceholder"].forEach((el, index) => {
    console.log("el", el);

    setTimeout(() => {
      if (el.click) {
        console.log("el click", el);

        el.click();
      } else if (
        el === "setIntervalPlaceholder" &&
        !window.githubBookmarkletLoadMoreInterval
      ) {
        console.log("setting up interval");

        window.githubBookmarkletLoadMoreInterval = setInterval(
          setButtonClickTimeouts,
          1000
        );
      }
    }, index * 300);
  });
}

setButtonClickTimeouts();
