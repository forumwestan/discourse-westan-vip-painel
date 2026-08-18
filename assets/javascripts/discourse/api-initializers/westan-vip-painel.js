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
let verifiedBadgeSequence = 0;

const SCAN_DEBOUNCE_MS = 450;
const REQUEST_THROTTLE_MS = 1_500;
const RATE_LIMIT_BACKOFF_MS = 60_000;
const MAX_BATCH_SIZE = 80;
const VERIFIED_BADGE_SELECTOR = ".westan-vip-verified";

function applyNicknameStyle(element, style) {
  if (!element || !style) {
    return;
  }

  element.style.backgroundImage = `linear-gradient(120deg, ${style.from}, ${style.to}, ${style.from})`;
  element.style.backgroundSize = "240% 240%";
  element.style.backgroundPosition = "0% 50%";
  element.style.webkitBackgroundClip = "text";
  element.style.backgroundClip = "text";
  element.style.color = "transparent";
}

function escapeHtml(value) {
  return String(value || "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function classToken(value) {
  return String(value || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function usernameKey(value) {
  return String(value || "").toLowerCase();
}

function badgeClasses(theme) {
  const classes = ["westan-vip-post-badge"];
  const id = classToken(theme.id);
  const name = classToken(theme.name);

  if (id) {
    classes.push(`westan-vip-theme-${id}`);
  }

  if (name) {
    classes.push(`westan-vip-theme-name-${name}`);
  }

  return classes.join(" ");
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

  return `<span class="${badgeClasses(theme)}" title="${safeName}">${background}${content}</span>`;
}

function verifiedBadgeHtml(key) {
  const token = `${classToken(key) || "member"}-${++verifiedBadgeSequence}`;
  const faceId = `westan-vip-gold-face-${token}`;
  const rimId = `westan-vip-gold-rim-${token}`;
  const sealPath =
    "M21.007 8.27C22.194 9.125 23 10.45 23 12s-.806 2.876-1.993 3.73c.24 1.442-.134 2.958-1.227 4.05c-1.095 1.095-2.61 1.459-4.046 1.225C14.883 22.196 13.546 23 12 23c-1.55 0-2.878-.807-3.731-1.996c-1.438.235-2.954-.128-4.05-1.224c-1.095-1.095-1.459-2.611-1.217-4.05C1.816 14.877 1 13.551 1 12s.816-2.878 2.002-3.73c-.242-1.439.122-2.955 1.218-4.05c1.093-1.094 2.61-1.467 4.057-1.227C9.125 1.804 10.453 1 12 1c1.545 0 2.88.803 3.732 1.993c1.442-.24 2.956.135 4.048 1.227s1.468 2.608 1.227 4.05m-4.426-.084a1 1 0 0 1 .233 1.395l-5 7a1 1 0 0 1-1.521.126l-3-3a1 1 0 0 1 1.414-1.414l2.165 2.165l4.314-6.04a1 1 0 0 1 1.395-.232";

  return `<button type="button" class="westan-vip-verified" aria-label="Membro Verificado" aria-expanded="false" data-tooltip="Membro Verificado"><svg viewBox="0 0 24 24" aria-hidden="true"><defs><linearGradient id="${faceId}" x1="4" y1="3" x2="21" y2="22" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#fff1a0"></stop><stop offset=".28" stop-color="#f8d84d"></stop><stop offset=".62" stop-color="#edb80d"></stop><stop offset="1" stop-color="#cf8500"></stop></linearGradient><linearGradient id="${rimId}" x1="5" y1="4" x2="20" y2="21" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#fff8c9"></stop><stop offset=".42" stop-color="#f8d956"></stop><stop offset="1" stop-color="#ad6500"></stop></linearGradient></defs><path class="westan-vip-verified__depth" transform="translate(0 .75)" fill-rule="evenodd" d="${sealPath}" clip-rule="evenodd"></path><path class="westan-vip-verified__seal" fill="url(#${faceId})" fill-rule="evenodd" d="${sealPath}" clip-rule="evenodd"></path><path class="westan-vip-verified__rim" fill="none" stroke="url(#${rimId})" fill-rule="evenodd" d="${sealPath}" clip-rule="evenodd"></path><path class="westan-vip-verified__check-shadow" transform="translate(.55 .7)" d="m7.8 13 3 3 5.5-7.7"></path><path class="westan-vip-verified__check" d="m7.8 13 3 3 5.5-7.7"></path></svg></button>`;
}

function activateVerifiedBadge(badge) {
  if (!badge || badge.dataset.tooltipReady === "true") {
    return;
  }

  badge.dataset.tooltipReady = "true";
  badge.dataset.tooltip = "Membro Verificado";
  badge.setAttribute("aria-label", "Membro Verificado");
  badge.setAttribute("aria-expanded", "false");
  if (badge.tagName !== "BUTTON") {
    badge.setAttribute("role", "button");
    badge.setAttribute("tabindex", "0");
  }

  badge.addEventListener("click", (event) => {
    event.preventDefault();
    event.stopPropagation();

    const willOpen = !badge.classList.contains("is-tooltip-visible");
    document
      .querySelectorAll(`${VERIFIED_BADGE_SELECTOR}.is-tooltip-visible`)
      .forEach((item) => {
        item.classList.remove("is-tooltip-visible");
        item.setAttribute("aria-expanded", "false");
      });

    badge.classList.toggle("is-tooltip-visible", willOpen);
    badge.setAttribute("aria-expanded", String(willOpen));
  });

  badge.addEventListener("blur", () => {
    badge.classList.remove("is-tooltip-visible");
    badge.setAttribute("aria-expanded", "false");
  });
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

  const nameContainer = nameLink?.closest(".username") || nameLink?.parentElement;
  nameContainer?.classList.add("westan-vip-verified-name");

  if (
    data.verified &&
    nameLink &&
    !nameContainer?.querySelector(VERIFIED_BADGE_SELECTOR)
  ) {
    nameLink.insertAdjacentHTML(
      "afterend",
      verifiedBadgeHtml(data.username || data.id)
    );
    activateVerifiedBadge(nameLink.nextElementSibling);
  }

  if (nameLink && data.nickname_style) {
    nameLink.classList.add("westan-vip-nickname");
    applyNicknameStyle(nameLink, data.nickname_style);
  }

  const names =
    post.querySelector(".topic-meta-data .names") ||
    post.querySelector(".topic-meta-data");
  if (data.verified) {
    names?.classList.add("westan-vip-has-verified");
  }
  if (names && data.custom_title) {
    names.classList.add("westan-vip-names");
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

function profileUsername() {
  const match = window.location.pathname.match(/^\/u\/([^/]+)/i);
  if (!match) {
    return null;
  }

  try {
    return decodeURIComponent(match[1]);
  } catch {
    return match[1];
  }
}

function normalizedText(value) {
  return String(value || "").replace(/\s+/g, " ").trim().toLowerCase();
}

function findProfileNameElement(data) {
  const expectedNames = new Set(
    [data.name, data.username].map(normalizedText).filter(Boolean)
  );
  const selectors = [
    ".user-main .user-profile-names .full-name",
    ".user-main .user-profile-names .username",
    ".user-main .about .details .primary .full-name",
    ".user-main .about .details .primary .username",
    ".user-profile .user-profile-names .full-name",
    ".user-profile .user-profile-names .username",
    "main .profile-name",
    "main .profile_name",
  ];

  for (const selector of selectors) {
    const element = document.querySelector(selector);
    if (element && expectedNames.has(normalizedText(element.textContent))) {
      return element;
    }
  }

  const candidates = document.querySelectorAll(
    "main h1, main h2, main strong, main span, main div"
  );

  return Array.from(candidates).find((element) => {
    if (element.matches("a, button") || element.closest(".user-card")) {
      return false;
    }

    return (
      element.childElementCount <= 1 &&
      expectedNames.has(normalizedText(element.textContent))
    );
  });
}

function decorateProfile(data) {
  const nameElement = findProfileNameElement(data);
  if (!nameElement || nameElement.querySelector(".westan-vip-verified")) {
    return;
  }

  nameElement.classList.add("westan-vip-profile-name");
  nameElement.insertAdjacentHTML(
    "beforeend",
    verifiedBadgeHtml(`profile-${data.username || data.id}`)
  );
  activateVerifiedBadge(nameElement.querySelector(".westan-vip-verified"));
}

function findUserCardUsername(card) {
  const userLink =
    card.querySelector(".username a[href^='/u/']") ||
    card.querySelector(".names a[href^='/u/']") ||
    card.querySelector("a[href^='/u/']");
  const usernameFromData = userLink?.dataset?.userCard;
  if (usernameFromData) {
    return usernameFromData;
  }

  const match = userLink?.getAttribute("href")?.match(/^\/u\/([^/?#]+)/i);
  if (!match) {
    return null;
  }

  try {
    return decodeURIComponent(match[1]);
  } catch {
    return match[1];
  }
}

function decorateUserCard(card, data) {
  const expectedNames = new Set(
    [data.name, data.username].map(normalizedText).filter(Boolean)
  );
  const links = Array.from(
    card.querySelectorAll(".username a[href^='/u/'], .names a[href^='/u/']")
  );
  const nameLink =
    links.find((link) => expectedNames.has(normalizedText(link.textContent))) ||
    links[0];
  const nameContainer = nameLink?.parentElement;

  if (!nameLink || nameContainer?.querySelector(".westan-vip-verified")) {
    return;
  }

  nameLink.insertAdjacentHTML(
    "afterend",
    verifiedBadgeHtml(`card-${data.username || data.id}`)
  );
  nameContainer.classList.add("westan-vip-verified-card-name");
  const verifiedBadge = nameLink.nextElementSibling;
  verifiedBadge?.classList.add("westan-vip-verified--user-card");

  activateVerifiedBadge(verifiedBadge);
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
  usernames.forEach((username) => usernameCache.set(usernameKey(username), null));

  Object.entries(response.users || {}).forEach(([id, data]) => {
    cache.set(String(id), data);
  });
  Object.entries(response.users_by_username || {}).forEach(([username, data]) => {
    usernameCache.set(usernameKey(username), data);
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

  activateNativeVerifiedBadges();

  const posts = Array.from(document.querySelectorAll(".topic-post, article[data-post-id], article[data-user-id]"));
  const userCards = Array.from(document.querySelectorAll(".user-card"));
  const currentProfileUsername = profileUsername();
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
    } else if (username && usernameCache.has(usernameKey(username))) {
      const data = usernameCache.get(usernameKey(username));
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
    } else if (username && !pendingUsernames.has(usernameKey(username))) {
      if (missingUsernames.length < MAX_BATCH_SIZE) {
        pendingUsernames.add(usernameKey(username));
        missingUsernames.push(String(username));
      } else {
        hasMoreMissing = true;
      }
    }
  });

  userCards.forEach((card) => {
    const username = findUserCardUsername(card);
    const key = usernameKey(username);

    if (username && usernameCache.has(key)) {
      const data = usernameCache.get(key);
      if (data) {
        decorateUserCard(card, data);
      }
    } else if (username && !pendingUsernames.has(key)) {
      if (missingUsernames.length < MAX_BATCH_SIZE) {
        pendingUsernames.add(key);
        missingUsernames.push(username);
      } else {
        hasMoreMissing = true;
      }
    }
  });

  if (currentProfileUsername) {
    const key = usernameKey(currentProfileUsername);
    if (usernameCache.has(key)) {
      const data = usernameCache.get(key);
      if (data) {
        decorateProfile(data);
      }
    } else if (!pendingUsernames.has(key)) {
      if (missingUsernames.length < MAX_BATCH_SIZE) {
        pendingUsernames.add(key);
        missingUsernames.push(currentProfileUsername);
      } else {
        hasMoreMissing = true;
      }
    }
  }

  if (missing.length > 0 || missingUsernames.length > 0) {
    inFlight = true;
    let fetched = false;
    try {
      fetched = await fetchUsers(missing, missingUsernames);
    } finally {
      inFlight = false;
      lastFetchAt = Date.now();
      pending = new Set([...pending].filter((id) => !missing.includes(id)));
      const fetchedUsernameKeys = new Set(missingUsernames.map(usernameKey));
      pendingUsernames = new Set(
        [...pendingUsernames].filter(
          (username) => !fetchedUsernameKeys.has(usernameKey(username))
        )
      );
    }

    if (!fetched) {
      return;
    }

    posts.forEach((post) => {
      const userId = findPostUserId(post);
      const username = findPostUsername(post);
      const data =
        cache.get(String(userId)) || usernameCache.get(usernameKey(username));
      if (data) {
        decoratePost(post, data);
      }
    });

    userCards.forEach((card) => {
      const username = findUserCardUsername(card);
      const data = usernameCache.get(usernameKey(username));
      if (data) {
        decorateUserCard(card, data);
      }
    });

    if (currentProfileUsername) {
      const data = usernameCache.get(usernameKey(currentProfileUsername));
      if (data) {
        decorateProfile(data);
      }
    }
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
  api.addTrackedPostProperties("westan_vip_painel");

  api.decorateCookedElement(
    (cookedElement, helper) => {
      const data = helper.model?.westan_vip_painel;
      const post = cookedElement.closest(
        ".topic-post, article[data-post-id], article[data-user-id]"
      );
      if (data && post) {
        decoratePost(post, data);
      }
    },
    { onlyStream: true }
  );

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
