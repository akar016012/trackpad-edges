// Set these when a build is ready. An empty link keeps the download marked as coming soon.
const release = {
  url: "",
  version: "",
};

const pad = document.getElementById("pad");
const readout = document.getElementById("readout");
const announcer = document.getElementById("announcer");
const dimmer = document.getElementById("dimmer");
const trackLength = 220;
// This keeps the text and focus rings readable at the lowest brightness.
const darkest = 0.3;
// A press must travel this far to count as a slide, as it must in the app.
const deadZone = 6;

const state = {
  volume: 9,
  brightness: 16,
  seek: 8,
  muted: false,
  playing: true,
};

function formatTime(seconds) {
  const whole = Math.round(seconds);
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, "0")}`;
}

function tick() {
  pad.classList.remove("is-ticking");
  // Reading the size restarts the animation on each step.
  void pad.offsetWidth;
  pad.classList.add("is-ticking");
  if (navigator.userActivation?.hasBeenActive) {
    navigator.vibrate?.(8);
  }
}

const controls = {
  volume: {
    steps: 16,
    describe: (value) =>
      state.muted ? "Volume is muted." : `Volume is at ${value} of 16.`,
    apply() {
      if (state.muted) {
        state.muted = false;
        document.getElementById("mute").setAttribute("aria-pressed", "false");
      }
    },
  },
  brightness: {
    steps: 16,
    describe: (value) => `Brightness is at ${value} of 16.`,
    apply(value) {
      // The demo dims itself, because that is the honest way to show brightness in a web page.
      dimmer.style.opacity = String(((16 - value) / 16) * darkest);
    },
  },
  seek: {
    steps: 20,
    describe: (value) =>
      `Seeking to ${formatTime((value / 20) * trackLength)} of ${formatTime(trackLength)}.`,
    apply() {},
  },
};

function render(name) {
  const control = controls[name];
  const element = document.getElementById(name);
  const value = state[name];
  element.style.setProperty("--value", `${(value / control.steps) * 100}%`);
  element.setAttribute("aria-valuenow", String(value));
  element.setAttribute("aria-valuetext", control.describe(value));
}

function setValue(name, next) {
  const control = controls[name];
  const value = Math.min(Math.max(next, 0), control.steps);
  if (value === state[name]) {
    return;
  }
  state[name] = value;
  control.apply(value);
  render(name);
  readout.textContent = control.describe(value);
  tick();
}

function connect(name) {
  const element = document.getElementById(name);
  const control = controls[name];
  const isVertical = element.getAttribute("aria-orientation") === "vertical";
  let slide = null;

  function position(event) {
    return isVertical ? -event.clientY : event.clientX;
  }

  element.addEventListener("pointerdown", (event) => {
    if (event.button !== 0) {
      return;
    }
    element.setPointerCapture(event.pointerId);
    slide = { start: position(event), value: state[name], engaged: false };
  });
  element.addEventListener("pointermove", (event) => {
    if (!slide) {
      return;
    }
    const travel = position(event) - slide.start;
    if (!slide.engaged && Math.abs(travel) < deadZone) {
      return;
    }
    slide.engaged = true;
    const box = element.getBoundingClientRect();
    const length = isVertical ? box.height : box.width;
    setValue(name, slide.value + Math.round((travel / length) * control.steps));
  });
  function finish() {
    // A screen reader hears the result once, and the slider itself reports keyboard changes.
    if (slide?.engaged) {
      announcer.textContent = control.describe(state[name]);
    }
    slide = null;
  }
  element.addEventListener("pointerup", finish);
  element.addEventListener("pointercancel", finish);
  element.addEventListener("keydown", (event) => {
    const change = { ArrowUp: 1, ArrowRight: 1, ArrowDown: -1, ArrowLeft: -1 }[
      event.key
    ];
    if (change) {
      event.preventDefault();
      setValue(name, state[name] + change);
    } else if (event.key === "Home") {
      event.preventDefault();
      setValue(name, 0);
    } else if (event.key === "End") {
      event.preventDefault();
      setValue(name, control.steps);
    }
  });
  render(name);
}

Object.keys(controls).forEach(connect);

function report(text) {
  readout.textContent = text;
  announcer.textContent = text;
  tick();
}

const mute = document.getElementById("mute");
mute.addEventListener("click", () => {
  state.muted = !state.muted;
  mute.setAttribute("aria-pressed", String(state.muted));
  render("volume");
  report(controls.volume.describe(state.volume));
});

const play = document.getElementById("play");
play.addEventListener("click", () => {
  state.playing = !state.playing;
  play.querySelector("span").textContent = state.playing ? "Pause" : "Play";
  report(state.playing ? "Playing." : "Paused.");
});

document.getElementById("previous").addEventListener("click", () => {
  report("Skipped to the previous track.");
});

document.getElementById("next").addEventListener("click", () => {
  report("Skipped to the next track.");
});

// The page opens by ticking the volume up to its level, which shows what a slide feels like.
function openWithTicks() {
  if (matchMedia("(prefers-reduced-motion: reduce)").matches) {
    return;
  }
  const strip = document.getElementById("volume");
  let shown = 0;
  strip.style.setProperty("--value", "0%");
  const timer = setInterval(() => {
    shown += 1;
    if (shown > state.volume) {
      stop();
      return;
    }
    strip.style.setProperty(
      "--value",
      `${(shown / controls.volume.steps) * 100}%`,
    );
    tick();
  }, 80);
  // Any use of the volume controls takes over from the opening.
  function stop() {
    clearInterval(timer);
    render("volume");
  }
  strip.addEventListener("pointerdown", stop, { once: true });
  strip.addEventListener("keydown", stop, { once: true });
  mute.addEventListener("click", stop, { once: true });
}

openWithTicks();

if (release.url) {
  const link = document.getElementById("download-link");
  link.href = release.url;
  link.hidden = false;
  document.getElementById("coming-soon").hidden = true;
  if (release.version) {
    const version = document.getElementById("version");
    version.textContent = `Version ${release.version}`;
    version.hidden = false;
  }
}
