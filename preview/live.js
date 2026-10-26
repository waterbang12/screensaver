// Live reload: scripts/preview-server.mjs sends "reload" when files under
// preview/, shared/ or ios/Shared/ change. Settings survive the reload
// because they live in localStorage.
(function () {
  const badge = document.getElementById("live");
  if (!location.protocol.startsWith("http") || !window.EventSource) return;
  const source = new EventSource("/__events");
  source.onopen = () => { badge.textContent = "live"; badge.classList.add("on"); };
  source.onerror = () => { badge.textContent = "reconnecting"; badge.classList.remove("on"); };
  source.onmessage = (event) => { if (event.data === "reload") location.reload(); };
})();
