/* CloudTwin task board — vanilla JS client for the FastAPI backend.
   All API calls use relative paths so the same bundle works behind any
   reverse proxy (nginx serves these files and forwards /api/* upstream). */

(function () {
  "use strict";

  var API = "/api/tasks";

  var state = { tasks: [], filter: "all" };

  var els = {
    form: document.getElementById("taskForm"),
    title: document.getElementById("titleInput"),
    desc: document.getElementById("descInput"),
    list: document.getElementById("taskList"),
    empty: document.getElementById("emptyState"),
    error: document.getElementById("errorBox"),
    count: document.getElementById("taskCount"),
    healthDot: document.getElementById("healthDot"),
    healthText: document.getElementById("healthText"),
  };

  /* ---------------- helpers ---------------- */

  function showError(message) {
    els.error.textContent = message;
    els.error.hidden = false;
  }

  function clearError() {
    els.error.hidden = true;
    els.error.textContent = "";
  }

  function escapeHtml(text) {
    var div = document.createElement("div");
    div.textContent = text == null ? "" : String(text);
    return div.innerHTML;
  }

  function formatDate(iso) {
    try {
      return new Date(iso).toLocaleString();
    } catch (e) {
      return iso;
    }
  }

  async function api(path, options) {
    var resp = await fetch(path, options);
    if (!resp.ok) {
      var detail = "";
      try {
        var body = await resp.json();
        detail = body.detail ? " — " + JSON.stringify(body.detail) : "";
      } catch (e) { /* non-JSON error body */ }
      throw new Error("Request failed (" + resp.status + ")" + detail);
    }
    if (resp.status === 204) return null;
    return resp.json();
  }

  /* ---------------- rendering ---------------- */

  function visibleTasks() {
    if (state.filter === "active") return state.tasks.filter(function (t) { return !t.completed; });
    if (state.filter === "completed") return state.tasks.filter(function (t) { return t.completed; });
    return state.tasks;
  }

  function render() {
    var tasks = visibleTasks();
    els.list.innerHTML = "";

    tasks.forEach(function (task) {
      var li = document.createElement("li");
      li.className = "task" + (task.completed ? " done" : "");
      li.innerHTML =
        '<input type="checkbox" class="checkbox" aria-label="Mark complete"' +
        (task.completed ? " checked" : "") +
        ' data-action="toggle" data-id="' + task.id + '">' +
        '<div class="task-body">' +
        '<div class="task-title">' + escapeHtml(task.title) + "</div>" +
        (task.description
          ? '<div class="task-desc">' + escapeHtml(task.description) + "</div>"
          : "") +
        '<div class="task-meta">#' + task.id + " &middot; " + escapeHtml(formatDate(task.created_at)) + "</div>" +
        "</div>" +
        '<button class="btn btn-danger" data-action="delete" data-id="' + task.id + '">Delete</button>';
      els.list.appendChild(li);
    });

    els.empty.hidden = tasks.length !== 0;
    var done = state.tasks.filter(function (t) { return t.completed; }).length;
    els.count.textContent =
      state.tasks.length + " total · " + done + " completed";
  }

  /* ---------------- data ---------------- */

  async function loadTasks() {
    try {
      clearError();
      state.tasks = await api(API);
      render();
    } catch (err) {
      showError("Could not load tasks: " + err.message);
    }
  }

  async function checkHealth() {
    try {
      var resp = await fetch("/health");
      if (resp.ok) {
        els.healthDot.className = "dot ok";
        els.healthText.textContent = "api online";
        return;
      }
      throw new Error("unhealthy");
    } catch (err) {
      els.healthDot.className = "dot down";
      els.healthText.textContent = "api offline";
    }
  }

  /* ---------------- events ---------------- */

  els.form.addEventListener("submit", async function (e) {
    e.preventDefault();
    var title = els.title.value.trim();
    if (!title) {
      showError("Title is required.");
      return;
    }
    try {
      clearError();
      await api(API, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          title: title,
          description: els.desc.value.trim() || null,
        }),
      });
      els.title.value = "";
      els.desc.value = "";
      await loadTasks();
    } catch (err) {
      showError("Could not create task: " + err.message);
    }
  });

  els.list.addEventListener("click", async function (e) {
    var target = e.target;
    var action = target.getAttribute("data-action");
    if (!action) return;
    var id = target.getAttribute("data-id");
    try {
      clearError();
      if (action === "toggle") {
        await api(API + "/" + id, {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ completed: target.checked }),
        });
      } else if (action === "delete") {
        if (!confirm("Delete this task?")) return;
        await api(API + "/" + id, { method: "DELETE" });
      }
      await loadTasks();
    } catch (err) {
      showError("Operation failed: " + err.message);
      await loadTasks(); // re-render to restore checkbox state
    }
  });

  document.querySelectorAll(".chip").forEach(function (chip) {
    chip.addEventListener("click", function () {
      document.querySelectorAll(".chip").forEach(function (c) { c.classList.remove("active"); });
      chip.classList.add("active");
      state.filter = chip.getAttribute("data-filter");
      render();
    });
  });

  /* ---------------- init ---------------- */
  checkHealth();
  loadTasks();
})();
