const LogLevel = {
  DEBUG: 0,
  INFO: 1,
  WARN: 2,
  ERROR: 3,
  OFF: 4,
};

const LOG_LEVEL_KEY = 'logLevel';

class Logger {
  constructor() {
    this.level = LogLevel.INFO; // Default
    this.init();
  }

  async init() {
    try {
      if (typeof browser === 'undefined') return; // Safety
      const res = await browser.storage.sync.get([LOG_LEVEL_KEY]);
      if (res[LOG_LEVEL_KEY] !== undefined) {
        this.level = res[LOG_LEVEL_KEY];
      }

      // Listen for changes
      browser.storage.onChanged.addListener((changes, area) => {
        if (area === 'sync' && changes[LOG_LEVEL_KEY]) {
          this.level = changes[LOG_LEVEL_KEY].newValue;
          console.log(
            `[Logger] Level changed to ${this.getLevelName(this.level)}`
          );
        }
      });
    } catch (e) {
      console.warn('Failed to init logger level', e);
    }
  }

  getLevelName(lvl) {
    return (
      Object.keys(LogLevel).find((key) => LogLevel[key] === lvl) || 'UNKNOWN'
    );
  }

  debug(...args) {
    if (this.level <= LogLevel.DEBUG) console.debug('[DEBUG]', ...args);
  }

  info(...args) {
    if (this.level <= LogLevel.INFO) console.log('[INFO]', ...args);
  }

  warn(...args) {
    if (this.level <= LogLevel.WARN) console.warn('[WARN]', ...args);
  }

  error(...args) {
    if (this.level <= LogLevel.ERROR) console.error('[ERROR]', ...args);
  }
}

export const logger = new Logger();
export { LogLevel };
