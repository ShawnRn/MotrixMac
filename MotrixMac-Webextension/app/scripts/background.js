import { filter, lastValueFrom, Observable, take } from 'rxjs';
import AriaDownloader from './AriaDownloader';
import BrowserDownloader from './BrowserDownloader';
import { historyToArray } from './utils';
import * as browser from 'webextension-polyfill';

// Track active downloads (Browser IDs only) to keep service worker alive for browser downloads
// Use storage to persist active downloads across service worker suspensions
let activeDownloads = new Set();

// Ensure listeners are set up immediately when the Service Worker starts/wakes up
loadExtension();

async function downloadAgent() {
  const subscribers = [];
  const observable = new Observable((s) => subscribers.push(s));
  const history = new Map();

  console.log('Motrix WebExtension: Service worker started');

  // Load active downloads from storage (Browser IDs)
  try {
    const { activeDownloadsList = [] } = await browser.storage.local.get(['activeDownloadsList']);
    activeDownloads = new Set(activeDownloadsList);
    console.log(`Loaded ${activeDownloads.size} active browser downloads from storage`);
  } catch (e) {
    console.error('Error loading active downloads:', e);
  }

  // Setup history
  try {
    const { history: oldHistory = [] } = await browser.storage.local.get(['history']);
    oldHistory.forEach((x) => {
      if (x.status !== 'completed' && x.status !== 'error' && x.status !== 'deleted') {
        // If it was 'downloading', treat it as potentially active
      }
      history.set(x.gid, x);
    });
    // Ensure we sync back normalized history
    browser.storage.local.set({ history: historyToArray(history) });

    // RESUMPTION LOGIC:
    // Resume monitoring for any Aria2 tasks that are 'downloading'
    const config = await browser.storage.sync.get(['motrixAPIkey', 'motrixPort']);

    // Default config if missing
    if (!config.motrixPort) config.motrixPort = 16800;

    console.log('Checking for downloads to resume...');
    let resumeCount = 0;
    for (const [gid, item] of history) {
      if (item.status === 'downloading' && item.downloader === 'aria') {
        console.log(`Resuming monitoring for task ${gid}`);
        const downloader = new AriaDownloader();
        downloader.resume(config, gid, history);
        resumeCount++;
      }
    }
    console.log(`Resumed ${resumeCount} Aria2 tasks`);

  } catch (e) {
    console.error('Error setting up history/resumption:', e);
  }


  // Helper function to save active downloads to storage
  const saveActiveDownloads = async () => {
    await browser.storage.local.set({
      activeDownloadsList: Array.from(activeDownloads)
    });
  };

  // Helper function to add download to active list
  const addActiveDownload = async (downloadId) => {
    activeDownloads.add(downloadId);
    await saveActiveDownloads();
  };

  // Helper function to remove download from active list
  const removeActiveDownload = async (downloadId) => {
    activeDownloads.delete(downloadId);
    await saveActiveDownloads();
  };

  // Hide bottom bar (Legacy/Browser download support)
  browser.storage.sync.get(['hideChromeBar', 'extensionStatus']).then(({ hideChromeBar, extensionStatus }) => {
    if (extensionStatus) browser.downloads.setShelfEnabled?.(!hideChromeBar);
  });

  browser.downloads.onChanged.addListener((delta) => {
    subscribers.forEach((s) => s.next(delta));
    // Track download state changes
    if (delta.state) {
      if (delta.state.current === 'in_progress') {
        addActiveDownload(delta.id);
        processDownload(delta.id);
      } else if (delta.state.current === 'complete' || delta.state.current === 'interrupted') {
        removeActiveDownload(delta.id);
      }
    }
  });

  // Clean up when downloads are removed
  browser.downloads.onErased.addListener((downloadId) => {
    removeActiveDownload(downloadId);
  });

  // Track downloads that need processing
  const pendingDownloads = new Map();

  browser.downloads.onCreated.addListener(async function (downloadItem) {
    console.log(`New download detected: ${downloadItem.id} - ${downloadItem.url}`);

    // Store download info for processing
    pendingDownloads.set(downloadItem.id, downloadItem);

    // If download is already in progress, process it immediately
    if (downloadItem.state === 'in_progress') {
      processDownload(downloadItem.id);
    }
  });

  async function processDownload(downloadId) {
    const downloadItem = pendingDownloads.get(downloadId);
    if (!downloadItem) {
      return;
    }

    // Remove from pending to avoid double processing
    pendingDownloads.delete(downloadId);
    addActiveDownload(downloadId);

    // For cookies
    try {
      const cookies = await browser.cookies.getAll({ url: downloadItem.url });
      downloadItem.cookies = cookies
        .map((cookie) => `${cookie.name}=${cookie.value}`)
        .join('; ');
    } catch (e) {
      console.warn('Could not fetch cookies:', e);
    }

    async function onError(error) {
      console.log(`Error: ${error}`);
      removeActiveDownload(downloadId);
    }

    // Triggered whenever a new download event fires
    let getResult = browser.storage.sync.get([
      'motrixAPIkey',
      'extensionStatus',
      'enableNotifications',
      'minFileSize',
      'blacklist',
      'motrixPort',
      'downloadFallback',
    ]);

    const getAriaDownloader = async (options) => {
      const result = options;
      // this will find item with by extension name set
      const statuses = await browser.downloads.search({
        id: downloadId,
      });

      const shouldCheck =
        statuses[0]?.byExtensionName !== browser.i18n.getMessage('appName');

      // Extension is disabled
      if (shouldCheck && !result.extensionStatus) return;
      // File size is known and it is smaller than the minimum file size (in mb)
      if (
        shouldCheck &&
        downloadItem.fileSize > 0 &&
        downloadItem.fileSize < result.minFileSize * 1024 * 1024
      )
        return;
      // If url is on the blacklist then skip
      if (
        shouldCheck &&
        result.blacklist
          .map((x) => downloadItem.url.includes(x))
          .reduce((prev, curr) => prev || curr, false)
      ) {
        return;
      }

      return new AriaDownloader();
    };

    const getDownloader = async (options) => {
      return (await getAriaDownloader(options)) ?? new BrowserDownloader();
    };

    getResult.then(async (result) => {
      // Default port if not set
      if (!result.motrixPort) {
        result.motrixPort = 16800;
        // await browser.storage.sync.set({ motrixPort: 16800 }); // Optional: could save back
      }

      let downloader = await getDownloader(result);

      if (!downloader) {
        removeActiveDownload(downloadId);
        return;
      }

      console.log(`Using downloader: ${downloader.name}`);

      // wait for filename to be set
      if (!downloadItem.filename) {
        // Wait for filename...
        // Note: Using 'take(1)' to avoid leaking subscribers?
        // But 'observable' is cold/hot? It's a Subject-like logic above.
        // We create a new observable that pushes to 'subscribers'.
        // This logic is a bit fragile but keeping it for compatibility.
        // Adding a timeout constraint would be wise but let's trust existing logic for now.
        const obs = observable.pipe(
          filter((d) => d.id === downloadId && d.filename),
          take(1)
        );
        const delta = await lastValueFrom(obs);
        downloadItem.filename = delta.filename.current;
      }

      // get icon of the file
      try {
        downloadItem.icon = await browser.downloads.getFileIcon(downloadId);
      } catch (e) { }

      try {
        console.log('Starting download with Motrix...');
        await downloader.handleStart(result, downloadItem, history);
        // Note: AriaDownloader.handleStart will remove the file from browser history
        // which triggers onErased -> removeActiveDownload.
        // This is expected. We stop tracking it as a "Browser Download".
        // Instead, the 'history' logic and 'resume' logic handles it as an "Aria Download".
      } catch (error) {
        console.error('Error sending to Motrix:', error);
        // Fallback or cleanup
        if (downloader instanceof AriaDownloader) {
          if (
            typeof result.downloadFallback === 'undefined' ||
            result?.downloadFallback
          ) {
            console.log('Falling back to browser download');
            await browser.downloads.resume(downloadId);
            downloader = new BrowserDownloader();
            await downloader.handleStart(result, downloadItem, history);
          } else {
            // Cancel logic... 
            await browser?.downloads?.erase({ id: downloadId }).catch(() => { });
            onError(error);
          }
        }
      }
    }, onError);
  }
}

