// Keepa domainId per Amazon store, from Keepa's own client (AmazonLocale enum).
const DOMAIN_IDS = {
  "amazon.com": 1,
  "amazon.co.uk": 2,
  "amazon.de": 3,
  "amazon.fr": 4,
  "amazon.co.jp": 5,
  "amazon.ca": 6,
  "amazon.it": 8,
  "amazon.es": 9,
  "amazon.in": 10,
  "amazon.com.mx": 11,
  "amazon.com.br": 12,
};

const ASIN_URL_RE = /\/(?:dp|gp\/product)\/([A-Z0-9]{10})(?:[/?]|$)/;

function domainIdFor(hostname) {
  return DOMAIN_IDS[hostname.replace(/^www\./, "")];
}

function asinFromPage() {
  const el = document.querySelector("[data-asin]:not([data-asin=''])");
  if (el) return el.getAttribute("data-asin");
  const canonical = document.querySelector("link[rel='canonical']");
  const match = canonical && canonical.href.match(/\/(?:dp|gp\/product)\/([A-Z0-9]{10})/);
  return match ? match[1] : null;
}

async function findAsin(tab, url) {
  const fromUrl = url.pathname.match(ASIN_URL_RE);
  if (fromUrl) return fromUrl[1];

  const [{ result }] = await chrome.scripting.executeScript({
    target: { tabId: tab.id },
    func: asinFromPage,
  });
  return result;
}

function flashBadge(tabId, text) {
  chrome.action.setBadgeBackgroundColor({ tabId, color: "#c0392b" });
  chrome.action.setBadgeText({ tabId, text });
  setTimeout(() => chrome.action.setBadgeText({ tabId, text: "" }), 2000);
}

// Grey out (disable) the toolbar icon everywhere except on a supported
// Amazon store, so it's only clickable where it can actually do something.
// Chrome has no way to make a pinned icon fully disappear -- this is as
// close as declarativeContent gets. Built from DOMAIN_IDS so the set of
// stores stays in one place.
const AMAZON_URL_MATCH =
  "^https://([a-z0-9-]+\\.)*(" +
  Object.keys(DOMAIN_IDS)
    .map((host) => host.replace(/\./g, "\\."))
    .join("|") +
  ")(/|$)";

chrome.runtime.onInstalled.addListener(() => {
  chrome.action.disable();
  chrome.declarativeContent.onPageChanged.removeRules(undefined, () => {
    chrome.declarativeContent.onPageChanged.addRules([
      {
        conditions: [
          new chrome.declarativeContent.PageStateMatcher({
            pageUrl: { urlMatches: AMAZON_URL_MATCH },
          }),
        ],
        actions: [new chrome.declarativeContent.ShowAction()],
      },
    ]);
  });
});

chrome.action.onClicked.addListener(async (tab) => {
  if (!tab.url) return;
  const url = new URL(tab.url);

  const domainId = domainIdFor(url.hostname);
  if (!domainId) {
    flashBadge(tab.id, "?");
    return;
  }

  const asin = await findAsin(tab, url);
  if (!asin) {
    flashBadge(tab.id, "!");
    return;
  }

  chrome.tabs.create({ url: `https://keepa.com/#!product/${domainId}-${asin}` });
});
