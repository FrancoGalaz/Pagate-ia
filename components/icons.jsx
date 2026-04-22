// Minimal SVG icons — stroke-based, match Material rounded feel
const Icon = ({ d, size = 20, color = 'currentColor', fill, strokeWidth = 2, filled }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill={filled ? color : (fill || 'none')}
       stroke={filled ? 'none' : color} strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
    {typeof d === 'string' ? <path d={d} /> : d}
  </svg>
);

const I = {
  home: (p) => <Icon {...p} d="M3 11l9-8 9 8v10a2 2 0 01-2 2h-4v-7H9v7H5a2 2 0 01-2-2V11z" />,
  chart: (p) => <Icon {...p} d={<><rect x="3" y="12" width="4" height="9" rx="1"/><rect x="10" y="6" width="4" height="15" rx="1"/><rect x="17" y="9" width="4" height="12" rx="1"/></>} />,
  inventory: (p) => <Icon {...p} d={<><path d="M3 7l9-4 9 4v10l-9 4-9-4V7z"/><path d="M3 7l9 4 9-4M12 11v10"/></>} />,
  bot: (p) => <Icon {...p} d={<><rect x="4" y="7" width="16" height="12" rx="3"/><circle cx="9" cy="13" r="1.2" fill={p?.color || 'currentColor'} stroke="none"/><circle cx="15" cy="13" r="1.2" fill={p?.color || 'currentColor'} stroke="none"/><path d="M12 3v4M8 19v2M16 19v2"/></>} />,
  user: (p) => <Icon {...p} d={<><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-7 8-7s8 3 8 7"/></>} />,
  bell: (p) => <Icon {...p} d="M6 8a6 6 0 1112 0c0 7 3 9 3 9H3s3-2 3-9zM10 21a2 2 0 004 0" />,
  arrowUp: (p) => <Icon {...p} d="M12 19V5M5 12l7-7 7 7" />,
  arrowDown: (p) => <Icon {...p} d="M12 5v14M5 12l7 7 7-7" />,
  plus: (p) => <Icon {...p} d="M12 5v14M5 12h14" strokeWidth={2.5} />,
  minus: (p) => <Icon {...p} d="M5 12h14" strokeWidth={2.5} />,
  search: (p) => <Icon {...p} d={<><circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/></>} />,
  send: (p) => <Icon {...p} d="M4 12l16-8-6 18-3-8-7-2z" />,
  wallet: (p) => <Icon {...p} d={<><rect x="3" y="6" width="18" height="14" rx="2"/><path d="M3 10h18M17 15h2"/></>} />,
  receipt: (p) => <Icon {...p} d="M6 2h12v20l-3-2-3 2-3-2-3 2V2zM9 7h6M9 11h6M9 15h4" />,
  trending: (p) => <Icon {...p} d="M3 17l6-6 4 4 8-8M15 7h6v6" />,
  tool: (p) => <Icon {...p} d="M14.7 6.3a4 4 0 00-5.6 5.6L3 18l3 3 6.1-6.1a4 4 0 005.6-5.6l-2.8 2.8-2.8-2.8 2.8-2.8z" />,
  settings: (p) => <Icon {...p} d={<><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 00.3 1.8l.1.1a2 2 0 11-2.8 2.8l-.1-.1a1.7 1.7 0 00-1.8-.3 1.7 1.7 0 00-1 1.5V21a2 2 0 11-4 0v-.1a1.7 1.7 0 00-1.1-1.5 1.7 1.7 0 00-1.8.3l-.1.1a2 2 0 11-2.8-2.8l.1-.1a1.7 1.7 0 00.3-1.8 1.7 1.7 0 00-1.5-1H3a2 2 0 110-4h.1a1.7 1.7 0 001.5-1.1 1.7 1.7 0 00-.3-1.8l-.1-.1a2 2 0 112.8-2.8l.1.1a1.7 1.7 0 001.8.3H9a1.7 1.7 0 001-1.5V3a2 2 0 114 0v.1a1.7 1.7 0 001 1.5 1.7 1.7 0 001.8-.3l.1-.1a2 2 0 112.8 2.8l-.1.1a1.7 1.7 0 00-.3 1.8v0a1.7 1.7 0 001.5 1H21a2 2 0 110 4h-.1a1.7 1.7 0 00-1.5 1z"/></>} />,
  help: (p) => <Icon {...p} d={<><circle cx="12" cy="12" r="10"/><path d="M9.1 9a3 3 0 015.8 1c0 2-3 3-3 3M12 17h.01"/></>} />,
  star: (p) => <Icon {...p} d="M12 2l3.1 6.3 6.9 1-5 4.9 1.2 6.8L12 17.8 5.8 21l1.2-6.8L2 9.3l6.9-1L12 2z" />,
  share: (p) => <Icon {...p} d={<><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="M8.6 13.5l6.8 4M15.4 6.5l-6.8 4"/></>} />,
  logout: (p) => <Icon {...p} d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4M16 17l5-5-5-5M21 12H9" />,
  chevron: (p) => <Icon {...p} d="M9 6l6 6-6 6" />,
  google: (p) => <Icon {...p} size={p?.size || 22} fill={<><path d="M21.8 12.2c0-.7-.1-1.4-.2-2H12v3.8h5.5a4.7 4.7 0 01-2 3.1v2.6h3.3c2-1.8 3-4.5 3-7.5z" fill="#4285F4"/><path d="M12 22c2.7 0 5-.9 6.7-2.4l-3.3-2.6a6 6 0 01-9-3.1H3v2.7A10 10 0 0012 22z" fill="#34A853"/><path d="M6.4 13.9a6 6 0 010-3.8V7.4H3a10 10 0 000 9.2l3.4-2.7z" fill="#FBBC05"/><path d="M12 6a5.4 5.4 0 013.8 1.5l2.9-2.9A10 10 0 003 7.4l3.4 2.7A6 6 0 0112 6z" fill="#EA4335"/></>} d={null} />,
  apple: (p) => <Icon {...p} filled d="M17.5 12.5c0-2.2 1.8-3.3 1.9-3.4a4 4 0 00-3.2-1.7c-1.4-.1-2.7.8-3.4.8-.7 0-1.8-.8-3-.8a4.3 4.3 0 00-3.6 2.2c-1.6 2.7-.4 6.6 1.1 8.8.7 1 1.6 2.2 2.8 2.2s1.6-.7 3-.7 1.8.7 3 .7 2.1-1.1 2.9-2.2a9.6 9.6 0 001.3-2.7 4 4 0 01-2.8-3.2zM15.5 6a4 4 0 001-3 4 4 0 00-2.6 1.4 3.7 3.7 0 00-1 2.9A3.3 3.3 0 0015.5 6z" />,
  handyman: (p) => <Icon {...p} d="M6 20l5-5M11 15l-2-2 6-6 2 2M14 6l4 4M9 8l2 2M16 3l5 5" />,
  ring: (p) => <Icon {...p} d={<><circle cx="12" cy="12" r="9"/></>} />,
};

window.I = I;
window.Icon = Icon;
