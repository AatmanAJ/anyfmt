import cassette from './assets/cassette.webp'
import chrome from './assets/chrome.webp'
import film from './assets/film.webp'
import floppy from './assets/floppy.webp'
import folder from './assets/folder.webp'
import photo from './assets/photo.webp'
import shift from './assets/shift.webp'

/** Objects generated with Higgsfield (gpt_image_2_5, transparent), trimmed to content. */
export const ASSETS = {
  cassette: { src: cassette, ratio: 640 / 606 },
  chrome: { src: chrome, ratio: 426 / 640 },
  film: { src: film, ratio: 621 / 640 },
  floppy: { src: floppy, ratio: 614 / 640 },
  folder: { src: folder, ratio: 562 / 640 },
  photo: { src: photo, ratio: 543 / 640 },
  shift: { src: shift, ratio: 640 / 402 },
} as const
