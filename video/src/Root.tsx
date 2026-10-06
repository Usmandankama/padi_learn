import React from 'react';
import {Composition} from 'remotion';
import {AppAd, AD_DURATION} from './AppAd';
import {LogoSting, STING_DURATION} from './LogoSting';
import {EditorsNotes} from './EditorsNotes';
import {TeacherCall, CALL_DURATION} from './TeacherCall';
import {TeacherFlyer} from './TeacherFlyer';
import {FPS} from './theme';

/**
 * Two cuts of the same ad.
 *
 * 16:9 is the one that goes in the app as the "Welcome to PadiLearn" course
 * video; 9:16 is for stores and social. They share every component and all the
 * copy, so they cannot disagree — only the frame does.
 */
export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="AppAdLandscape"
        component={AppAd}
        durationInFrames={AD_DURATION}
        fps={FPS}
        width={1920}
        height={1080}
      />
      {/* The marked-up reference cut. Separate from AppAdLandscape on
          purpose: there is no flag that could leave the notes switched on in
          the deliverable. */}
      <Composition
        id="EditorsNotes"
        component={EditorsNotes}
        durationInFrames={AD_DURATION}
        fps={FPS}
        width={1920}
        height={1080}
      />
      <Composition
        id="LogoSting"
        component={LogoSting}
        durationInFrames={STING_DURATION}
        fps={FPS}
        width={1920}
        height={1080}
      />
      <Composition
        id="LogoStingSquare"
        component={LogoSting}
        durationInFrames={STING_DURATION}
        fps={FPS}
        width={1080}
        height={1080}
      />
      <Composition
        id="AppAdVertical"
        component={AppAd}
        durationInFrames={AD_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
      />

      {/* ---- the "first teachers" announcement ----
          A separate campaign from the product ad, addressed to teachers
          rather than learners. Shares the palette, the mark and the fonts,
          and nothing else: see the note at the top of `TeacherCall`. */}
      <Composition
        id="TeacherCall"
        component={TeacherCall}
        durationInFrames={CALL_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
      />
      <Composition
        id="TeacherCallSquare"
        component={TeacherCall}
        durationInFrames={CALL_DURATION}
        fps={FPS}
        width={1080}
        height={1080}
      />
      {/* Stills. One frame each; rendered with `remotion still`. 1080x1350 is
          the tallest a feed shows without cropping, and crops to A-series
          cleanly enough to print. */}
      <Composition
        id="TeacherFlyer"
        component={TeacherFlyer}
        durationInFrames={1}
        fps={FPS}
        width={1080}
        height={1350}
        defaultProps={{theme: 'dark' as const}}
      />
      <Composition
        id="TeacherFlyerLight"
        component={TeacherFlyer}
        durationInFrames={1}
        fps={FPS}
        width={1080}
        height={1350}
        defaultProps={{theme: 'light' as const}}
      />
    </>
  );
};
