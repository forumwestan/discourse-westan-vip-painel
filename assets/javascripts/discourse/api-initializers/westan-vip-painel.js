import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";

const cache = new Map();
const usernameCache = new Map();
let pending = new Set();
let pendingUsernames = new Set();
let scheduled = false;
let scanTimer = null;
let inFlight = false;
let lastFetchAt = 0;
let backoffUntil = 0;
let observer;

const SCAN_DEBOUNCE_MS = 450;
const REQUEST_THROTTLE_MS = 1_500;
const RATE_LIMIT_BACKOFF_MS = 60_000;
const MAX_BATCH_SIZE = 80;

function styleForNickname(style) {
  if (!style) {
    return "";
  }
  return [
    `background-image:linear-gradient(120deg, ${style.from}, ${style.to}, ${style.from})`,
    "background-size:220% 220%",
    "-webkit-background-clip:text",
    "background-clip:text",
    "color:transparent",
  ].join(";");
}

function escapeHtml(value) {
  return String(value || "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function badgeHtml(theme) {
  if (!theme) {
    return "";
  }

  const safeName = escapeHtml(theme.name);
  const safeBackground = escapeHtml(theme.badgeBackgroundUrl);
  const safeLogo = escapeHtml(theme.logoUrl);
  const background = theme.badgeBackgroundUrl
    ? theme.badgeBackgroundIsVideo
      ? `<video class="westan-vip-post-badge__bg" src="${safeBackground}" autoplay loop muted playsinline></video>`
      : `<img class="westan-vip-post-badge__bg" src="${safeBackground}" alt="">`
    : "";
  const content = theme.logoUrl
    ? `<img class="westan-vip-post-badge__logo" src="${safeLogo}" alt="${safeName}">`
    : `<span>${escapeHtml(theme.badgeText || "VIP")}</span>`;

  return `<span class="westan-vip-post-badge" title="${safeName}">${background}${content}</span>`;
}

function findPostUserId(post) {
  return post.dataset.userId || post.getAttribute("data-user-id");
}

function findPostUsername(post) {
  const userCard =
    post.querySelector("[data-user-card]") ||
    post.querySelector(".topic-meta-data .names a") ||
    post.querySelector(".names a");
  return userCard?.dataset?.userCard || userCard?.textContent?.trim()?.replace(/^@/, "");
}

function decoratePost(post, data) {
  const nameLink =
    post.querySelector(".topic-meta-data .names a") ||
    post.querySelector(".topic-meta-data .username a") ||
    post.querySelector(".names .username a") ||
    post.querySelector(".names a");

  if (nameLink && data.nickname_style) {
    nameLink.classList.add("westan-vip-nickname");
    nameLink.setAttribute("style", `${nameLink.getAttribute("style") || ""};${styleForNickname(data.nickname_style)}`);
  }

  const names =
    post.querySelector(".topic-meta-data .names") ||
    post.querySelector(".topic-meta-data");
  if (names && data.custom_title) {
    let title = names.querySelector(".westan-vip-user-title");
    if (!title) {
      title = document.createElement("div");
      title.className = "westan-vip-user-title";
      names.appendChild(title);
    }
    title.textContent = data.custom_title;
  }

  if (data.badge_enabled && data.theme) {
    const postInfos = post.querySelector(".post-infos") || post.querySelector(".post-info");
    if (postInfos && !postInfos.querySelector(".westan-vip-post-badge")) {
      postInfos.insertAdjacentHTML("beforeend", badgeHtml(data.theme));
    }
  }
}

async function fetchUsers(ids, usernames) {
  let response;

  try {
    response = await ajax("/westan/vip-painel/post-users", {
      data: {
        ids: ids.join(","),
        usernames: usernames.join(","),
      },
    });
  } catch (error) {
    if (error?.jqXHR?.status === 429 || error?.status === 429) {
      backoffUntil = Date.now() + RATE_LIMIT_BACKOFF_MS;
    }
    return false;
  }

  ids.forEach((id) => cache.set(String(id), null));
  usernames.forEach((username) => usernameCache.set(String(username), null));

  Object.entries(response.users || {}).forEach(([id, data]) => {
    cache.set(String(id), data);
  });
  Object.entries(response.users_by_username || {}).forEach(([username, data]) => {
    usernameCache.set(String(username), data);
  });

  return true;
}

async function scanPosts() {
  scheduled = false;
  scanTimer = null;
  if (inFlight || Date.now() < backoffUntil) {
    return;
  }

  if (Date.now() - lastFetchAt < REQUEST_THROTTLE_MS) {
    scheduleScan(REQUEST_THROTTLE_MS);
    return;
  }

  const posts = Array.from(document.querySelectorAll(".topic-post, article[data-post-id], article[data-user-id]"));
  const missing = [];
  const missingUsernames = [];
  let hasMoreMissing = false;

  posts.forEach((post) => {
    const userId = findPostUserId(post);
    const username = findPostUsername(post);

    if (userId && cache.has(String(userId))) {
      const data = cache.get(String(userId));
      if (data) {
        decoratePost(post, data);
      }
    } else if (username && usernameCache.has(String(username))) {
      const data = usernameCache.get(String(username));
      if (data) {
        decoratePost(post, data);
      }
    } else if (userId && !pending.has(String(userId))) {
      if (missing.length < MAX_BATCH_SIZE) {
        pending.add(String(userId));
        missing.push(String(userId));
      } else {
        hasMoreMissing = true;
      }
    } else if (username && !pendingUsernames.has(String(username))) {
      if (missingUsernames.length < MAX_BATCH_SIZE) {
        pendingUsernames.add(String(username));
        missingUsernames.push(String(username));
      } else {
        hasMoreMissing = true;
      }
    }
  });

  if (missing.length > 0 || missingUsernames.length > 0) {
    inFlight = true;
    let fetched = false;
    try {
      fetched = await fetchUsers(missing, missingUsernames);
    } finally {
      inFlight = false;
      lastFetchAt = Date.now();
      pending = new Set([...pending].filter((id) => !missing.includes(id)));
      pendingUsernames = new Set([...pendingUsernames].filter((username) => !missingUsernames.includes(username)));
    }

    if (!fetched) {
      return;
    }

    posts.forEach((post) => {
      const userId = findPostUserId(post);
      const username = findPostUsername(post);
      const data = cache.get(String(userId)) || usernameCache.get(String(username));
      if (data) {
        decoratePost(post, data);
      }
    });
  }

  if (hasMoreMissing) {
    scheduleScan(REQUEST_THROTTLE_MS);
  }
}

function scheduleScan(delay = SCAN_DEBOUNCE_MS) {
  if (scheduled) {
    return;
  }
  scheduled = true;
  scanTimer = window.setTimeout(() => {
    scanPosts().catch(() => {
      scheduled = false;
      scanTimer = null;
    });
  }, delay);
}

export default apiInitializer("1.8.0", (api) => {
  const currentUser = api.getCurrentUser();
  if (currentUser?.staff) {
    api.addAdminSidebarSectionLink?.("plugins", {
      name: "westan-vip-painel",
      route: "westan-vip-painel-admin",
      label: "westan_vip_painel.admin_title",
      title: "Westan VIP Painel",
      text: "Westan VIP Painel",
      icon: "crown",
    });
  }

  if (currentUser?.westan_vip_painel_can_use) {
    api.addCommunitySectionLink?.({
      name: "westan-vip-painel",
      route: "westan-vip-painel",
      title: "Painel VIP",
      text: "Painel VIP",
      icon: "crown",
    });
  }

  if (scanTimer) {
    window.clearTimeout(scanTimer);
    scanTimer = null;
    scheduled = false;
  }

  observer?.disconnect();
  observer = new MutationObserver(scheduleScan);
  observer.observe(document.documentElement, {
    childList: true,
    subtree: true,
  });

  api.onPageChange?.(() => scheduleScan());
  scheduleScan();
});
