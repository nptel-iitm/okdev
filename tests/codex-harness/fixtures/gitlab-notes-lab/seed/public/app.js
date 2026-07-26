let token = null;
let user = null;
const $ = (id) => document.getElementById(id);

async function api(path, options = {}) {
  const headers = { "Content-Type": "application/json", ...(options.headers || {}) };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(path, { ...options, headers });
  return { status: res.status, data: await res.json().catch(() => ({})) };
}

async function refresh() {
  const { data } = await api("/api/notes");
  const notes = data.notes || [];
  $("note-list").innerHTML = notes
    .map((n) => `<li><h3>${n.title}</h3><p>${n.body}</p></li>`)
    .join("");
  $("empty-state").hidden = notes.length > 0;
}

function render() {
  $("signin-view").hidden = !!user;
  $("notes-view").hidden = !user;
  $("signout").hidden = !user;
  $("who").textContent = user || "";
  if (user) refresh();
}

$("signin-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const { status, data } = await api("/api/signin", {
    method: "POST",
    body: JSON.stringify({ email: $("email").value.trim(), password: $("password").value }),
  });
  if (status === 200) {
    token = data.token;
    user = data.email;
    $("signin-err").textContent = "";
    render();
  } else {
    $("signin-err").textContent = data.error || "Sign in failed.";
  }
});

$("note-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  await api("/api/notes", {
    method: "POST",
    body: JSON.stringify({ title: $("note-title").value, body: $("note-body").value }),
  });
  $("note-title").value = "";
  $("note-body").value = "";
  refresh();
});

$("signout").addEventListener("click", () => {
  token = null;
  user = null;
  render();
});

render();
