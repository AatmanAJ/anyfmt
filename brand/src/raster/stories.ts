import interview from './assets/s-interview.webp'
import photos from './assets/s-photos.webp'
import receipts from './assets/s-receipts.webp'
import slides from './assets/s-slides.webp'

/** Use-case guides for the stories row. Photos generated with Higgsfield (gpt_image_2_5). */
export const STORIES = [
  { src: receipts, route: 'HEIC → PDF', t: 'Turn a pile of receipt photos into PDFs for your accountant' },
  { src: interview, route: 'M4A → MP3', t: 'Get an interview recording into the format your transcriber wants' },
  { src: photos, route: 'HEIC → JPG', t: 'Send a year of iPhone photos to a Windows laptop' },
  { src: slides, route: 'PPTX → PDF', t: 'Hand out slides as a PDF before the meeting starts' },
]
