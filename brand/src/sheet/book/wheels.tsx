import { Clipboard, Crop, EyeOff, FolderInput, Info, Layers, Link, Minimize2, PenLine, Scissors, Share, SquareTerminal } from 'lucide-react'
import type { Wedge } from '../SheetWheel'

const ic = (I: typeof Crop) => <I size={16} strokeWidth={1.5} />

export const CONVERT: Wedge[] = [
  { id: 'gif', label: 'GIF', sub: '3.8 MB' }, { id: 'mp4', label: 'MP4', sub: '1.2 MB' }, { id: 'webm', label: 'WEBM', sub: '0.9 MB' },
  { id: 'm4v', label: 'M4V', sub: '1.3 MB' }, { id: 'mp3', label: 'MP3', sub: 'audio' }, { id: 'png', label: 'PNG', sub: 'frame' },
]
export const TOOLS: Wedge[] = [
  { id: 'compress', label: 'Compress', icon: ic(Minimize2) }, { id: 'crop', label: 'Crop', icon: ic(Crop) }, { id: 'trim', label: 'Trim', icon: ic(Scissors) },
  { id: 'redact', label: 'Redact', icon: ic(EyeOff) }, { id: 'annotate', label: 'Annotate', icon: ic(PenLine) }, { id: 'meta', label: 'Metadata', icon: ic(Info) },
]
export const ACTIONS: Wedge[] = [
  { id: 'airdrop', label: 'AirDrop', icon: ic(Share) }, { id: 'float', label: 'Float', icon: ic(Layers) }, { id: 'copy', label: 'Copy', icon: ic(Clipboard) },
  { id: 'move', label: 'Move', icon: ic(FolderInput) }, { id: 'path', label: 'Copy Path', icon: ic(Link) }, { id: 'term', label: 'Terminal', icon: ic(SquareTerminal) },
]
