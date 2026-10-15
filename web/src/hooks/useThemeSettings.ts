import { useEffect, useState } from 'react';
import apiClient from '../api/client';
import { useAuth } from './useAuth';

export interface AppSettings {
  'theme.seedColorIndex'?: number;
  'theme.themeMode'?: number; // 0: system, 1: light, 2: dark
  'theme.fontScale'?: number;
  [key: string]: any;
}

export const PRESET_SEEDS = [
  { seed: '#006874', darkPrimary: '#85D2E0', darkContainer: '#006874', lightPrimary: '#006874', lightContainer: '#9EEFFD' }, // Deep Teal
  { seed: '#6750A4', darkPrimary: '#D0BCFF', darkContainer: '#4F378B', lightPrimary: '#6750A4', lightContainer: '#EADDFF' }, // Purple
  { seed: '#0061A4', darkPrimary: '#9ECAFF', darkContainer: '#004A77', lightPrimary: '#0061A4', lightContainer: '#D1E4FF' }, // Blue
  { seed: '#006E1C', darkPrimary: '#80DC89', darkContainer: '#005313', lightPrimary: '#006E1C', lightContainer: '#9BF6A3' }, // Green
  { seed: '#B3261E', darkPrimary: '#FFB4AB', darkContainer: '#93000A', lightPrimary: '#B3261E', lightContainer: '#F9DEDC' }, // Red
  { seed: '#984061', darkPrimary: '#FFB1C8', darkContainer: '#7D264A', lightPrimary: '#984061', lightContainer: '#FFD9E2' }, // Pink
  { seed: '#AC3306', darkPrimary: '#FFB599', darkContainer: '#8D1500', lightPrimary: '#AC3306', lightContainer: '#FFDBCF' }, // Orange
  { seed: '#7B5800', darkPrimary: '#E8C16C', darkContainer: '#5D4200', lightPrimary: '#7B5800', lightContainer: '#FFDEA1' }, // Brown/Amber
  { seed: '#386667', darkPrimary: '#4ED8D9', darkContainer: '#004F50', lightPrimary: '#00696A', lightContainer: '#6FF6F7' }, // Cyan
  { seed: '#343DFF', darkPrimary: '#BFC2FF', darkContainer: '#0008A6', lightPrimary: '#343DFF', lightContainer: '#E0E0FF' }, // Indigo
  { seed: '#1B6B46', darkPrimary: '#89D6A1', darkContainer: '#00522B', lightPrimary: '#1B6B46', lightContainer: '#A4F2BC' }, // Forest
  { seed: '#4A4458', darkPrimary: '#CCC2DC', darkContainer: '#332D41', lightPrimary: '#625B71', lightContainer: '#E8DEF8' }, // Slate
];

export function applyThemeToDom(data: AppSettings) {
  const root = document.documentElement;

  // Apply Theme Mode (1: light, 2: dark, 0: system)
  const modeIndex = data['theme.themeMode'] ?? 2;
  const isDark = modeIndex === 2 || (modeIndex === 0 && window.matchMedia('(prefers-color-scheme: dark)').matches);

  if (isDark) {
    root.classList.add('dark');
  } else {
    root.classList.remove('dark');
  }

  // Apply Seed Color
  const seedIndex = data['theme.seedColorIndex'] ?? 0;
  const seed = PRESET_SEEDS[seedIndex] || PRESET_SEEDS[0];
  const primary = isDark ? seed.darkPrimary : seed.lightPrimary;
  const container = isDark ? seed.darkContainer : seed.lightContainer;
  root.style.setProperty('--color-primary', primary);
  root.style.setProperty('--color-primary-container', container);

  // Apply Font Scale
  const fontScale = data['theme.fontScale'] ?? 1.0;
  root.style.setProperty('--font-scale', String(fontScale));
}

export function useThemeSettings() {
  const { isAuthenticated } = useAuth();
  const [settings, setSettings] = useState<AppSettings | null>(null);

  useEffect(() => {
    if (!isAuthenticated) return;

    const fetchSettings = async () => {
      try {
        const response = await apiClient.get('/settings');
        const data = response.data.data;
        setSettings(data);
        applyThemeToDom(data);
      } catch (error) {
        console.error('Failed to fetch settings:', error);
      }
    };

    fetchSettings();
  }, [isAuthenticated]);

  return { settings };
}
