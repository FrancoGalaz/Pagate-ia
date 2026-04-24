/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        brand: '#006B5F',
        'brand-dark': '#005a50',
        'brand-light': '#E6F2F0',
        'brand-subtle': '#F0F7F6',
        accent: '#FF735C',
        'accent-light': '#FFF0ED',
        'accent-dark': '#E85D47',
        bg: '#F3F4F6',
        surface: '#FFFFFF',
        'surface-secondary': '#F8FAFC',
        'text-primary': '#16213E',
        'text-secondary': '#6B7280',
        'text-muted': '#9CA3AF',
        border: '#E5E7EB',
        'border-light': '#F3F4F6',
        'dark-bg': '#16213E',
        'dark-surface': '#1F283E',
        success: '#10B981',
      },
      fontFamily: {
        sans: ['Manrope', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        display: ['Outfit', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
