import { useEffect, useMemo, useRef, useState } from "react";
import {
  API_BASE_URL,
  clearAdminToken,
  createAchievement,
  createBook,
  createCategory,
  createMenuItem,
  createNotification,
  createReadingList,
  deleteAchievement,
  deleteBook,
  deleteCategory,
  deleteMenuItem,
  deleteNotification,
  deleteReadingList,
  getAdminBootstrap,
  getAdminSession,
  getAdminToken,
  getContentVersion,
  listStoryImages,
  loginAdmin,
  setAdminToken,
  updateAchievement,
  updateBook,
  updateCategory,
  updateMenuItem,
  updateNotification,
  updateProfile,
  updateReadingList,
  updateSupportRequest,
  updateWriteScreen,
  uploadImage,
} from "./api";

const EMPTY_CATEGORY = { name: "", topic_count: 0, tab_group: "explore", sort_order: 999 };
const EMPTY_BOOK = {
  title: "",
  author: "",
  description: "",
  cover_path: "",
  accent_hex: "#119c95",
  section_name: "recently_updated",
  status_text: "Draft",
  rating: 0,
  genre: "",
  cta_label: "Read now",
  sort_order: 999,
};
const EMPTY_NOTIFICATION = { tab: "Story", title: "", message: "", created_at: "Now" };
const EMPTY_MENU = { section: "Support", section_order: 1, label: "", icon: "help", route: "/" };
const EMPTY_LIST = { name: "", story_count: 0, cover_path: "", sort_order: 999 };
const EMPTY_ACHIEVEMENT = {
  group_name: "Lifetime Words Published",
  group_order: 2,
  title: "",
  subtitle: "",
  progress: 0,
  total: 100,
  style: "ink",
  sort_order: 999,
};

function safeConfirm(message) {
  return window.confirm(message);
}

function asArray(value) {
  return Array.isArray(value) ? value : [];
}

function normalizeNotification(item) {
  return {
    ...item,
    tab: item.tab ?? item.tab_name ?? "Story",
  };
}

function normalizeMenuItem(item) {
  return {
    ...item,
    section: item.section ?? item.section_name ?? "General",
    icon: item.icon ?? item.icon_name ?? "menu",
    route: item.route ?? item.route_name ?? "/",
  };
}

function normalizeAchievement(item) {
  const progressLabel = item.progress_label || "0/0";
  const [current, total] = progressLabel.split("/");
  return {
    ...item,
    progress: Number.parseInt(current || "0", 10) || 0,
    total:
      Number.parseInt((total || "0").split(" ")[0], 10) ||
      Number.parseInt(item.badge_value || "0", 10) ||
      0,
  };
}

