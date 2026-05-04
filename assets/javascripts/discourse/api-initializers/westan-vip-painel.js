import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";

const cache = new Map();
const usernameCache = new Map();
let pending = new Set();
let pendingUsernames = new Set();
let scheduled = false;

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
  const response = await ajax("/westan/vip-painel/post-users", {
    data: {
      ids: ids.join(","),
      usernames: usernames.join(","),
    },
  });

  Object.entries(response.users || {}).forEach(([id, data]) => {
    cache.set(String(id), data);
  });
  Object.entries(response.users_by_username || {}).forEach(([username, data]) => {
    usernameCache.set(String(username), data);
  });
}

async function scanPosts() {
  scheduled = false;
  const posts = Array.from(document.querySelectorAll(".topic-post, article[data-post-id], article[data-user-id]"));
  const missing = [];
  const missingUsernames = [];

  posts.forEach((post) => {
    const userId = findPostUserId(post);
    const username = findPostUsername(post);

    if (userId && cache.has(String(userId))) {
      decoratePost(post, cache.get(String(userId)));
    } else if (username && usernameCache.has(String(username))) {
      decoratePost(post, usernameCache.get(String(username)));
    } else if (userId && !pending.has(String(userId))) {
      pending.add(String(userId));
      missing.push(String(userId));
    } else if (username && !pendingUsernames.has(String(username))) {
      pendingUsernames.add(String(username));
      missingUsernames.push(String(username));
    }
  });

  if (missing.length > 0 || missingUsernames.length > 0) {
    await fetchUsers(missing, missingUsernames);
    pending = new Set([...pending].filter((id) => !missing.includes(id)));
    pendingUsernames = new Set([...pendingUsernames].filter((username) => !missingUsernames.includes(username)));
    posts.forEach((post) => {
      const userId = findPostUserId(post);
      const username = findPostUsername(post);
      if (cache.has(String(userId))) {
        decoratePost(post, cache.get(String(userId)));
      } else if (usernameCache.has(String(username))) {
        decoratePost(post, usernameCache.get(String(username)));
      }
    });
  }
}

function scheduleScan() {
  if (scheduled) {
    return;
  }
  scheduled = true;
  window.requestAnimationFrame(scanPosts);
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

  scheduleScan();

  const observer = new MutationObserver(scheduleScan);
  observer.observe(document.documentElement, {
    childList: true,
    subtree: true,
  });
});
