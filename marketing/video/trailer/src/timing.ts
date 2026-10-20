// Beat grid for "A Game" (Mixkit 777), 126.25 BPM. public/music.mp3 starts 74.896 s into the
// track, exactly 4 bars before the drop (82.50 s in the original).
export const FPS = 60;
export const BEAT = 60 / 126.25;
export const BAR = BEAT * 4;
export const DROP = BAR * 4; // 7.6 s
export const DURATION = 30; // the track's own ending fades out around 29 s
export const f = (seconds: number) => Math.round(seconds * FPS);

export type Caption = { text: string; color?: string; sub?: string; top?: boolean };

export type Section = {
	clip: string; // public/clips/<clip>.mp4
	at: number; // seconds into the trailer
	dur: number;
	from?: number; // seconds into the clip
	rate?: number;
	caption?: Caption;
	depth?: { from: number; to: number }; // depth counter overlay (metres)
	flash?: boolean; // white flash on entry
	dim?: boolean; // blur + darken (behind the logo)
};

const b = (n: number) => n * BAR;

export const SECTIONS: Section[] = [
	// Breakdown: the tease, 4 bars.
	{ clip: "golden", at: 0, dur: b(1), from: 0, caption: { text: "WHAT'S BURIED", sub: "under the beach?" } },
	{ clip: "ring", at: b(1), dur: b(1), from: 0.6, caption: { text: "TIME YOUR TAPS", color: "#7CFF8A" } },
	{ clip: "legendary", at: b(2), dur: b(1), from: 0.9 },
	{ clip: "dive", at: b(3), dur: BEAT, from: 1.0 },
	{ clip: "dive", at: b(3) + BEAT, dur: BEAT, from: 7.5 },
	{ clip: "dive", at: b(3) + 2 * BEAT, dur: BEAT, from: 13.5 },
	{ clip: "dive", at: b(3) + 3 * BEAT, dur: BEAT, from: 19.5, caption: { text: "HOW DEEP?" } },
	// Drop: logo slam, then the montage cut on bars.
	{ clip: "dive", at: DROP, dur: b(1), from: 22, flash: true, dim: true },
	{ clip: "dive", at: DROP + b(1), dur: b(2), from: 0.5, rate: 2.6, depth: { from: 0, to: 993 }, flash: true },
	{ clip: "hatch", at: DROP + b(3), dur: b(1), from: 1.2, rate: 1.4, caption: { text: "HATCH PETS", color: "#FFBE1E" } },
	{ clip: "golden", at: DROP + b(4), dur: b(1), from: 0, caption: { text: "THEY DIG WITH YOU", color: "#78FFE6" } },
	{ clip: "sell", at: DROP + b(5), dur: BEAT * 2, from: 0.9, caption: { text: "SELL", color: "#FFD84A" } },
	{ clip: "perfects", at: DROP + b(5) + BEAT * 2, dur: BEAT * 2, from: 10.4, caption: { text: "UPGRADE", color: "#3CA0FF" } },
	{ clip: "core", at: DROP + b(6), dur: b(1), from: 1.0, caption: { text: "REACH THE CORE", color: "#FF8A3C" }, flash: true },
	{ clip: "relic", at: DROP + b(7), dur: b(1.5), from: 2.6, caption: { text: "FIND A RELIC", color: "#78FFE6", top: true } },
];

export const END_AT = DROP + b(8.5); // end card
export const LOGO_AT = DROP; // logo slam on the drop
export const LOGO_DUR = BAR;
