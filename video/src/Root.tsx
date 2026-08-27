import React from 'react';
import {Composition} from 'remotion';
import {AppAd, AD_DURATION} from './AppAd';
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
      <Composition
        id="AppAdVertical"
        component={AppAd}
        durationInFrames={AD_DURATION}
        fps={FPS}
        width={1080}
        height={1920}
      />
    </>
  );
};