export default function App() {
  const [tokenReady, setTokenReady] = useState(Boolean(getAdminToken()));
  const [session, setSession] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [contentVersion, setContentVersion] = useState("");

  const [categories, setCategories] = useState([]);
  const [books, setBooks] = useState([]);
  const [notifications, setNotifications] = useState([]);
  const [menuItems, setMenuItems] = useState([]);
  const [writeScreen, setWriteScreen] = useState({
    manage_tabs: ["Manage Stories", "Analytics"],
    story_tabs: ["Submitted", "Drafts"],
    filter_label: "All stories",
    sort_label: "Recently Updated",
    empty_title: "You have not submitted any story yet",
    empty_cta: "Submit Stories",
  });
  const [profile, setProfile] = useState({
    display_name: "",
    username: "",
    following: 0,
    followers: 0,
    blocked: 0,
    chapters_read: 0,
    social_karma: 0,
    day_streak: 0,
  });
  const [readingLists, setReadingLists] = useState([]);
  const [achievements, setAchievements] = useState([]);
  const [supportRequests, setSupportRequests] = useState([]);
  const [storyImages, setStoryImages] = useState([]);

  const [categoryForm, setCategoryForm] = useState(EMPTY_CATEGORY);
  const [bookForm, setBookForm] = useState(EMPTY_BOOK);
  const [notificationForm, setNotificationForm] = useState(EMPTY_NOTIFICATION);
  const [menuForm, setMenuForm] = useState(EMPTY_MENU);
  const [listForm, setListForm] = useState(EMPTY_LIST);
  const [achievementForm, setAchievementForm] = useState(EMPTY_ACHIEVEMENT);
  const [uploadingImage, setUploadingImage] = useState(false);
  const uploadInputRef = useRef(null);

  const stats = useMemo(
    () => ({
      categories: categories.length,
      books: books.length,
      notifications: notifications.length,
      menuItems: menuItems.length,
      lists: readingLists.length,
      achievements: achievements.length,
      supportRequests: supportRequests.length,
    }),
    [categories, books, notifications, menuItems, readingLists, achievements, supportRequests]
  );

  async function loadImages() {
    const payload = await listStoryImages();
    setStoryImages(asArray(payload.items));
  }

  async function loadData({ silent = false } = {}) {
    try {
      if (!silent) {
        setLoading(true);
      }
      setError("");
      const [sessionPayload, bootstrapPayload, versionPayload] = await Promise.all([
        getAdminSession(),
        getAdminBootstrap(),
        getContentVersion(),
      ]);
      setSession(sessionPayload);
      setCategories(asArray(bootstrapPayload.categories));
      setBooks(asArray(bootstrapPayload.books));
      setNotifications(asArray(bootstrapPayload.notifications).map(normalizeNotification));
      setMenuItems(asArray(bootstrapPayload.menu_items).map(normalizeMenuItem));
      setWriteScreen(bootstrapPayload.write_screen || writeScreen);
      setProfile(bootstrapPayload.profile || profile);
      setReadingLists(asArray(bootstrapPayload.reading_lists));
      setAchievements(asArray(bootstrapPayload.achievements).map(normalizeAchievement));
      setSupportRequests(asArray(bootstrapPayload.support_requests));
      setContentVersion(versionPayload.value || "");
      await loadImages();
      setTokenReady(true);
    } catch (err) {
      clearAdminToken();
      setSession(null);
      setTokenReady(false);
      setError(err.message || "Failed to load admin data");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (!tokenReady) {
      return undefined;
    }

    loadData();
    return undefined;
  }, [tokenReady]);

  useEffect(() => {
    if (!tokenReady || !contentVersion) {
      return undefined;
    }

    const intervalId = window.setInterval(async () => {
      try {
        const payload = await getContentVersion();
        if (payload.value && payload.value !== contentVersion) {
          setSuccess("Content changed. Dashboard refreshed.");
          await loadData({ silent: true });
        }
      } catch (_) {}
    }, 5000);

    return () => window.clearInterval(intervalId);
  }, [contentVersion, tokenReady]);

  async function submitCreate(action, resetForm, successMessage) {
    try {
      setError("");
      await action();
      resetForm();
      setSuccess(successMessage);
      await loadData({ silent: true });
    } catch (err) {
      setError(err.message || "Action failed");
    }
  }

  async function submitDelete(action, message, successMessage) {
    if (!safeConfirm(message)) return;
    try {
      setError("");
      await action();
      setSuccess(successMessage);
      await loadData({ silent: true });
    } catch (err) {
      setError(err.message || "Delete failed");
    }
  }

  async function quickUpdate(action, successMessage = "Saved") {
    try {
      setError("");
      await action();
      setSuccess(successMessage);
      await loadData({ silent: true });
    } catch (err) {
      setError(err.message || "Update failed");
    }
  }

  async function handleLogin(credentials) {
    try {
      setError("");
      const payload = await loginAdmin(credentials);
      setAdminToken(payload.token);
      setSession({ username: payload.username });
      setSuccess("Admin login successful.");
      setTokenReady(true);
    } catch (err) {
      setError(err.message || "Login failed");
    }
  }

  function handleLogout() {
    clearAdminToken();
    setTokenReady(false);
    setSession(null);
    setContentVersion("");
    setSuccess("");
  }

  async function handleImageUpload(event) {
    const file = event.target.files?.[0];
    if (!file) return;

    try {
      setUploadingImage(true);
      const payload = await uploadImage(file);
      setBookForm((current) => ({ ...current, cover_path: payload.path }));
      setSuccess("Cover image uploaded.");
      await loadImages();
    } catch (err) {
      setError(err.message || "Image upload failed");
    } finally {
      setUploadingImage(false);
      event.target.value = "";
    }
  }

  if (!tokenReady) {
    return (
      <LoginScreen
        apiBaseUrl={API_BASE_URL}
        error={error}
        onLogin={handleLogin}
      />
    );
  }

  return (
    <div className="admin-shell">
      <header className="hero">
        <div>
          <p className="eyebrow">Inkitt-style CMS</p>
          <h1>Admin Control Panel</h1>
          <p className="subtitle">
            Manage the Flutter app catalogue, menus, notifications, profile data, and seeded story imagery.
          </p>
        </div>
        <div className="hero-actions">
          <div className="endpoint">API: {API_BASE_URL}</div>
          <div className="endpoint">Live sync key: {contentVersion || "waiting..."}</div>
          <div className="endpoint">Signed in as: {session?.username || "admin"}</div>
          <button type="button" className="ghost-button" onClick={() => loadData()}>
            Refresh
          </button>
          <button type="button" className="ghost-button" onClick={handleLogout}>
            Log out
          </button>
        </div>
      </header>

      <section className="stats-grid">
        <article className="stat-card"><p>Categories</p><h3>{stats.categories}</h3></article>
        <article className="stat-card"><p>Stories</p><h3>{stats.books}</h3></article>
        <article className="stat-card"><p>Notifications</p><h3>{stats.notifications}</h3></article>
        <article className="stat-card"><p>Menu Items</p><h3>{stats.menuItems}</h3></article>
        <article className="stat-card"><p>Reading Lists</p><h3>{stats.lists}</h3></article>
        <article className="stat-card"><p>Achievements</p><h3>{stats.achievements}</h3></article>
        <article className="stat-card"><p>Support</p><h3>{stats.supportRequests}</h3></article>
      </section>

      {error ? <div className="error-banner">{error}</div> : null}
      {success ? <div className="success-banner">{success}</div> : null}
      {loading ? <p className="loading">Loading admin data...</p> : null}

      <section className="panel-grid">
        <article className="panel panel-wide">
          <div className="panel-heading">
            <div>
              <h2>Stories</h2>
              <p>Create a story, upload a cover, or bind one of the seeded dummy images.</p>
            </div>
          </div>
          <form
            className="form-grid"
            onSubmit={(e) => {
              e.preventDefault();
              submitCreate(
                () =>
                  createBook({
                    ...bookForm,
                    rating: Number(bookForm.rating || 0),
                    sort_order: Number(bookForm.sort_order || 0),
                  }),
                () => setBookForm(EMPTY_BOOK),
                "Story created"
              );
            }}
          >
            <div className="story-form-grid">
              <div className="story-cover-column">
                <div className="cover-preview-frame">
                  {bookForm.cover_path ? (
                    <img src={`${API_BASE_URL}${bookForm.cover_path}`} alt="Selected cover" className="cover-preview" />
                  ) : (
                    <div className="cover-placeholder">Select cover</div>
                  )}
                </div>
                <input ref={uploadInputRef} hidden type="file" accept="image/*" onChange={handleImageUpload} />
                <button
                  type="button"
                  className="ghost-button"
                  onClick={() => uploadInputRef.current?.click()}
                  disabled={uploadingImage}
                >
                  {uploadingImage ? "Uploading..." : "Upload Cover"}
                </button>
                <input
                  placeholder="Cover path"
                  value={bookForm.cover_path}
                  onChange={(e) => setBookForm((current) => ({ ...current, cover_path: e.target.value }))}
                />
              </div>

              <div className="story-fields-column">
                <input placeholder="Title" value={bookForm.title} onChange={(e) => setBookForm((current) => ({ ...current, title: e.target.value }))} required />
                <input placeholder="Author" value={bookForm.author} onChange={(e) => setBookForm((current) => ({ ...current, author: e.target.value }))} required />
                <input placeholder="Primary genre" value={bookForm.genre} onChange={(e) => setBookForm((current) => ({ ...current, genre: e.target.value }))} required />
                <textarea placeholder="Description" rows={4} value={bookForm.description} onChange={(e) => setBookForm((current) => ({ ...current, description: e.target.value }))} />
                <div className="inline-grid inline-grid-3">
                  <select value={bookForm.section_name} onChange={(e) => setBookForm((current) => ({ ...current, section_name: e.target.value }))}>
                    <option value="featured">featured</option>
                    <option value="recently_updated">recently_updated</option>
                    <option value="recently_completed">recently_completed</option>
                  </select>
                  <input type="number" step="0.1" min="0" max="5" value={bookForm.rating} onChange={(e) => setBookForm((current) => ({ ...current, rating: Number(e.target.value || 0) }))} />
                  <input type="number" value={bookForm.sort_order} onChange={(e) => setBookForm((current) => ({ ...current, sort_order: Number(e.target.value || 0) }))} />
                </div>
                <div className="inline-grid inline-grid-2">
                  <input placeholder="Accent hex" value={bookForm.accent_hex} onChange={(e) => setBookForm((current) => ({ ...current, accent_hex: e.target.value }))} />
                  <input placeholder="Status text" value={bookForm.status_text} onChange={(e) => setBookForm((current) => ({ ...current, status_text: e.target.value }))} />
                </div>
                <button type="submit">Create Story</button>
              </div>
            </div>

            <div className="asset-strip">
              {storyImages.map((image) => (
                <button
                  type="button"
                  key={image.path}
                  className={`asset-chip ${bookForm.cover_path === image.path ? "asset-chip-selected" : ""}`}
                  onClick={() => setBookForm((current) => ({ ...current, cover_path: image.path }))}
                >
                  <img src={`${API_BASE_URL}${image.path}`} alt={image.name} />
                  <span>{image.name}</span>
                </button>
              ))}
            </div>
          </form>

          <SimpleTable
            headers={["Cover", "Title", "Section", "Rating", "Genre", "Action"]}
            rows={books.map((row) => [
              <StoryThumb path={row.cover_path} alt={row.title} apiBaseUrl={API_BASE_URL} />,
              row.title,
              <InlineSelect
                value={row.section_name}
                options={["featured", "recently_updated", "recently_completed"]}
                onChange={(value) => quickUpdate(() => updateBook(row.id, { ...row, section_name: value }), "Story updated")}
              />,
              <InlineNumber
                value={row.rating}
                step="0.1"
                onChange={(value) => quickUpdate(() => updateBook(row.id, { ...row, rating: value }), "Story updated")}
              />,
              row.genre,
              <span className="actions">
                <button
                  type="button"
                  onClick={() => {
                    const title = window.prompt("Title", row.title);
                    if (title == null) return;
                    quickUpdate(() => updateBook(row.id, { ...row, title }), "Story updated");
                  }}
                >
                  Edit
                </button>
                <button type="button" className="danger" onClick={() => submitDelete(() => deleteBook(row.id), "Delete this story?", "Story deleted")}>
                  Delete
                </button>
              </span>,
            ])}
          />
        </article>

        <article className="panel">
          <h2>Categories</h2>
          <form
            className="form-grid"
            onSubmit={(e) => {
              e.preventDefault();
              submitCreate(
                () => createCategory({
                  ...categoryForm,
                  topic_count: Number(categoryForm.topic_count || 0),
                  sort_order: Number(categoryForm.sort_order || 0),
                }),
                () => setCategoryForm(EMPTY_CATEGORY),
                "Category created"
              );
            }}
          >
            <input placeholder="Name" value={categoryForm.name} onChange={(e) => setCategoryForm((current) => ({ ...current, name: e.target.value }))} required />
            <select value={categoryForm.tab_group} onChange={(e) => setCategoryForm((current) => ({ ...current, tab_group: e.target.value }))}>
              <option value="discover">discover</option>
              <option value="explore">explore</option>
            </select>
            <div className="inline-grid inline-grid-2">
              <input type="number" placeholder="Topic count" value={categoryForm.topic_count} onChange={(e) => setCategoryForm((current) => ({ ...current, topic_count: Number(e.target.value || 0) }))} />
              <input type="number" placeholder="Sort" value={categoryForm.sort_order} onChange={(e) => setCategoryForm((current) => ({ ...current, sort_order: Number(e.target.value || 0) }))} />
            </div>
            <button type="submit">Create Category</button>
          </form>
          <SimpleTable
            headers={["Name", "Group", "Count", "Sort", "Action"]}
            rows={categories.map((row) => [
              row.name,
              <InlineSelect value={row.tab_group} options={["discover", "explore"]} onChange={(value) => quickUpdate(() => updateCategory(row.id, { ...row, tab_group: value }), "Category updated")} />,
              <InlineNumber value={row.topic_count} onChange={(value) => quickUpdate(() => updateCategory(row.id, { ...row, topic_count: value }), "Category updated")} />,
              <InlineNumber value={row.sort_order} onChange={(value) => quickUpdate(() => updateCategory(row.id, { ...row, sort_order: value }), "Category updated")} />,
              <button type="button" className="danger" onClick={() => submitDelete(() => deleteCategory(row.id), "Delete this category?", "Category deleted")}>Delete</button>,
            ])}
          />
        </article>

        <article className="panel">
          <h2>Notifications</h2>
          <form className="form-grid" onSubmit={(e) => { e.preventDefault(); submitCreate(() => createNotification(notificationForm), () => setNotificationForm(EMPTY_NOTIFICATION), "Notification created"); }}>
            <input placeholder="Tab" value={notificationForm.tab} onChange={(e) => setNotificationForm((current) => ({ ...current, tab: e.target.value }))} required />
            <input placeholder="Title" value={notificationForm.title} onChange={(e) => setNotificationForm((current) => ({ ...current, title: e.target.value }))} required />
            <textarea placeholder="Message" rows={2} value={notificationForm.message} onChange={(e) => setNotificationForm((current) => ({ ...current, message: e.target.value }))} required />
            <button type="submit">Create Notification</button>
          </form>
          <SimpleTable
            headers={["Tab", "Title", "Message", "Action"]}
            rows={notifications.map((row) => [
              row.tab,
              row.title,
              row.message,
              <span className="actions">
                <button type="button" onClick={() => {
                  const title = window.prompt("Title", row.title);
                  if (title == null) return;
                  quickUpdate(() => updateNotification(row.id, { ...row, title }), "Notification updated");
                }}>Edit</button>
                <button type="button" className="danger" onClick={() => submitDelete(() => deleteNotification(row.id), "Delete this notification?", "Notification deleted")}>Delete</button>
              </span>,
            ])}
          />
        </article>

        <article className="panel">
          <h2>Menu Items</h2>
          <form className="form-grid" onSubmit={(e) => { e.preventDefault(); submitCreate(() => createMenuItem(menuForm), () => setMenuForm(EMPTY_MENU), "Menu item created"); }}>
            <input placeholder="Section" value={menuForm.section} onChange={(e) => setMenuForm((current) => ({ ...current, section: e.target.value }))} required />
            <div className="inline-grid inline-grid-2">
              <input placeholder="Label" value={menuForm.label} onChange={(e) => setMenuForm((current) => ({ ...current, label: e.target.value }))} required />
              <input placeholder="Icon" value={menuForm.icon} onChange={(e) => setMenuForm((current) => ({ ...current, icon: e.target.value }))} required />
            </div>
            <input placeholder="Route" value={menuForm.route} onChange={(e) => setMenuForm((current) => ({ ...current, route: e.target.value }))} required />
            <button type="submit">Create Menu Item</button>
          </form>
          <SimpleTable
            headers={["Section", "Label", "Route", "Action"]}
            rows={menuItems.map((row) => [
              row.section,
              row.label,
              row.route,
              <span className="actions">
                <button type="button" onClick={() => {
                  const route = window.prompt("Route", row.route);
                  if (route == null) return;
                  quickUpdate(() => updateMenuItem(row.id, { ...row, route }), "Menu item updated");
                }}>Edit</button>
                <button type="button" className="danger" onClick={() => submitDelete(() => deleteMenuItem(row.id), "Delete this menu item?", "Menu item deleted")}>Delete</button>
              </span>,
            ])}
          />
        </article>

        <article className="panel">
          <h2>Write Screen Config</h2>
          <form className="form-grid" onSubmit={(e) => { e.preventDefault(); quickUpdate(() => updateWriteScreen(writeScreen), "Write screen updated"); }}>
            <input value={writeScreen.filter_label || ""} onChange={(e) => setWriteScreen((current) => ({ ...current, filter_label: e.target.value }))} placeholder="Filter label" />
            <input value={writeScreen.sort_label || ""} onChange={(e) => setWriteScreen((current) => ({ ...current, sort_label: e.target.value }))} placeholder="Sort label" />
            <input value={writeScreen.empty_title || ""} onChange={(e) => setWriteScreen((current) => ({ ...current, empty_title: e.target.value }))} placeholder="Empty title" />
            <input value={writeScreen.empty_cta || ""} onChange={(e) => setWriteScreen((current) => ({ ...current, empty_cta: e.target.value }))} placeholder="Empty CTA" />
            <button type="submit">Save Write Config</button>
          </form>
        </article>

        <article className="panel">
          <h2>Profile</h2>
          <form className="form-grid" onSubmit={(e) => { e.preventDefault(); quickUpdate(() => updateProfile(profile), "Profile updated"); }}>
            <input value={profile.display_name || ""} onChange={(e) => setProfile((current) => ({ ...current, display_name: e.target.value }))} placeholder="Display name" />
            <input value={profile.username || ""} onChange={(e) => setProfile((current) => ({ ...current, username: e.target.value }))} placeholder="Username" />
            <div className="inline-grid inline-grid-3">
              <input type="number" value={profile.followers || 0} onChange={(e) => setProfile((current) => ({ ...current, followers: Number(e.target.value || 0) }))} placeholder="Followers" />
              <input type="number" value={profile.following || 0} onChange={(e) => setProfile((current) => ({ ...current, following: Number(e.target.value || 0) }))} placeholder="Following" />
              <input type="number" value={profile.day_streak || 0} onChange={(e) => setProfile((current) => ({ ...current, day_streak: Number(e.target.value || 0) }))} placeholder="Day streak" />
            </div>
            <button type="submit">Save Profile</button>
          </form>
        </article>

        <article className="panel">
          <h2>Reading Lists</h2>
          <form className="form-grid" onSubmit={(e) => { e.preventDefault(); submitCreate(() => createReadingList({ ...listForm, story_count: Number(listForm.story_count || 0) }), () => setListForm(EMPTY_LIST), "Reading list created"); }}>
            <input placeholder="List name" value={listForm.name} onChange={(e) => setListForm((current) => ({ ...current, name: e.target.value }))} required />
            <div className="inline-grid inline-grid-2">
              <input type="number" placeholder="Story count" value={listForm.story_count} onChange={(e) => setListForm((current) => ({ ...current, story_count: Number(e.target.value || 0) }))} />
              <input type="number" placeholder="Sort" value={listForm.sort_order} onChange={(e) => setListForm((current) => ({ ...current, sort_order: Number(e.target.value || 0) }))} />
            </div>
            <input placeholder="Cover path" value={listForm.cover_path} onChange={(e) => setListForm((current) => ({ ...current, cover_path: e.target.value }))} />
            <button type="submit">Create Reading List</button>
          </form>
          <SimpleTable
            headers={["Name", "Count", "Cover", "Action"]}
            rows={readingLists.map((row) => [
              row.name,
              row.story_count,
              row.cover_path,
              <span className="actions">
                <button type="button" onClick={() => {
                  const name = window.prompt("List name", row.name);
                  if (name == null) return;
                  quickUpdate(() => updateReadingList(row.id, { ...row, name }), "Reading list updated");
                }}>Edit</button>
                <button type="button" className="danger" onClick={() => submitDelete(() => deleteReadingList(row.id), "Delete this reading list?", "Reading list deleted")}>Delete</button>
              </span>,
            ])}
          />
        </article>

        <article className="panel">
          <h2>Support Requests</h2>
          <SimpleTable
            headers={["From", "Issue", "Subject", "Status", "Action"]}
            rows={supportRequests.map((row) => [
              `${row.first_name} (${row.email})`,
              row.issue,
              row.subject,
              <InlineSelect
                value={row.status || "open"}
                options={["open", "in_progress", "resolved"]}
                onChange={(value) => quickUpdate(() => updateSupportRequest(row.id, { status: value }), "Support request updated")}
              />,
              <button type="button" onClick={() => window.alert([
                row.description || "No description",
                row.device_type ? `Device: ${row.device_type}` : "",
                row.attachment_path ? `Attachment: ${API_BASE_URL}${row.attachment_path}` : "",
              ].filter(Boolean).join("\n\n"))}>View</button>,
            ])}
          />
        </article>

        <article className="panel">
          <h2>Achievements</h2>
          <form className="form-grid" onSubmit={(e) => { e.preventDefault(); submitCreate(() => createAchievement({ ...achievementForm, progress: Number(achievementForm.progress || 0), total: Number(achievementForm.total || 0) }), () => setAchievementForm(EMPTY_ACHIEVEMENT), "Achievement created"); }}>
            <input placeholder="Group name" value={achievementForm.group_name} onChange={(e) => setAchievementForm((current) => ({ ...current, group_name: e.target.value }))} />
            <input placeholder="Title" value={achievementForm.title} onChange={(e) => setAchievementForm((current) => ({ ...current, title: e.target.value }))} required />
            <input placeholder="Subtitle" value={achievementForm.subtitle} onChange={(e) => setAchievementForm((current) => ({ ...current, subtitle: e.target.value }))} />
            <div className="inline-grid inline-grid-2">
              <input type="number" placeholder="Progress" value={achievementForm.progress} onChange={(e) => setAchievementForm((current) => ({ ...current, progress: Number(e.target.value || 0) }))} />
              <input type="number" placeholder="Total" value={achievementForm.total} onChange={(e) => setAchievementForm((current) => ({ ...current, total: Number(e.target.value || 0) }))} />
            </div>
            <button type="submit">Create Achievement</button>
          </form>
          <SimpleTable
            headers={["Title", "Progress", "Action"]}
            rows={achievements.map((row) => [
              row.title,
              `${row.progress}/${row.total}`,
              <span className="actions">
                <button type="button" onClick={() => {
                  const title = window.prompt("Title", row.title);
                  if (title == null) return;
                  quickUpdate(() => updateAchievement(row.id, { ...row, title }), "Achievement updated");
                }}>Edit</button>
                <button type="button" className="danger" onClick={() => submitDelete(() => deleteAchievement(row.id), "Delete this achievement?", "Achievement deleted")}>Delete</button>
              </span>,
            ])}
          />
        </article>
      </section>
    </div>
  );
}

