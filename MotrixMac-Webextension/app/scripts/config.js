import React, { useState, useEffect } from 'react';
import ReactDOM from 'react-dom';
import { Global, css } from '@emotion/react';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import { Snackbar, Alert } from '@mui/material';
import * as browser from 'webextension-polyfill';
import {
  SettingsCard,
  SettingsRow,
  ToggleSwitch,
  InputGroup,
  Select,
  BlacklistEditor,
  PrimaryButton,
} from './components/SettingsComponents';
import { globalStyles } from './utils/theme';
import { LogLevel } from './utils/logger';
import styled from '@emotion/styled';

// --- I18n Helper ---
const i18n = (key) => browser.i18n.getMessage(key) || key;

// --- Styled Components ---

const Container = styled.div`
  max-width: 640px;
  margin: 0 auto;
`;

const Header = styled.h1`
  font-size: 28px;
  font-weight: 700;
  margin-bottom: 32px;
  text-align: center;
  background: linear-gradient(
    135deg,
    var(--text-primary),
    var(--text-secondary)
  );
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  opacity: 0.9;
`;

const Footer = styled.div`
  text-align: center;
  margin-top: 32px;
  padding-bottom: 48px;
  color: var(--text-secondary);
  font-size: 12px;
  opacity: 0.6;
`;

// --- Main App Component ---

