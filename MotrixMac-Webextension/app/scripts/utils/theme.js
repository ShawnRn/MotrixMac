import { css } from '@emotion/react';

export const globalStyles = css`
  :root {
    --primary-color: #007aff;
    --primary-color-dim: rgba(0, 122, 255, 0.15);
    --bg: #f2f2f7;
    --card-bg: rgba(255, 255, 255, 0.7);
    --text-primary: #000000;
    --text-secondary: #636366;
    --border-color: rgba(0, 0, 0, 0.1);
    --border-color-light: rgba(0, 0, 0, 0.05);
    --shadow-color: rgba(0, 0, 0, 0.08);
    --shadow-color-hover: rgba(0, 0, 0, 0.12);
    --input-bg: #ffffff;
    --success-color: #34c759;
    --error-color: #ff3b30;
  }

  @media (prefers-color-scheme: dark) {
    :root {
      --primary-color: #0a84ff;
      --primary-color-dim: rgba(10, 132, 255, 0.2);
      --bg: #000000;
      --card-bg: rgba(28, 28, 30, 0.7);
      --text-primary: #f5f5f7;
      --text-secondary: #98989d;
      --border-color: #38383a;
      --border-color-light: #2c2c2e;
      --shadow-color: rgba(0, 0, 0, 0.3);
      --shadow-color-hover: rgba(0, 0, 0, 0.5);
      --input-bg: rgba(255, 255, 255, 0.05);
    }
  }

  body {
    margin: 0;
    padding: 0;
    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI',
      Roboto, Helvetica, Arial, sans-serif;
    background-color: var(--bg);
    color: var(--text-primary);
    line-height: 1.5;
    transition: background-color 0.3s ease;
  }

  * {
    box-sizing: border-box;
  }

  /* Force dark mode via attribute */
  [data-theme='dark'] {
    --primary-color: #0a84ff;
    --primary-color-dim: rgba(10, 132, 255, 0.2);
    --bg: #000000;
    --card-bg: rgba(28, 28, 30, 0.7);
    --text-primary: #f5f5f7;
    --text-secondary: #98989d;
    --border-color: #38383a;
    --border-color-light: #2c2c2e;
    --shadow-color: rgba(0, 0, 0, 0.3);
    --shadow-color-hover: rgba(0, 0, 0, 0.5);
    --input-bg: rgba(255, 255, 255, 0.05);
  }

  [data-theme='light'] {
    --primary-color: #007aff;
    --primary-color-dim: rgba(0, 122, 255, 0.2);
    --bg: #f5f5f7;
    --card-bg: rgba(255, 255, 255, 0.8);
    --text-primary: #1d1d1f;
    --text-secondary: #86868b;
    --border-color: #e5e5e5;
    --border-color-light: #f0f0f0;
    --shadow-color: rgba(0, 0, 0, 0.05);
    --shadow-color-hover: rgba(0, 0, 0, 0.1);
    --input-bg: #ffffff;
  }
`;
