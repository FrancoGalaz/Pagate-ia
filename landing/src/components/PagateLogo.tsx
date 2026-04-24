export default function PagateLogo({ className = 'h-9' }: { className?: string }) {
  return (
    <img
      src="/assets/brand/logo-horizontal.png"
      alt="Pagate"
      className={`object-contain ${className}`}
    />
  );
}
