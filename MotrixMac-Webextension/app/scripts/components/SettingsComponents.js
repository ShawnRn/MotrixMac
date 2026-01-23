import React from 'react';
import styled from '@emotion/styled';
import { Switch, IconButton, Tooltip } from '@mui/material';
import InfoOutlinedIcon from '@mui/icons-material/InfoOutlined';

// --- Styled Components ---

const Card = styled.div`
  background: var(--card-bg);
  border-radius: 16px;
  padding: 24px;
  margin-bottom: 20px;
  box-shadow: 0 4px 24px var(--shadow-color);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px solid var(--border-color);
  transition: transform 0.2s ease, box-shadow 0.2s ease;

  &:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 32px var(--shadow-color-hover);
  }
`;

const SectionTitle = styled.h3`
  font-size: 13px;
  font-weight: 600;
  color: var(--text-secondary);
  text-transform: uppercase;
  margin: 0 0 16px 4px;
  letter-spacing: 0.8px;
`;

const Row = styled.div`
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 0;
  border-bottom: 1px solid var(--border-color-light);

  &:last-child {
    border-bottom: none;
  }
`;

const LabelGroup = styled.div`
  display: flex;
  flex-direction: column;
`;

const Label = styled.div`
  font-size: 15px;
  font-weight: 500;
  color: var(--text-primary);
  display: flex;
  align-items: center;
  gap: 6px;
`;

const Description = styled.div`
  font-size: 13px;
  color: var(--text-secondary);
  margin-top: 4px;
`;

const StyledInput = styled.input`
  background: var(--input-bg);
  border: 1px solid var(--border-color);
  color: var(--text-primary);
  padding: 10px 14px;
  border-radius: 8px;
  font-size: 14px;
  outline: none;
  transition: all 0.2s;
  width: 100%;
  box-sizing: border-box;

  &:focus {
    border-color: var(--primary-color);
    box-shadow: 0 0 0 3px var(--primary-color-dim);
  }
`;

const ActionButton = styled.button`
  background: var(--primary-color);
  color: white;
  border: none;
  padding: 10px 18px;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  white-space: nowrap;

  &:hover {
    opacity: 0.9;
    transform: translateY(-1px);
  }

  &:active {
    transform: translateY(0);
  }

  &.secondary {
    background: transparent;
    color: var(--primary-color);
    border: 1px solid var(--primary-color);
    
    &:hover {
      background: var(--primary-color-dim);
    }
  }
`;

const InputRowContainer = styled.div`
    display: flex;
    gap: 12px;
    align-items: center;
    width: 100%;
    margin-top: 8px;
`;

// --- Public Components ---

export const SettingsCard = ({ title, children }) => (
    <Card>
        {title && <SectionTitle>{title}</SectionTitle>}
        {children}
    </Card>
);

export const SettingsRow = ({ label, description, icon, children, info }) => (
    <Row>
        <LabelGroup>
            <Label>
                {icon && <span style={{ display: 'flex' }}>{icon}</span>}
                {label}
                {info && (
                    <Tooltip title={info} arrow placement="top">
                        <InfoOutlinedIcon style={{ fontSize: 16, color: 'var(--text-secondary)', cursor: 'help' }} />
                    </Tooltip>
                )}
            </Label>
            {description && <Description>{description}</Description>}
        </LabelGroup>
        <div>{children}</div>
    </Row>
);

export const ToggleSwitch = ({ checked, onChange }) => (
    <Switch
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        color="primary"
        inputProps={{ 'aria-label': 'toggle switch' }}
    />
);

export const InputGroup = ({ value, onChange, placeholder, onSave, type = "text", buttonLabel = "Save" }) => (
    <InputRowContainer>
        <StyledInput
            type={type}
            value={value}
            onChange={(e) => onChange(e.target.value)}
            placeholder={placeholder}
        />
        <ActionButton className="secondary" onClick={onSave}>{buttonLabel}</ActionButton>
    </InputRowContainer>
);

export const TextArea = styled.textarea`
  background: var(--input-bg);
  border: 1px solid var(--border-color);
  color: var(--text-primary);
  padding: 14px;
  border-radius: 12px;
  font-size: 13px;
  font-family: 'Menlo', 'Monaco', monospace;
  outline: none;
  width: 100%;
  min-height: 120px;
  resize: vertical;
  box-sizing: border-box;
  transition: all 0.2s;

  &:focus {
    border-color: var(--primary-color);
    box-shadow: 0 0 0 3px var(--primary-color-dim);
  }
`;

export const PrimaryButton = styled(ActionButton)`
    width: 100%;
    margin-top: 12px;
`;
