import Aria2 from 'aria2';
import { historyToArray, parsePath, isFirefox } from './utils';
import * as browser from 'webextension-polyfill';

function validateUrl(value) {
  return /^(?:(?:(?:https?|ftp):)?\/\/)(?:\S+(?::\S*)?@)?(?:(?!(?:10|127)(?:\.\d{1,3}){3})(?!(?:169\.254|192\.168)(?:\.\d{1,3}){2})(?!172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2})(?:[1-9]\d?|1\d\d|2[01]\d|22[0-3])(?:\.(?:1?\d{1,2}|2[0-4]\d|25[0-5])){2}(?:\.(?:[1-9]\d?|1\d\d|2[0-4]\d|25[0-4]))|(?:(?:[a-z0-9\u00a1-\uffff][a-z0-9\u00a1-\uffff_-]{0,62})?[a-z0-9\u00a1-\uffff]\.)+(?:[a-z\u00a1-\uffff]{2,}\.?))(?::\d{2,5})?(?:[/?#]\S*)?$/i.test(
    value
  );
}

const pass = () => null;
const handleError = (error) => console.log(`Error: ${error}`);

async function removeFromHistory(id) {
  await browser.downloads.removeFile(id).then(pass).catch(pass);
  await browser.downloads.cancel(id).then(pass).catch(handleError);
  await browser.downloads.erase({ id }).then(pass).catch(handleError);
}

export default class AriaDownloader {
  constructor() {
    this.name = 'AriaDownloader';
  }

  async handleStart(options, downloadItem, history) {
    // remove file from browsers history
    await browser.downloads.pause(downloadItem.id);
    const gid = await this.addDownloadToMotrix(options, downloadItem);
    if (gid) {
      await removeFromHistory(downloadItem.id);
      this.startMonitoring(gid, downloadItem, history, options);
    }
  }

  async resume(options, downloadId, history) {
    // Attempt to match downloadId to a history item
    // In background.js, activeDownloads stores the original browser DownloadItem.id or similar.
    // History is keyed by GID. 
    // We need to find the history entry that corresponds to this download.
    // Since we don't have a direct map of BrowserID -> GID in 'activeDownloads' (it's just a set of IDs),
    // we rely on the fact that for 'resume' to work, the download must be in the history map.
    // BUT we might be passed a GID directly if background.js tracks GIDs. 
    // If background.js tracks browser IDs, we have a problem because we don't know the GID.

    // However, if we look at existing history items, they have 'gid'. 
    // We can just iterate all history items that are 'downloading' and resume them?
    // The explicit 'resume' method here takes a 'downloadId'. 

    // If downloadId is a GID (string), we use it.
    // If it's a number (browser ID), we probably can't find it easily unless we stored it.

    // Strategy: assume downloadId Passed is the GID if it's a string, or iterate history.
    // Actually, background.js 'activeDownloads' contains IDs. 
    // I will modify background.js to tracking GIDs for Aria2 downloads.

    const item = history.get(downloadId); // Try direct GID lookup
    if (item && (item.status === 'downloading' || item.status === 'active')) {
      this.startMonitoring(downloadId, null, history, options);
      return;
    }

    // Fallback: search values?
    const found = [...history.values()].find(x => x.id === downloadId);
    if (found && (found.status === 'downloading' || found.status === 'active')) {
      this.startMonitoring(found.gid, null, history, options);
    }
  }

  async addDownloadToMotrix(result, downloadItem) {
    const options = {
      host: '127.0.0.1',
      port: result.motrixPort,
      secure: false,
      secret: result.motrixAPIkey,
      path: '/jsonrpc',
    };
    console.log(`Motrix WebExtension: Connecting to RPC at 127.0.0.1:${result.motrixPort}`);
    const aria2 = new Aria2(options);
    try {
      await aria2.open();
    } catch (e) {
      console.error('Motrix WebExtension: RPC connection failed:', e);
      // Show notification on failure
      this.showErrorNotification();
      throw e;
    }

    let downloadUrl = '';
    if (validateUrl(downloadItem.finalUrl)) {
      downloadUrl = downloadItem.finalUrl;
    } else if (validateUrl(downloadItem.url)) {
      downloadUrl = downloadItem.url;
    } else {
      return null;
    }

    let params = {
      'remote-time': 'true',
      'check-certificate': 'false'
    };

    if (downloadItem.filename) {
      const pathInfo = parsePath(downloadItem.filename);
      if (pathInfo.out) params.out = pathInfo.out;
      if (pathInfo.dir) params.dir = pathInfo.dir;
    }

    const headers = [];
    if (downloadItem.cookies) {
      headers.push(`Cookie: ${downloadItem.cookies}`);
    }
    headers.push(`User-Agent: ${navigator.userAgent}`);
    if (headers.length > 0) {
      params.header = headers;
    }
    if (downloadItem.referrer) {
      params.referer = downloadItem.referrer;
    }

    try {
      const gid = await aria2.call('addUri', [downloadUrl], params);
      if (result.enableNotifications) {
        this.showSuccessNotification();
      }
      return gid;
    } catch (err) {
      console.error(`Error adding execution: ${err}`);
      this.showErrorNotification();
      throw err;
    }
  }

