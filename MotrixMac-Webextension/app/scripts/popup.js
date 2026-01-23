import React, { useEffect, useState } from 'react';
import ReactDOM from 'react-dom';
import { Global } from '@emotion/react';
import styled from '@emotion/styled';
import { IconButton, Switch, LinearProgress, ThemeProvider, createTheme } from '@mui/material';
import SettingsIcon from '@mui/icons-material/Settings';
import FolderIcon from '@mui/icons-material/Folder';
import HistoryIcon from '@mui/icons-material/History';
import ClearAllIcon from '@mui/icons-material/ClearAll';
import PowerSettingsNewIcon from '@mui/icons-material/PowerSettingsNew';
import OpenInNewIcon from '@mui/icons-material/OpenInNew';
import * as browser from 'webextension-polyfill';
import { globalStyles } from './utils/theme';

// --- I18n Helper ---
const i18n = (key) => browser.i18n.getMessage(key) || key;

// --- Styled Components ---

const PopupContainer = styled.div`
  width: 360px;
  min-height: 400px;
  padding: 20px;
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
  font-size: 18px;
  font-weight: 700;
  margin: 0;
  background: linear-gradient(135deg, var(--text-primary), var(--text-secondary));
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  letter-spacing: -0.5px;
`;

const StatusCard = styled.div`
  background: var(--card-bg);
  padding: 16px 20px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 24px;
  border: 1px solid var(--border-color);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  box-shadow: 0 4px 16px var(--shadow-color);
  transition: all 0.2s ease;
`;

const StatusText = styled.div`
  font-size: 15px;
  font-weight: 600;
  color: ${props => props.active ? 'var(--success-color)' : 'var(--text-secondary)'};
  display: flex;
  align-items: center;
  gap: 12px;
  
  & svg {
      display: block;
      margin-bottom: 2px;
  }
`;

const ActionGrid = styled.div`
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 12px;
  margin-bottom: 28px;
  padding: 0 4px;
`;

const ActionButtonWrapper = styled.div`
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  flex: 1;
`;

const ActionLabel = styled.span`
  font-size: 12px;
  color: var(--text-secondary);
  font-weight: 500;
  text-align: center;
  white-space: nowrap;
`;

const StyledIconButton = styled(IconButton)`
  background: var(--card-bg);
  border: 1px solid var(--border-color);
  color: var(--text-primary);
  width: 56px;
  height: 56px;
  border-radius: 18px;
  transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  backdrop-filter: blur(10px);
  box-shadow: 0 2px 8px var(--shadow-color);

  /* Icon Size Consistency */
  & svg {
      font-size: 24px;
      stroke-width: 1.5px;
  }

  &:hover {
    background: var(--border-color-light);
    transform: translateY(-2px);
    box-shadow: 0 6px 16px var(--shadow-color-hover);
  }
  
  &:active {
    transform: translateY(0);
    box-shadow: 0 2px 4px var(--shadow-color);
  }
`;

const SectionTitle = styled.h3`
  font-size: 12px;
  font-weight: 700;
  color: var(--text-secondary);
  text-transform: uppercase;
  margin: 0 0 12px 4px;
  letter-spacing: 0.8px;
  opacity: 0.8;
`;

const DownloadList = styled.div`
  display: flex;
  flex-direction: column;
  gap: 12px;
  flex: 1;
`;

const DownloadCard = styled.div`
  background: var(--card-bg);
  border-radius: 14px;
  padding: 14px;
  display: flex;
  align-items: center;
  gap: 14px;
  border: 1px solid var(--border-color);
  backdrop-filter: blur(10px);
  box-shadow: 0 2px 6px var(--shadow-color);
  transition: all 0.2s ease;
  
  &:hover {
      background: var(--border-color-light);
      transform: translateX(2px);
  }
`;

const FileIcon = styled.img`
  width: 36px;
  height: 36px;
  object-fit: contain;
  opacity: 0.9;
  filter: drop-shadow(0 2px 4px rgba(0,0,0,0.1));
`;

const FileInfo = styled.div`
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 4px;
`;

const FileName = styled.div`
  font-size: 14px;
  font-weight: 500;
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
`;

const EmptyState = styled.div`
  text-align: center;
  color: var(--text-secondary);
  font-size: 13px;
  padding: 40px 0;
  opacity: 0.6;
  font-weight: 500;
`;

