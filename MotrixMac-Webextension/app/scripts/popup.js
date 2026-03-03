import React, { useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { Global } from '@emotion/react';
import styled from '@emotion/styled';
import {
  IconButton,
  Switch,
  LinearProgress,
  ThemeProvider,
  createTheme,
} from '@mui/material';
import SettingsIcon from '@mui/icons-material/Settings';
import PowerSettingsNewIcon from '@mui/icons-material/PowerSettingsNew';
import BlockIcon from '@mui/icons-material/Block';
import { Snackbar, Alert } from '@mui/material';
import * as browser from 'webextension-polyfill';
import { globalStyles } from './utils/theme';

// --- I18n Helper ---
const i18n = (key) => browser.i18n.getMessage(key) || key;

// --- Styled Components ---

const PopupContainer = styled.div`
  width: 300px;
  min-height: 120px;
  padding: 16px;
  background-color: var(--bg);
  /* Ensure overall text alignment */
  text-align: left;
  display: flex;
  flex-direction: column;
`;

const Header = styled.div`
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 24px;
`;

const Title = styled.h1`
  font-size: 16px;
  font-weight: 700;
  margin: 0;
  background: linear-gradient(
    135deg,
    var(--text-primary),
    var(--text-secondary)
  );
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  letter-spacing: -0.5px;
`;

const StatusCard = styled.div`
  background: var(--card-bg);
  padding: 14px 18px;
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
  border: 1px solid var(--border-color);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  box-shadow: 0 4px 12px var(--shadow-color);
  transition: all 0.2s ease;
`;

const StatusText = styled.div`
  font-size: 15px;
  font-weight: 600;
  color: ${(props) =>
    props.active ? 'var(--success-color)' : 'var(--text-secondary)'};
  display: flex;
  align-items: center;
  gap: 12px;

  & svg {
    display: block;
    margin-bottom: 2px;
  }
`;

const ActionButton = styled.button`
  background: var(--input-bg);
  border: 1px solid var(--border-color);
  color: var(--text-primary);
  padding: 12px;
  border-radius: 12px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  transition: all 0.2s;
  margin-top: 8px;

  &:hover {
    background: var(--card-bg);
    border-color: var(--text-secondary);
  }

  &:active {
    transform: scale(0.98);
  }
`;

// --- Components ---

function PopupView() {
  const [extensionStatus, setExtensionStatus] = useState(false);
  const [feedback, setFeedback] = useState({ open: false, message: '' });

  useEffect(() => {
    // Initial Load
    browser.storage.sync.get(['extensionStatus', 'theme']).then((res) => {
      setExtensionStatus(res.extensionStatus !== false);
      applyTheme(res.theme || 'system');
    });
  }, []);

  const applyTheme = (mode) => {
    if (mode === 'system') {
      document.documentElement.removeAttribute('data-theme');
    } else {
      document.documentElement.setAttribute('data-theme', mode);
    }
  };

  const toggleExtension = () => {
    const newValue = !extensionStatus;
    setExtensionStatus(newValue);
    browser.storage.sync.set({ extensionStatus: newValue });

    // Also Toggle Shelf if needed (logic from background)
    if (!newValue) {
      browser.downloads.setShelfEnabled?.(true);
    }
  };

  const addToBlacklist = async () => {
    try {
      const tabs = await browser.tabs.query({
        active: true,
        currentWindow: true,
      });
      if (tabs.length === 0 || !tabs[0].url) return;

      const url = new URL(tabs[0].url);
      const hostname = url.hostname;

      if (!hostname) return;

      const res = await browser.storage.sync.get(['blacklist']);
      const currentList = res.blacklist || [];

      if (!currentList.includes(hostname)) {
        const newList = [...currentList, hostname];
        await browser.storage.sync.set({ blacklist: newList });
        setFeedback({
          open: true,
          message: browser.i18n.getMessage('blacklistAddedSuccess', [hostname]),
        });
      } else {
        setFeedback({
          open: true,
          message: browser.i18n.getMessage('blacklistAlreadyExists', [
            hostname,
          ]),
        });
      }
    } catch (e) {
      console.error(e);
      setFeedback({ open: true, message: i18n('blacklistAddFailed') });
    }
  };

  const handleCloseFeedback = () => setFeedback({ ...feedback, open: false });

  const openSettings = () => browser.runtime.openOptionsPage();

  return (
    <ThemeProvider theme={createTheme()}>
      <Global styles={globalStyles} />
      <PopupContainer>
        <Header>
          <Title>{i18n('appShortName')}</Title>
          <IconButton size="small" onClick={openSettings}>
            <SettingsIcon style={{ color: 'var(--text-secondary)' }} />
          </IconButton>
        </Header>

        <StatusCard>
          <StatusText active={extensionStatus}>
            <PowerSettingsNewIcon sx={{ fontSize: 20 }} />
            {extensionStatus ? i18n('statusActive') : i18n('statusInactive')}
          </StatusText>
          <Switch
            checked={extensionStatus}
            onChange={toggleExtension}
            size="small"
          />
        </StatusCard>

        <ActionButton onClick={addToBlacklist}>
          <BlockIcon style={{ fontSize: 18, color: 'var(--text-secondary)' }} />
          {i18n('addToBlacklist') || 'Add current site to Blacklist'}
        </ActionButton>

        <Snackbar
          open={feedback.open}
          autoHideDuration={2000}
          onClose={handleCloseFeedback}
          anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
        >
          <Alert
            onClose={handleCloseFeedback}
            severity="success"
            sx={{ width: '100%', fontSize: '12px' }}
          >
            {feedback.message}
          </Alert>
        </Snackbar>
      </PopupContainer>
    </ThemeProvider>
  );
}

ReactDOM.render(<PopupView />, document.getElementById('react-root'));
