import React from 'react';
import styled from '@emotion/styled';
import { Switch, IconButton, Tooltip, InputAdornment } from '@mui/material';
import InfoOutlinedIcon from '@mui/icons-material/InfoOutlined';
import Visibility from '@mui/icons-material/Visibility';
import VisibilityOff from '@mui/icons-material/VisibilityOff';

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
  gap: 8px;
  align-items: center;
  width: 100%;
  margin-top: 8px;
`;

const InputWrapper = styled.div`
  position: relative;
  flex: 1;
  display: flex;
  align-items: center;
`;

const VisibilityButton = styled(IconButton)`
  position: absolute;
  right: 8px;
  padding: 4px;
  color: var(--text-secondary);
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
            <InfoOutlinedIcon
              style={{
                fontSize: 16,
                color: 'var(--text-secondary)',
                cursor: 'help',
              }}
            />
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

export const InputGroup = ({
  value,
  onChange,
  placeholder,
  onSave,
  type = 'text',
  buttonLabel = 'Save',
}) => {
  const [showPassword, setShowPassword] = React.useState(false);
  const isPassword = type === 'password';

  return (
    <InputRowContainer>
      <InputWrapper>
        <StyledInput
          type={isPassword ? (showPassword ? 'text' : 'password') : type}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          style={{ paddingRight: isPassword ? '40px' : '14px' }}
        />
        {isPassword && (
          <VisibilityButton
            size="small"
            onClick={() => setShowPassword(!showPassword)}
          >
            {showPassword ? (
              <VisibilityOff fontSize="small" />
            ) : (
              <Visibility fontSize="small" />
            )}
          </VisibilityButton>
        )}
      </InputWrapper>
      <ActionButton className="secondary" onClick={onSave}>
        {buttonLabel}
      </ActionButton>
    </InputRowContainer>
  );
};

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

export const Select = styled.select`
  appearance: none;
  background: var(--input-bg);
  border: 1px solid var(--border-color);
  color: var(--text-primary);
  padding: 8px 32px 8px 12px;
  border-radius: 8px;
  font-size: 14px;
  outline: none;
  cursor: pointer;
  background-image: url('data:image/svg+xml;charset=US-ASCII,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%22292.4%22%20height%3D%22292.4%22%3E%3Cpath%20fill%3D%22%23AAAAAA%22%20d%3D%22M287%2069.4a17.6%2017.6%200%200%200-13-5.4H18.4c-5%200-9.3%201.8-12.9%205.4A17.6%2017.6%200%200%200%200%2082.2c0%205%201.8%209.3%205.4%2012.9l128%20127.9c3.6%203.6%207.8%205.4%2012.8%205.4s9.2-1.8%2012.8-5.4L287%2095c3.5-3.5%205.4-7.8%205.4-12.8%200-5-1.9-9.2-5.5-12.8z%22%2F%3E%3C%2Fsvg%3E');
  background-repeat: no-repeat;
  background-position: right 12px top 50%;
  background-size: 10px auto;
  min-width: 120px;

  &:focus {
    border-color: var(--primary-color);
  }
`;

const BlacklistContainer = styled.div`
  background: var(--input-bg);
  border: 1px solid var(--border-color);
  border-radius: 12px;
  padding: 12px;
  min-height: 120px;
  display: flex;
  flex-direction: column;
  gap: 8px;
`;

const ChipContainer = styled.div`
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 8px;
  max-height: 200px;
  overflow-y: auto;
`;

const Chip = styled.div`
  background: var(--card-bg);
  border: 1px solid var(--border-color);
  border-radius: 6px;
  padding: 4px 8px;
  font-size: 13px;
  font-family: 'Menlo', monospace;
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--text-primary);
`;

const DeleteButton = styled.button`
  background: none;
  border: none;
  cursor: pointer;
  padding: 0;
  display: flex;
  align-items: center;
  color: var(--text-secondary);
  opacity: 0.6;

  &:hover {
    opacity: 1;
    color: #ff4d4f;
  }
`;

const AddRow = styled.div`
  display: flex;
  gap: 8px;
`;

export const BlacklistEditor = ({
  items,
  onAdd,
  onRemove,
  placeholder,
  cta,
}) => {
  const [text, setText] = React.useState('');

  const handleAdd = () => {
    if (text.trim()) {
      onAdd(text.trim());
      setText('');
    }
  };

  const handleKeyDown = (e) => {
    if (e.key === 'Enter') {
      handleAdd();
    }
  };

  return (
    <BlacklistContainer>
      <ChipContainer>
        {items.map((item, idx) => (
          <Chip key={`${item}-${idx}`}>
            {item}
            <DeleteButton onClick={() => onRemove(item)}>
              <svg
                width="12"
                height="12"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <line x1="18" y1="6" x2="6" y2="18"></line>
                <line x1="6" y1="6" x2="18" y2="18"></line>
              </svg>
            </DeleteButton>
          </Chip>
        ))}
      </ChipContainer>
      <AddRow>
        <StyledInput
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder={placeholder || 'domain.com'}
        />
        <ActionButton onClick={handleAdd} disabled={!text.trim()}>
          {cta || 'Add'}
        </ActionButton>
      </AddRow>
    </BlacklistContainer>
  );
};