const ConfigApp = () => {
  const [settings, setSettings] = useState({
    motrixAPIkey: '',
    motrixPort: 12800,
    defaultConnections: 128,
    extensionStatus: true,
    showContextOption: true,
    enableNotifications: true,
    minFileSize: '',
    hideChromeBar: true,
    blacklist: [],
    theme: 'system',
    logLevel: LogLevel.INFO,
  });

  const [feedback, setFeedback] = useState({ open: false, message: '' });

  // Load settings
  useEffect(() => {
    const load = async () => {
      const items = await browser.storage.sync.get([
        'motrixAPIkey',
        'motrixPort',
        'defaultConnections',
        'extensionStatus',
        'showContextOption',
        'enableNotifications',
        'minFileSize',
        'hideChromeBar',
        'blacklist',
        'theme',
        'logLevel',
      ]);

      if (items.logLevel === undefined) items.logLevel = LogLevel.INFO;
      // Ensure blacklist is an array
      if (!Array.isArray(items.blacklist)) items.blacklist = [];

      setSettings((prev) => ({ ...prev, ...items }));
      // Apply theme
      applyTheme(items.theme || 'system');
    };
    load();

    // Update document title
    document.title = i18n('settingsHeader');
  }, []);

  const applyTheme = (mode) => {
    if (mode === 'system') {
      document.documentElement.removeAttribute('data-theme');
    } else {
      document.documentElement.setAttribute('data-theme', mode);
    }
  };

  const updateSetting = (key, value) => {
    setSettings((prev) => ({ ...prev, [key]: value }));
    browser.storage.sync.set({ [key]: value });
    if (key === 'theme') {
      applyTheme(value);
    }

    if (key === 'showContextOption') {
      browser.contextMenus
        ?.update?.('motrix-webextension-download-context-menu-option', {
          visible: value,
        })
        .catch(() => {});
    }

    if (key === 'hideChromeBar') {
      browser.downloads?.setShelfEnabled?.(!value);
    }
  };

  const saveManual = (key, value) => {
    updateSetting(key, value);
    showFeedback(i18n('settingsSaved'));
  };

  const handleAddBlacklist = (newItem) => {
    const currentList = settings.blacklist || [];
    if (!currentList.includes(newItem)) {
      const newList = [...currentList, newItem];
      updateSetting('blacklist', newList);
    }
  };

  const handleRemoveBlacklist = (item) => {
    const currentList = settings.blacklist || [];
    const newList = currentList.filter((x) => x !== item);
    updateSetting('blacklist', newList);
  };

  const showFeedback = (msg) => {
    setFeedback({ open: true, message: msg });
  };

  const handleCloseFeedback = () => setFeedback({ ...feedback, open: false });

  return (
    <ThemeProvider theme={createTheme()}>
      <Global styles={globalStyles} />
      <Container>
        <Header>{i18n('settingsHeader')}</Header>

        <SettingsCard title={i18n('connectionTitle')}>
          <SettingsRow
            label={i18n('rpcKeyLabel')}
            description={i18n('rpcKeyDesc')}
          >
            <InputGroup
              value={settings.motrixAPIkey}
              onChange={(v) => setSettings({ ...settings, motrixAPIkey: v })}
              onSave={() => saveManual('motrixAPIkey', settings.motrixAPIkey)}
              placeholder={i18n('rpcKeyPlaceholder')}
              type="password"
              buttonLabel={i18n('save')}
            />
          </SettingsRow>
          <SettingsRow
            label={i18n('rpcPortLabel')}
            description={i18n('rpcPortDesc')}
          >
            <InputGroup
              value={settings.motrixPort}
              onChange={(v) =>
                setSettings({ ...settings, motrixPort: Number(v) })
              }
              onSave={() => saveManual('motrixPort', settings.motrixPort)}
              type="number"
              buttonLabel={i18n('save')}
            />
          </SettingsRow>
        </SettingsCard>

        <SettingsCard title={i18n('behaviorTitle')}>
          <SettingsRow
            label={i18n('enableExtensionLabel')}
            description={i18n('enableExtensionDesc')}
          >
            <ToggleSwitch
              checked={settings.extensionStatus}
              onChange={(v) => updateSetting('extensionStatus', v)}
            />
          </SettingsRow>
          <SettingsRow
            label={i18n('showContextLabel')}
            description={i18n('showContextDesc')}
          >
            <ToggleSwitch
              checked={settings.showContextOption}
              onChange={(v) => updateSetting('showContextOption', v)}
            />
          </SettingsRow>
          <SettingsRow
            label={i18n('showNotificationsLabel')}
            description={i18n('showNotificationsDesc')}
          >
            <ToggleSwitch
              checked={settings.enableNotifications}
              onChange={(v) => updateSetting('enableNotifications', v)}
            />
          </SettingsRow>
        </SettingsCard>

        <SettingsCard title={i18n('appearanceTitle')}>
          <SettingsRow
            label={i18n('darkModeLabel')}
            description={i18n('darkModeDesc')}
          >
            <Select
              value={settings.theme || 'system'}
              onChange={(e) => updateSetting('theme', e.target.value)}
            >
              <option value="system">{i18n('followSystem')}</option>
              <option value="light">{i18n('lightMode')}</option>
              <option value="dark">{i18n('darkMode')}</option>
            </Select>
          </SettingsRow>
        </SettingsCard>

        <SettingsCard title={i18n('advancedTitle')}>
          <SettingsRow
            label={i18n('logLevelLabel') || 'Log Level'}
            description={
              i18n('logLevelDesc') || 'Set the verbosity of extension logs'
            }
          >
            <Select
              value={settings.logLevel}
              onChange={(e) =>
                updateSetting('logLevel', Number(e.target.value))
              }
            >
              <option value={LogLevel.DEBUG}>Debug</option>
              <option value={LogLevel.INFO}>Info</option>
              <option value={LogLevel.WARN}>Warning</option>
              <option value={LogLevel.ERROR}>Error</option>
              <option value={LogLevel.OFF}>Off</option>
            </Select>
          </SettingsRow>
          <SettingsRow
            label={i18n('minFileSizeLabel')}
            description={i18n('minFileSizeDesc')}
          >
            <InputGroup
              value={settings.minFileSize}
              onChange={(v) => setSettings({ ...settings, minFileSize: v })}
              onSave={() => saveManual('minFileSize', settings.minFileSize)}
              type="number"
              placeholder="0"
              buttonLabel={i18n('save')}
            />
          </SettingsRow>
          <SettingsRow
            label={i18n('hideShelfLabel')}
            description={i18n('hideShelfDesc')}
          >
            <ToggleSwitch
              checked={settings.hideChromeBar}
              onChange={(v) => updateSetting('hideChromeBar', v)}
            />
          </SettingsRow>
        </SettingsCard>

        <SettingsCard title={i18n('blacklistTitle')}>
          <BlacklistEditor
            items={settings.blacklist || []}
            onAdd={handleAddBlacklist}
            onRemove={handleRemoveBlacklist}
            placeholder={i18n('blacklistPlaceholder')}
            cta={i18n('add') || 'Add'}
          />
        </SettingsCard>

        <Footer>MotrixMac Extension v1.0.2</Footer>

        <Snackbar
          open={feedback.open}
          autoHideDuration={2000}
          onClose={handleCloseFeedback}
          anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
        >
          <Alert
            onClose={handleCloseFeedback}
            severity="success"
            sx={{ width: '100%' }}
          >
            {feedback.message}
          </Alert>
        </Snackbar>
      </Container>
    </ThemeProvider>
  );
};

ReactDOM.render(<ConfigApp />, document.querySelector('#react-root'));
