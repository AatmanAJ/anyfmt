/** Bundled engine versions, from Engines/VERSIONS.md. */
export const BUNDLED: { name: string; version: string; licence: string; does: string }[] = [
  { name: 'FFmpeg', version: '9.0.2', licence: 'GPL-2.0+', does: 'Video and audio, built without network support' },
  { name: 'x264', version: 'stable', licence: 'GPL-2.0+', does: 'H.264 encoding' },
  { name: 'x265', version: '4.2', licence: 'GPL-2.0+', does: 'HEVC encoding' },
  { name: 'libaom', version: '3.15.2', licence: 'BSD-2', does: 'AV1 encoding' },
  { name: 'dav1d', version: '1.5.4', licence: 'BSD-2', does: 'AV1 decoding' },
  { name: 'libvpx', version: '1.17.0', licence: 'BSD-3', does: 'VP8 and VP9' },
  { name: 'Opus', version: '1.6.1', licence: 'BSD-3', does: 'Opus audio' },
  { name: 'LAME', version: '3.100', licence: 'LGPL-2.0+', does: 'MP3 encoding' },
  { name: 'libvorbis', version: '1.3.7', licence: 'BSD-3', does: 'Ogg Vorbis' },
  { name: 'libwebp', version: '1.6.0', licence: 'BSD-3', does: 'WebP' },
  { name: 'resvg', version: '0.48.1', licence: 'Apache-2.0 / MIT', does: 'SVG rendering' },
  { name: 'Sparkle', version: '2.10.0', licence: 'MIT', does: 'Opt-in updates' },
]
