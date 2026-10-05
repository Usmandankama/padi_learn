import React from 'react';
import {AbsoluteFill} from 'remotion';
import {loadFont as loadPoppins} from '@remotion/google-fonts/Poppins';
import {loadFont as loadPlayfair} from '@remotion/google-fonts/PlayfairDisplay';
import {colors} from './theme';
import {announcement} from './announcement';
import {LogoMark} from './components/LogoMark';

const {fontFamily: poppins} = loadPoppins();
const {fontFamily: playfair} = loadPlayfair();

/**
 * The "first teachers" flyer — the still companion to `TeacherCall`.
 *
 * Same copy, same argument, one page. Laid out as a notice rather than an
 * advert: a header rule, a hanging left margin, one statement set large, the
 * number, the terms as a ruled list, and metadata in the footer. The things
 * that make a graphic look generated are all absent on purpose — no gradient
 * ground, no glow, no rounded card floating on a background, no centred
 * stack, no photograph of somebody at a laptop. Flat brand colour and
 * hairlines, and the only ornament is the mark.
 *
 * Two variants, because a flyer here has two lives. `dark` is for sharing —
 * WhatsApp, status, a feed, where it sits against other images and has to
 * hold its own. `light` is for paper, where a dark ground is a print bill
 * and a smudge. They are the same layout; only the palette swaps, so neither
 * can drift.
 */

export type FlyerTheme = 'dark' | 'light';

const palettes = {
  dark: {
    ground: colors.richBlack,
    ink: colors.appWhite,
    inkSoft: 'rgba(255,255,255,0.6)',
    inkFaint: 'rgba(255,255,255,0.42)',
    rule: 'rgba(255,255,255,0.16)',
    accent: colors.primary,
  },
  light: {
    // Warm off-white rather than paper white: it prints without looking like
    // an unstyled page, and matches the lesson boards.
    ground: '#F7F5F0',
    ink: colors.richBlack,
    inkSoft: 'rgba(13,27,42,0.66)',
    inkFaint: 'rgba(13,27,42,0.5)',
    rule: 'rgba(13,27,42,0.16)',
    accent: '#257356',
  },
} as const;

const MARGIN = 78;

export const TeacherFlyer: React.FC<{theme?: FlyerTheme}> = ({
  theme = 'dark',
}) => {
  const c = palettes[theme];

  return (
    <AbsoluteFill
      style={{
        background: c.ground,
        padding: MARGIN,
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'space-between',
        WebkitFontSmoothing: 'antialiased',
      }}
    >
      {/* ---- header ---- */}
      <div>
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'baseline',
            fontFamily: poppins,
            fontSize: 17,
            fontWeight: 600,
            letterSpacing: 2.4,
            textTransform: 'uppercase',
          }}
        >
          <span style={{color: c.accent}}>PadiLearn</span>
          <span style={{color: c.inkFaint}}>{announcement.eyebrow}</span>
        </div>
        <div style={{height: 1, background: c.rule, marginTop: 16}} />

        <div
          style={{
            fontFamily: playfair,
            fontSize: 86,
            fontWeight: 700,
            lineHeight: 1.02,
            letterSpacing: -2,
            color: c.ink,
            marginTop: 54,
          }}
        >
          You already teach.
          <br />
          <span style={{color: c.accent}}>Put it in a course.</span>
        </div>

        <div
          style={{
            fontFamily: poppins,
            fontSize: 25,
            lineHeight: 1.5,
            color: c.inkSoft,
            marginTop: 26,
            maxWidth: 740,
          }}
        >
          {announcement.blurb}
        </div>
      </div>

      {/* ---- the number ---- */}
      <div style={{display: 'flex', alignItems: 'flex-end', gap: 30, padding: '10px 0 22px'}}>
        <div
          style={{
            fontFamily: playfair,
            fontSize: 208,
            fontWeight: 700,
            lineHeight: 0.82,
            letterSpacing: -7,
            color: c.accent,
          }}
        >
          {announcement.share.figure}
        </div>
        <div
          style={{
            fontFamily: playfair,
            fontSize: 44,
            fontWeight: 700,
            letterSpacing: -0.5,
            color: c.ink,
            paddingBottom: 10,
            maxWidth: 300,
            lineHeight: 1.14,
          }}
        >
          {announcement.share.of}
        </div>
      </div>

      {/* ---- terms ---- */}
      <div>
        {announcement.terms.map((term) => (
          <div
            key={term}
            style={{
              borderTop: `1px solid ${c.rule}`,
              padding: '17px 0',
              fontFamily: poppins,
              fontSize: 27,
              fontWeight: 500,
              color: c.ink,
            }}
          >
            {term}
          </div>
        ))}
        <div
          style={{
            borderTop: `1px solid ${c.rule}`,
            paddingTop: 22,
            fontFamily: poppins,
            fontSize: 24,
            color: c.inkSoft,
          }}
        >
          {announcement.worked.label}{' '}
          <span style={{color: c.ink, fontWeight: 600}}>
            {announcement.worked.price}
          </span>{' '}
          {announcement.worked.middle}{' '}
          <span style={{color: c.accent, fontWeight: 700}}>
            {announcement.worked.earn}
          </span>
          .
        </div>
      </div>

      {/* ---- footer ---- */}
      <div>
        <div style={{height: 1, background: c.rule, marginBottom: 26}} />
        <div
          style={{
            display: 'flex',
            alignItems: 'flex-end',
            justifyContent: 'space-between',
            gap: 30,
          }}
        >
          <div style={{flex: 1}}>
            <div
              style={{
                fontFamily: poppins,
                fontSize: 21,
                lineHeight: 1.5,
                color: c.inkSoft,
                whiteSpace: 'pre-line',
              }}
            >
              {announcement.status}
            </div>
            <div
              style={{
                fontFamily: playfair,
                fontSize: 42,
                fontWeight: 700,
                color: c.ink,
                letterSpacing: -0.8,
                marginTop: 16,
              }}
            >
              {announcement.cta.site}
            </div>
            <div
              style={{
                fontFamily: poppins,
                fontSize: 21,
                color: c.inkFaint,
                marginTop: 7,
              }}
            >
              {announcement.cta.email} · {announcement.colophon}
            </div>
          </div>
          {/* A negative delay, not speed 0. `LogoMark` multiplies the frame
              by speed, so zero would hold it at frame 0 — the mark before it
              has grown. Winding the clock forward past the 110-frame build
              lands it settled, which is the only state a still wants. */}
          <LogoMark
            variant={theme === 'dark' ? 'bare' : 'tile'}
            size={theme === 'dark' ? 126 : 112}
            delay={-200}
          />
        </div>
      </div>
    </AbsoluteFill>
  );
};
