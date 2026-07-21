const previews = {
  working: {
    src: "./assets/working.png",
    width: 170,
    height: 34,
    alt: "Cowlick showing the Scoutly project in its working state",
    caption: "Working. Quietly present.",
  },
  approval: {
    src: "./assets/approval.png",
    width: 380,
    height: 116,
    alt: "Cowlick showing a request-matched Bash approval with explicit Deny and Allow once actions",
    caption: "Approval. Enough context to decide.",
  },
  completed: {
    src: "./assets/completed.png",
    width: 170,
    height: 34,
    alt: "Cowlick showing the Meetly project as completed",
    caption: "Completed. Then out of the way.",
  },
};

const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
const header = document.querySelector("[data-site-header]");
const stage = document.querySelector(".island-stage");
const previewImage = document.querySelector("#island-preview");
const previewCaption = document.querySelector("#island-caption");
const previewButtons = Array.from(document.querySelectorAll("[data-preview]"));
const previewNames = previewButtons.map((button) => button.dataset.preview);
let activePreview = stage?.dataset.mode ?? "working";
let requestedPreview = activePreview;
let previewRequest = 0;
let viewportFrame = 0;

Object.values(previews).forEach((preview) => {
  const image = new Image();
  image.src = preview.src;
});

async function showPreview(name, { moveFocus = false } = {}) {
  const preview = previews[name];
  if (!preview || !stage || !previewImage || !previewCaption) return;

  requestedPreview = name;
  const request = ++previewRequest;
  stateSwitcher?.setAttribute("aria-busy", "true");

  const replacement = new Image();
  replacement.src = preview.src;

  try {
    await replacement.decode();
  } catch {
    if (request === previewRequest) {
      requestedPreview = activePreview;
      stateSwitcher?.removeAttribute("aria-busy");
    }
    return;
  }

  if (request !== previewRequest) return;

  activePreview = name;
  stage.dataset.mode = name;
  previewImage.src = preview.src;
  previewImage.width = preview.width;
  previewImage.height = preview.height;
  previewImage.alt = preview.alt;
  previewCaption.textContent = preview.caption;

  previewButtons.forEach((button) => {
    const isActive = button.dataset.preview === name;
    button.setAttribute("aria-pressed", String(isActive));
    if (moveFocus && isActive) button.focus();
  });
  stateSwitcher?.removeAttribute("aria-busy");

  if (!reducedMotion.matches) {
    previewImage.animate(
      [
        { opacity: 0.35, transform: "translateY(-0.35rem) scale(0.965)" },
        { opacity: 1, transform: "translateY(0) scale(1)" },
      ],
      { duration: 280, easing: "cubic-bezier(0.22, 1, 0.36, 1)" },
    );
  }
}

previewButtons.forEach((button) => {
  button.addEventListener("click", () => showPreview(button.dataset.preview));
});

const stateSwitcher = document.querySelector(".state-switcher");
stateSwitcher?.removeAttribute("hidden");
stateSwitcher?.addEventListener("keydown", (event) => {
  const currentIndex = previewNames.indexOf(requestedPreview);
  let nextIndex = currentIndex;

  if (event.key === "ArrowRight" || event.key === "ArrowDown") {
    nextIndex = (currentIndex + 1) % previewNames.length;
  } else if (event.key === "ArrowLeft" || event.key === "ArrowUp") {
    nextIndex = (currentIndex - 1 + previewNames.length) % previewNames.length;
  } else if (event.key === "Home") {
    nextIndex = 0;
  } else if (event.key === "End") {
    nextIndex = previewNames.length - 1;
  } else {
    return;
  }

  event.preventDefault();
  showPreview(previewNames[nextIndex], { moveFocus: true });
});

function updateViewportState() {
  const scrollY = window.scrollY;
  header?.toggleAttribute("data-scrolled", scrollY > 48);

  const marker = window.innerHeight * 0.38;
  let currentSection = null;

  if (scrollY > window.innerHeight * 0.48) {
    document.querySelectorAll(".nav-links a[href^='#']").forEach((link) => {
      const section = document.querySelector(link.getAttribute("href"));
      if (section && section.getBoundingClientRect().top <= marker) currentSection = link;
    });
  }

  document.querySelectorAll(".nav-links a[href^='#']").forEach((link) => {
    if (link === currentSection) {
      link.setAttribute("aria-current", "location");
    } else {
      link.removeAttribute("aria-current");
    }
  });

  viewportFrame = 0;
}

function requestViewportUpdate() {
  if (viewportFrame) return;
  viewportFrame = window.requestAnimationFrame(updateViewportState);
}

window.addEventListener("scroll", requestViewportUpdate, { passive: true });
window.addEventListener("resize", requestViewportUpdate, { passive: true });
updateViewportState();

document.querySelectorAll("[data-copy-target]").forEach((button) => {
  button.removeAttribute("hidden");
  button.addEventListener("click", async () => {
    const target = document.getElementById(button.dataset.copyTarget);
    const feedback = button.parentElement?.querySelector(".copy-feedback");
    if (!target || !feedback) return;

    window.clearTimeout(button.resetTimer);
    button.disabled = true;
    button.setAttribute("aria-busy", "true");

    try {
      await navigator.clipboard.writeText(target.textContent.trim());
      button.textContent = "Copied";
      feedback.textContent = "Commands copied to the clipboard.";
    } catch {
      feedback.textContent = "Copy was unavailable. Select the commands above instead.";
    } finally {
      button.disabled = false;
      button.removeAttribute("aria-busy");
    }

    button.resetTimer = window.setTimeout(() => {
      button.textContent = "Copy commands";
      feedback.textContent = "";
    }, 3200);
  });
});