// --- Components ---

function ActionButton({ icon, label, onClick, title }) {
  return (
    <ActionButtonWrapper>
      <StyledIconButton onClick={onClick} title={title || label}>
        {icon}
      </StyledIconButton>
      <ActionLabel>{label}</ActionLabel>
    </ActionButtonWrapper>
  );
}

function DownloadItem({ item }) {
  const parseName = (name) => {
    if (!name) return 'Unknown';
    // keep only filename
    const parts = name.split(/[/\\]/);
    return parts[parts.length - 1];
  };

  const progress = item.size > 0 ? Math.min((item.downloaded * 100) / item.size, 100) : 0;

  const handleOpen = () => {
    if (item.downloader === 'aria') {
      browser.tabs.create({ url: 'motrixmac://show' });
    } else {
      browser.downloads.show(item.gid);
    }
  };

  return (
    <DownloadCard>
      <FileIcon src={item.icon || '../images/file_icon.png'} onError={(e) => { e.target.src = '../images/file_icon.png' }} />
      <FileInfo>
        <FileName title={item.name}>{parseName(item.name)}</FileName>
        {item.status === 'downloading' && (
          <LinearProgress variant="determinate" value={progress} sx={{ height: 4, borderRadius: 2 }} />
        )}
      </FileInfo>
      {item.status === 'completed' && (
        <IconButton size="small" onClick={handleOpen}>
          <FolderIcon style={{ fontSize: 20, color: 'var(--text-secondary)' }} />
        </IconButton>
      )}
    </DownloadCard>
  );
}

function PopupView() {
  const [downloadHistory, setDownloadHistory] = useState([]);
  const [extensionStatus, setExtensionStatus] = useState(false);
  const [theme, setTheme] = useState('system');

  useEffect(() => {
    // Initial Load
    browser.storage.sync.get(['extensionStatus', 'theme']).then(res => {
      setExtensionStatus(res.extensionStatus !== false);
      setTheme(res.theme || 'system');
      applyTheme(res.theme || 'system');
    });

    const updateHistory = async () => {
      const { history = [] } = await browser.storage.local.get(['history']);
      // Filter last 5 items
      const recent = history.slice(0, 5);
      setDownloadHistory(recent);
    };

    updateHistory();
    const interval = setInterval(updateHistory, 1000); // Polling for updates

    return () => clearInterval(interval);
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

  const clearHistory = async () => {
    if (confirm(i18n('clearHistoryConfirm'))) {
      await browser.storage.local.set({ history: [] });
      setDownloadHistory([]);
    }
  };

  const openSettings = () => browser.runtime.openOptionsPage();
  const openMotrix = () => browser.tabs.create({ url: 'motrixmac://show' });
  const openBrowserDownloads = () => browser.downloads.showDefaultFolder();

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

        <ActionGrid>
          <ActionButton
            icon={<PowerSettingsNewIcon style={{ color: extensionStatus ? 'var(--success-color)' : 'var(--text-secondary)' }} />}
            label={extensionStatus ? i18n('btnOn') : i18n('btnOff')}
            onClick={toggleExtension}
          />
          <ActionButton
            icon={<OpenInNewIcon style={{ color: 'var(--primary-color)' }} />}
            label={i18n('btnMotrix')}
            onClick={openMotrix}
          />
          <ActionButton
            icon={<FolderIcon style={{ color: 'var(--text-secondary)' }} />}
            label={i18n('btnDownloads')}
            onClick={openBrowserDownloads}
          />
          <ActionButton
            icon={<ClearAllIcon style={{ color: 'var(--error-color)' }} />}
            label={i18n('btnClear')}
            onClick={clearHistory}
          />
        </ActionGrid>

        <SectionTitle>{i18n('recentDownloads')}</SectionTitle>

        <DownloadList>
          {downloadHistory.length === 0 ? (
            <EmptyState>{i18n('noRecentDownloads')}</EmptyState>
          ) : (
            downloadHistory.map(item => (
              <DownloadItem key={item.gid} item={item} />
            ))
          )}
        </DownloadList>

      </PopupContainer>
    </ThemeProvider>
  );
}

ReactDOM.render(<PopupView />, document.getElementById('react-root'));
