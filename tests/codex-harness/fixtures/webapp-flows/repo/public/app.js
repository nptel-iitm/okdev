const USERS = { "demo@example.com": "correct-horse" };
let notes = [];
let user = null;

const $ = (id) => document.getElementById(id);

function render() {
  $("signin-view").hidden = !!user;
  $("notes-view").hidden = !user;
  $("signout").hidden = !user;
  $("who").textContent = user || "";
  $("note-list").innerHTML = notes
    .map((n) => `<li><h3>${n.title}</h3><p>${n.body}</p></li>`)
    .join("");
  $("empty-state").hidden = notes.length > 0;
}

$("signin-form").addEventListener("submit", (e) => {
  e.preventDefault();
  const email = $("email").value.trim();
  const password = $("password").value;
  if (USERS[email] === password) {
    user = email;
    $("signin-err").textContent = "";
    render();
  } else {
    $("signin-err").textContent = "Email or password is incorrect.";
  }
});

$("note-form").addEventListener("submit", (e) => {
  e.preventDefault();
  // A note with no title is accepted and renders as an empty heading.
  notes.push({ title: $("note-title").value, body: $("note-body").value });
  $("note-title").value = "";
  $("note-body").value = "";
  render();
});

$("signout").addEventListener("click", () => {
  user = null;
  render();
});

render();
