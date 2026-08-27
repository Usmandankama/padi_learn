import React from 'react';
import {Easing, interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {colors} from '../theme';

/**
 * The PadiLearn mark, animated as a plant growing.
 *
 * Rebuilt as live SVG rather than moving `icon_light.png` around, because the
 * point is to animate the parts *against each other* — the stem rising before
 * the bowl sweeps out, the leaf springing from its own base. A raster can only
 * be scaled and faded as one lump.
 *
 * The leaf, its vein and the curved shoot are the exact paths lifted from
 * `assets/branding/icon_foreground.svg`, so the organic shapes are the real
 * artwork. Only the "P" is reconstructed — it is two rounded rectangles and a
 * half-round right edge, which is trivial to match and much easier to reveal
 * piecewise than a converter's clip-path soup.
 *
 * Everything is keyed off `delay` so the same component can play as a standalone
 * sting and as the ad's closing card without the timings being written twice.
 */

/** Frame offsets within the build, relative to `delay`. */
const T = {
  tileIn: 0,
  stemRise: 12,
  bowlSweep: 26,
  shootDraw: 42,
  leafPop: 56,
  veinDraw: 72,
  shine: 84,
} as const;

/** Length of the shoot path, for the draw-on. Measured, not guessed. */
const SHOOT_LENGTH = 232;

export const LogoMark: React.FC<{
  delay?: number;
  /**
   * `tile` is the app-icon lockup: the mark on its rounded green tile.
   * `bare` is the same mark with the tile dropped, for sitting directly on a
   * brand-green background.
   *
   * The fills do NOT invert between them. The leaf is green *on* the white P
   * in the real artwork, so painting it white for a green background makes it
   * vanish into the letter — which is exactly what the first attempt did.
   */
  variant?: 'tile' | 'bare';
  size?: number;
  /**
   * Multiplies the build's pace. The full 110-frame growth reads well as a
   * standalone sting but eats an entire scene of the ad, so the closing card
   * runs it at roughly double speed.
   */
  speed?: number;
}> = ({delay = 0, variant = 'tile', size = 460, speed = 1}) => {
  const tile = variant === 'tile';
  const markFill = colors.appWhite;
  const leafFill = colors.primary;
  const veinFill = colors.appWhite;
  const frame = (useCurrentFrame() - delay) * speed;
  const {fps} = useVideoConfig();

  const at = (start: number, config?: Parameters<typeof spring>[0]['config']) =>
    spring({frame: frame - start, fps, config: {damping: 200, ...config}});

  const eased = (start: number, duration: number) =>
    interpolate(frame, [start, start + duration], [0, 1], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
      easing: Easing.inOut(Easing.cubic),
    });

  // Tile: springs up with a slight unwind, so it arrives rather than appears.
  const tileIn = at(T.tileIn, {damping: 14, mass: 0.8});
  const tileScale = interpolate(tileIn, [0, 1], [0.62, 1]);
  const tileSpin = interpolate(tileIn, [0, 1], [-8, 0]);

  // The stem grows upward: an inset clip retreating from the bottom edge.
  const stemRise = eased(T.stemRise, 20);
  // The bowl then sweeps out to the right from the stem.
  const bowlSweep = eased(T.bowlSweep, 18);
  // The shoot draws itself.
  const shootDraw = eased(T.shootDraw, 26);

  // The leaf springs from where it meets the shoot, overshooting slightly.
  const leafPop = at(T.leafPop, {damping: 11, mass: 0.7});
  const leafScale = interpolate(leafPop, [0, 1], [0, 1]);
  const leafTilt = interpolate(leafPop, [0, 1], [-28, 0]);

  const veinDraw = eased(T.veinDraw, 16);

  // A band of light crossing the mark once it has settled.
  const shine = interpolate(frame, [T.shine, T.shine + 26], [-1, 2], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.inOut(Easing.quad),
  });

  // Once built, the mark breathes very slightly so the frame is never static.
  const idle =
    1 + 0.012 * Math.sin(Math.max(0, frame - (T.shine + 20)) / 26);

  return (
    <svg
      width={size}
      height={size}
      viewBox="171 163 460 460"
      style={{
        overflow: 'visible',
        transform: `scale(${tileScale * idle}) rotate(${tileSpin}deg)`,
        opacity: interpolate(frame, [0, 6], [0, 1], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
        }),
      }}
    >
      <defs>
        {/* Confines the shine to the tile, so the band never spills into the
            frame around it. */}
        <clipPath id="tileClip">
          <rect x={171} y={163} width={460} height={460} rx={104} />
        </clipPath>

        <linearGradient id="shineGrad" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor="#fff" stopOpacity="0" />
          <stop offset="50%" stopColor="#fff" stopOpacity="0.5" />
          <stop offset="100%" stopColor="#fff" stopOpacity="0" />
        </linearGradient>

        <linearGradient id="tileGrad" x1="0" y1="0" x2="0.7" y2="1">
          <stop offset="0%" stopColor="#3AA87E" />
          <stop offset="100%" stopColor="#27795A" />
        </linearGradient>

        {/* The stem's reveal: an inset rect that retreats upward from the
            baseline, so the bar appears to grow out of the ground. */}
        <clipPath id="stemClip">
          <rect
            x={279.4}
            y={interpolate(stemRise, [0, 1], [560.8, 225.3])}
            width={107.7}
            height={interpolate(stemRise, [0, 1], [0, 335.5])}
          />
        </clipPath>

        <clipPath id="bowlClip">
          <rect
            x={279.4}
            y={219}
            width={interpolate(bowlSweep, [0, 1], [0, 250])}
            height={212}
          />
        </clipPath>
      </defs>

      <g clipPath="url(#tileClip)">
        {tile ? (
          <rect
            x={171}
            y={163}
            width={460}
            height={460}
            rx={104}
            fill="url(#tileGrad)"
          />
        ) : null}

        {/* --- the P ------------------------------------------------------ */}
        {/* Bowl first in paint order; the stem overlaps its left edge so the
            two read as one letter rather than a bar beside a D. */}
        <path
          clipPath="url(#bowlClip)"
          fill={markFill}
          d="M 295.9 225.35
             H 421.7
             A 101.18 101.18 0 0 1 421.7 427.71
             H 295.9
             A 16.5 16.5 0 0 1 279.4 411.21
             V 241.85
             A 16.5 16.5 0 0 1 295.9 225.35 Z"
        />
        <rect
          clipPath="url(#stemClip)"
          x={279.4}
          y={225.35}
          width={107.7}
          height={335.43}
          rx={16.5}
          fill={markFill}
        />

        {/* --- the shoot, drawing itself ---------------------------------- */}
        <path
          transform="matrix(0.440818, 0.606778, -0.606778, 0.440818, 284.446746, 335.915511)"
          d="M 14.298686 46.19023 C 76.304646 -2.083867 138.310067 -2.062778 200.316099 46.260772"
          fill="none"
          stroke={leafFill}
          strokeWidth={20}
          strokeLinecap="round"
          strokeDasharray={SHOOT_LENGTH}
          strokeDashoffset={interpolate(shootDraw, [0, 1], [SHOOT_LENGTH, 0])}
        />

        {/* --- the leaf, springing from where it meets the shoot ----------- */}
        <g
          style={{
            transform: `translate(338px, 402px) rotate(${leafTilt}deg) scale(${leafScale}) translate(-338px, -402px)`,
            transformBox: 'view-box',
          }}
        >
          <path
            d="M 460.125 277.164062 C 445.289062 329.625 440.742188 412.523438 338.628906 401.957031 C 324.828125 285.390625 425.144531 305.945312 460.125 277.164062 Z"
            fill={leafFill}
          />
          <path
            d="M 411.738281 324.605469 C 373.648438 348.777344 346.242188 379.550781 322.0625 417.269531 C 317.234375 424.800781 331.847656 426.144531 333.644531 422.429688 C 353.816406 380.769531 380.414062 351.519531 411.738281 324.605469 Z"
            fill={veinFill}
            opacity={veinDraw}
            style={{
              transform: `translate(367px, 375px) scale(${interpolate(
                veinDraw,
                [0, 1],
                [0.7, 1],
              )}) translate(-367px, -375px)`,
              transformBox: 'view-box',
            }}
          />
        </g>

        {/* --- the pass of light ------------------------------------------ */}
        <rect
          x={171 + shine * 460 - 130}
          y={100}
          width={130}
          height={600}
          fill="url(#shineGrad)"
          transform={`rotate(14 ${171 + shine * 460 - 65} 393)`}
          style={{mixBlendMode: 'soft-light'}}
        />
      </g>
    </svg>
  );
};