export function createMenuItem() {
  browser.storage.sync
    .get('showContextOption')
    .then(({ showContextOption }) => {
      const menuId = 'motrix-webextension-download-context-menu-option';
      const clickHandler = async (data) => {
        browser.downloads.download({ url: data.linkUrl });
      };

      browser.contextMenus.removeAll().then(() => {
        if (browser.contextMenus.onClicked.hasListener(clickHandler)) {
          browser.contextMenus.onClicked.removeListener(clickHandler);
        }

        if (showContextOption !== false) {
          browser.contextMenus.create({
            id: menuId,
            title: browser.i18n.getMessage('downloadWithMotrix'),
            visible: true,
            contexts: ['link'],
          }, () => {
            if (browser.runtime.lastError) {
              console.log('Motrix WebExtension: Context menu creation warning:', browser.runtime.lastError.message);
            }
          });
          browser.contextMenus.onClicked.addListener(clickHandler);
        }
      });
    });
}

function loadExtension() {
  downloadAgent();
  createMenuItem();
}

// Log service worker lifecycle events
browser.runtime.onSuspend.addListener(() => {
  console.log('Motrix WebExtension: Service worker being suspended');
});

// Configure alarm to keep service worker alive
browser.alarms.create('keepAlive', { periodInMinutes: 0.5 });
browser.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === 'keepAlive') {
    console.log('Motrix WebExtension: Keep-alive alarm triggered');
    // Calling loadExtension() here is redundant because the SW wakeup already runs top-level code.
    // But we could force a resume check if strict 'event driven' logic failed.
    // For now, reliance on top-level execution is cleaner.
  }
});