function LoginScreen({ apiBaseUrl, error, onLogin }) {
  const [form, setForm] = useState({
    username: "admin_Supun",
    password: "Ux3@f=7x2",
  });
  const [submitting, setSubmitting] = useState(false);

  return (
    <div className="login-shell">
      <div className="login-panel">
        <p className="eyebrow">Admin access</p>
        <h1>Sign in to manage Inkitt</h1>
        <p className="subtitle">The admin panel uses a signed token and talks directly to your FastAPI backend.</p>
        <form
          className="form-grid"
          onSubmit={async (event) => {
            event.preventDefault();
            setSubmitting(true);
            try {
              await onLogin(form);
            } finally {
              setSubmitting(false);
            }
          }}
        >
          <input value={form.username} onChange={(event) => setForm((current) => ({ ...current, username: event.target.value }))} placeholder="Username" required />
          <input type="password" value={form.password} onChange={(event) => setForm((current) => ({ ...current, password: event.target.value }))} placeholder="Password" required />
          <button type="submit" disabled={submitting}>{submitting ? "Signing in..." : "Sign in"}</button>
        </form>
        {error ? <div className="error-banner">{error}</div> : null}
        <div className="endpoint">API: {apiBaseUrl}</div>
      </div>
    </div>
  );
}

function StoryThumb({ path, alt, apiBaseUrl }) {
  if (!path) {
    return <div className="story-thumb story-thumb-placeholder">No cover</div>;
  }

  return <img className="story-thumb" src={`${apiBaseUrl}${path}`} alt={alt} />;
}

function SimpleTable({ headers, rows }) {
  return (
    <div className="table-wrap">
      <table>
        <thead>
          <tr>
            {headers.map((header) => <th key={header}>{header}</th>)}
          </tr>
        </thead>
        <tbody>
          {rows.length === 0 ? (
            <tr>
              <td colSpan={headers.length}>No records</td>
            </tr>
          ) : (
            rows.map((cells, index) => (
              <tr key={index}>
                {cells.map((cell, cellIndex) => <td key={cellIndex}>{cell}</td>)}
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );
}

function InlineSelect({ value, options, onChange }) {
  return (
    <select value={value || ""} onChange={(event) => onChange(event.target.value)}>
      {options.map((option) => <option key={option} value={option}>{option}</option>)}
    </select>
  );
}

function InlineNumber({ value, onChange, step = "1" }) {
  return (
    <input
      type="number"
      step={step}
      value={Number(value || 0)}
      onChange={(event) => onChange(Number(event.target.value || 0))}
    />
  );
}
