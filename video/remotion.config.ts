import {Config} from '@remotion/cli/config';

Config.setVideoImageFormat('jpeg');
Config.setOverwriteOutput(true);
// The mock screens are flat colour and text; CRF 18 keeps the type crisp
// without the file size a lossless render would cost.
Config.setCrf(18);
