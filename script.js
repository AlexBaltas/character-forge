document.querySelectorAll(".character-card").forEach((card) => {
  const toggle = card.querySelector(".card-toggle");
  const body = card.querySelector(".card-body");
  const openLabel = card.querySelector(".open-pill");

  function setOpen(isOpen) {
    card.classList.toggle("is-open", isOpen);
    toggle.setAttribute("aria-expanded", String(isOpen));
    body.hidden = !isOpen;
    openLabel.textContent = isOpen ? "Close" : "Open";
  }

  toggle.addEventListener("click", () => {
    setOpen(toggle.getAttribute("aria-expanded") !== "true");
  });
});