  startMonitoring(gid, downloadItem, history, options) {
    // Re-construct needed data if downloadItem is missing (resumption case)
    const historyItem = history.get(gid);

    const startTime = downloadItem?.startTime || historyItem?.startTime || Date.now();
    const icon = downloadItem?.icon || historyItem?.icon;
    const totalBytes = downloadItem?.totalBytes || historyItem?.size || 0;
    const out = historyItem?.name;
    const dir = historyItem?.path;

    const aria2 = new Aria2({
      host: '127.0.0.1',
      port: options.motrixPort,
      secure: false,
      secret: options.motrixAPIkey,
      path: '/jsonrpc',
    });

    this.updateIcon('downloading');

    // Initial history entry
    history.set(gid, {
      gid: gid,
      downloader: 'aria',
      startTime: startTime,
      icon: icon,
      name: out,
      path: dir,
      status: 'downloading',
      size: totalBytes,
      downloaded: historyItem?.downloaded || 0,
    });
    browser.storage.local.set({ history: historyToArray(history) });

    let inter = setInterval(async () => {
      let status = null;
      try {
        status = await aria2.call('tellStatus', gid);
      } catch (e) {
        // If we can't tell status, it might be stopped or complete and removed from Aria2 memory?
        // Or connection failed.
        // We'll keep trying for a bit or assume stopped?
        // For now, simple error handling.
        return;
      }

      const mapStatus = (s) => {
        if (s === 'active') return 'downloading';
        if (s === 'complete') return 'completed';
        if (s === 'error') return 'error';
        if (s === 'removed') return 'deleted';
        return 'paused';
      };

      const finalStatus = mapStatus(status.status);

      history.set(gid, {
        gid: gid,
        downloader: 'aria',
        startTime: startTime,
        icon: icon,
        name: out || status.files?.[0]?.path, // Try to capture path if we missed it
        path: dir,
        status: finalStatus,
        size: parseInt(status.totalLength) || totalBytes,
        downloaded: parseInt(status.completedLength),
      });
      browser.storage.local.set({ history: historyToArray(history) });

      if (finalStatus === 'completed' || finalStatus === 'error' || finalStatus === 'deleted') {
        clearInterval(inter);
        if (finalStatus === 'completed') {
          this.handleCompletion(history);
        }
      }
    }, 1000);
  }

  updateIcon(type) {
    const path = type === 'downloading' ? '../images/dwld.png' : '../images/32.png';
    if (isFirefox) {
      browser.browserAction.setIcon({ path });
    } else {
      browser.action.setIcon({ path });
    }
  }

  handleCompletion(history) {
    setTimeout(() => {
      const downloadingCount = [...history.values()].filter((x) => x.status === 'downloading').length;
      if (downloadingCount === 0) {
        this.updateIcon('default');
      }
    }, 1000);
  }

  showSuccessNotification() {
    const notificationOptions = {
      type: 'basic',
      iconUrl: '../images/icon-large.png',
      title: 'MotrixMac - 开始下载',
      message: '下载任务已发送至 MotrixMac 下载管理器',
    };
    const notificationId = Math.round(new Date().getTime() / 1000).toString();
    browser.notifications.create(notificationId, notificationOptions);
    browser.notifications.onClicked.addListener((id) => {
      if (id === notificationId) {
        browser.tabs.create({ url: 'motrixmac://show' });
      }
    });
  }

  showErrorNotification() {
    const notificationOptions = {
      type: 'basic',
      iconUrl: '../images/icon-large.png',
      title: '无法连接到 MotrixMac',
      message: '请打开 MotrixMac 并确保在 偏好设置 > 进阶设置 > RPC 授权密钥 中设置了 API Key。点击此处打开 MotrixMac。',
    };
    const notificationId = Math.round(new Date().getTime() / 1000).toString();
    browser.notifications.create(notificationId, notificationOptions);
    browser.notifications.onClicked.addListener((id) => {
      if (id === notificationId) {
        browser.tabs.create({ url: 'motrixmac://open' });
      }
    });
  }
}
