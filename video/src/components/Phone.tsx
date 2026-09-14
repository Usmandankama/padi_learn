import React from 'react';
import {DEVICE, colors} from '../theme';

/**
 * A device frame holding a screen laid out at the app's own design size
 * (393x852), scaled to whatever the scene needs.
 *
 * Children position themselves in real logical pixels — the same numbers the
 * Flutter widgets use — and the frame handles the scaling, so a mock screen can
 * be copied from a widget's dimensions without arithmetic.
 */
export const Phone: React.FC<{
  scale?: number;
  children: React.ReactNode;
}> = ({scale = 1, children}) => {
  const bezel = 12;

  return (
    <div
      style={{
        width: (DEVICE.width + bezel * 2) * scale,
        height: (DEVICE.height + bezel * 2) * scale,
        borderRadius: 54 * scale,
        padding: bezel * scale,
        background: 'linear-gradient(160deg, #1a1f26, #05070a)',
        boxShadow: `0 ${40 * scale}px ${90 * scale}px rgba(0,0,0,0.45)`,
        boxSizing: 'border-box',
      }}
    >
      <div
        style={{
          width: DEVICE.width * scale,
          height: DEVICE.height * scale,
          borderRadius: 42 * scale,
          overflow: 'hidden',
          background: colors.appWhite,
          position: 'relative',
        }}
      >
        {/* Children are authored at 1x and scaled as a unit. */}
        <div
          style={{
            width: DEVICE.width,
            height: DEVICE.height,
            transform: `scale(${scale})`,
            transformOrigin: 'top left',
            position: 'absolute',
            top: 0,
            left: 0,
          }}
        >
          {children}
        </div>
      </div>
    </div>
  );
};

/** The app's status bar, so mock screens don't float in a vacuum. */
export const StatusBar: React.FC<{poppins: string}> = ({poppins}) => (
  <div
    style={{
      height: 44,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '0 22px',
      fontFamily: poppins,
      fontSize: 12,
      fontWeight: 600,
      color: colors.richBlack,
    }}
  >
    <span>9:41</span>
    <span style={{letterSpacing: 2}}>▮▮▮</span>
  </div>
);
