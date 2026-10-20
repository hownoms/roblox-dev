import React from "react";
import {
	AbsoluteFill,
	Audio,
	Img,
	interpolate,
	OffthreadVideo,
	Sequence,
	spring,
	staticFile,
	useCurrentFrame,
	useVideoConfig,
	Easing,
} from "remotion";
import { loadFont } from "@remotion/google-fonts/Fredoka";
import { BEAT, DURATION, END_AT, f, LOGO_AT, LOGO_DUR, SECTIONS, Section } from "./timing";

const { fontFamily } = loadFont("normal", { weights: ["600", "700"] });

export type Layout = "wide" | "tall";

const INK = "#1B1430";
const SAND = "#FFD84A";

// Chunky game-style text: white/colour fill, thick ink outline, hard drop shadow.
const outlined = (size: number, color = "#fff"): React.CSSProperties => ({
	fontFamily,
	fontWeight: 700,
	fontSize: size,
	color,
	lineHeight: 0.95,
	letterSpacing: size * 0.01,
	WebkitTextStroke: `${Math.round(size * 0.12)}px ${INK}`,
	paintOrder: "stroke fill",
	textShadow: `0 ${Math.round(size * 0.09)}px 0 ${INK}`,
	textAlign: "center",
	whiteSpace: "pre",
});

// One gameplay shot: punch-in zoom on the cut, optional speed-up.
const Shot: React.FC<{ s: Section; layout: Layout }> = ({ s, layout }) => {
	const frame = useCurrentFrame();
	const punch = interpolate(frame, [0, 10], [1.07, 1], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
	const drift = interpolate(frame, [0, f(s.dur)], [1, 1.035]);
	const video = (
		<OffthreadVideo
			src={staticFile(`clips/${s.clip}.mp4`)}
			startFrom={f(s.from ?? 0)}
			playbackRate={s.rate ?? 1}
			muted
			style={{ width: "100%", height: "100%", objectFit: "cover" }}
		/>
	);
	if (layout === "wide") {
		return (
			<AbsoluteFill style={{ transform: `scale(${punch * drift})`, filter: s.dim ? "blur(10px) brightness(0.55)" : undefined }}>
				{video}
			</AbsoluteFill>
		);
	}
	// Tall: blurred fill behind, the 16:9 shot zoomed to 1.6x width in the middle band.
	return (
		<AbsoluteFill>
			<AbsoluteFill style={{ filter: "blur(36px) brightness(0.55) saturate(1.3)", transform: "scale(1.25)" }}>
				<OffthreadVideo
					src={staticFile(`clips/${s.clip}.mp4`)}
					startFrom={f(s.from ?? 0)}
					playbackRate={s.rate ?? 1}
					muted
					style={{ width: "100%", height: "100%", objectFit: "cover" }}
				/>
			</AbsoluteFill>
			<div
				style={{
					position: "absolute",
					left: "50%",
					top: 520,
					width: 1728,
					height: 972,
					marginLeft: -864,
					transform: `scale(${punch * drift})`,
					filter: s.dim ? "blur(10px) brightness(0.55)" : undefined,
					borderRadius: 0,
					overflow: "hidden",
					boxShadow: "0 30px 80px rgba(0,0,0,0.5)",
				}}
			>
				{video}
			</div>
		</AbsoluteFill>
	);
};

const CaptionView: React.FC<{ text: string; color?: string; sub?: string; top?: boolean; layout: Layout }> = ({ text, color, sub, top, layout }) => {
	const frame = useCurrentFrame();
	const { fps } = useVideoConfig();
	const pop = spring({ frame, fps, config: { damping: 11, stiffness: 180, mass: 0.6 } });
	const scale = interpolate(pop, [0, 1], [1.6, 1]);
	const rot = interpolate(pop, [0, 1], [-6, -2]);
	const subIn = spring({ frame: frame - Math.round(BEAT * fps), fps, config: { damping: 14 } });
	const size = layout === "wide" ? 150 : 140;
	return (
		<AbsoluteFill
			style={{
				justifyContent: layout === "wide" && !top ? "flex-end" : "flex-start",
				alignItems: "center",
				paddingBottom: layout === "wide" && !top ? 150 : 0,
				paddingTop: layout === "wide" ? (top ? 40 : 0) : 200,
			}}
		>
			<div style={{ transform: `scale(${scale}) rotate(${rot}deg)`, opacity: Math.min(1, pop * 3) }}>
				<div style={outlined(size, color ?? "#fff")}>{text}</div>
			</div>
			{sub ? (
				<div style={{ marginTop: 18, transform: `translateY(${(1 - subIn) * 40}px)`, opacity: subIn }}>
					<div style={outlined(size * 0.55, SAND)}>{sub}</div>
				</div>
			) : null}
		</AbsoluteFill>
	);
};

const Flash: React.FC = () => {
	const frame = useCurrentFrame();
	const o = interpolate(frame, [0, 10], [0.9, 0], { extrapolateRight: "clamp" });
	return <AbsoluteFill style={{ background: "white", opacity: o }} />;
};

const Logo: React.FC<{ layout: Layout; settle?: boolean }> = ({ layout, settle }) => {
	const frame = useCurrentFrame();
	const { fps } = useVideoConfig();
	const s = spring({ frame, fps, config: { damping: 9, stiffness: 160, mass: 0.7 } });
	const scale = settle ? interpolate(s, [0, 1], [0.6, 1]) : interpolate(s, [0, 1], [2.6, 1]);
	const shake = settle ? 0 : interpolate(frame, [0, 4, 8, 12, 16], [0, 14, -10, 6, 0], { extrapolateRight: "clamp" });
	const top = layout === "wide" ? 140 : 52;
	const big = layout === "wide" ? 250 : 210;
	return (
		<div
			style={{
				transform: `translate(${shake}px, ${-shake * 0.6}px) scale(${scale}) rotate(-3deg)`,
				display: "flex",
				flexDirection: "column",
				alignItems: "center",
				filter: "drop-shadow(0 18px 0 rgba(27,20,48,0.55))",
			}}
		>
			<div style={outlined(big * 0.42, "#fff")}>DIG TO THE</div>
			<div style={{ position: "relative", marginTop: -top * 0.05 }}>
				<div style={outlined(big, SAND)}>CORE!</div>
				<div
					style={{
						...outlined(big, "transparent"),
						position: "absolute",
						inset: 0,
						WebkitTextStroke: "0px transparent",
						textShadow: "none",
						background: "linear-gradient(180deg, #FFF6B8 0%, #FFD84A 45%, #FF9A1C 100%)",
						WebkitBackgroundClip: "text",
						backgroundClip: "text",
					}}
				>
					CORE!
				</div>
			</div>
		</div>
	);
};

const DepthCounter: React.FC<{ from: number; to: number; frames: number; layout: Layout }> = ({ from, to, frames, layout }) => {
	const frame = useCurrentFrame();
	const v = Math.round(interpolate(frame, [0, frames * 0.92], [from, to], { extrapolateRight: "clamp", easing: Easing.in(Easing.quad) }));
	const pulse = 1 + 0.04 * Math.sin(frame / 3);
	return (
		<AbsoluteFill style={{ justifyContent: layout === "wide" ? "flex-end" : "flex-start", alignItems: "center", paddingBottom: 120, paddingTop: layout === "wide" ? 0 : 230 }}>
			<div style={{ transform: `scale(${pulse})` }}>
				<div style={outlined(layout === "wide" ? 170 : 160, "#fff")}>{`▼ ${v}m`}</div>
			</div>
		</AbsoluteFill>
	);
};

const EndCard: React.FC<{ layout: Layout }> = ({ layout }) => {
	const frame = useCurrentFrame();
	const { fps } = useVideoConfig();
	const fadeIn = interpolate(frame, [0, 12], [0, 1], { extrapolateRight: "clamp" });
	const cta = spring({ frame: frame - 18, fps, config: { damping: 12 } });
	const icon = spring({ frame: frame - 8, fps, config: { damping: 12 } });
	const out = interpolate(frame, [f(DURATION - END_AT) - 40, f(DURATION - END_AT)], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
	return (
		<AbsoluteFill style={{ opacity: out }}>
			<AbsoluteFill style={{ opacity: fadeIn }}>
				<AbsoluteFill style={{ filter: "blur(18px) brightness(0.6) saturate(1.2)", transform: "scale(1.1)" }}>
					<OffthreadVideo src={staticFile("clips/boardwalk.mp4")} startFrom={f(2)} muted style={{ width: "100%", height: "100%", objectFit: "cover" }} />
				</AbsoluteFill>
				<AbsoluteFill style={{ background: "radial-gradient(ellipse at center, rgba(255,190,60,0.25) 0%, rgba(27,20,48,0.55) 75%)" }} />
			</AbsoluteFill>
			<AbsoluteFill style={{ justifyContent: "center", alignItems: "center", gap: layout === "wide" ? 30 : 60, flexDirection: "column" }}>
				<Img
					src={staticFile("icon.png")}
					style={{
						width: layout === "wide" ? 220 : 300,
						borderRadius: 48,
						border: `10px solid ${INK}`,
						transform: `scale(${icon}) rotate(${(1 - icon) * -20}deg)`,
						boxShadow: "0 16px 0 rgba(27,20,48,0.6)",
					}}
				/>
				<Logo layout={layout} settle />
				<div style={{ transform: `scale(${cta})`, background: "#36D46A", border: `8px solid ${INK}`, borderRadius: 40, padding: "14px 46px", boxShadow: `0 12px 0 ${INK}` }}>
					<div style={{ ...outlined(layout === "wide" ? 80 : 84, "#fff"), WebkitTextStroke: `7px ${INK}`, textShadow: "none" }}>PLAY FREE ON ROBLOX</div>
				</div>
			</AbsoluteFill>
		</AbsoluteFill>
	);
};

export const Film: React.FC<{ layout: Layout }> = ({ layout }) => {
	return (
		<AbsoluteFill style={{ background: INK }}>
			<Audio src={staticFile("music.mp3")} volume={(fr) => interpolate(fr, [f(DURATION) - 30, f(DURATION)], [1, 0], { extrapolateLeft: "clamp" })} />
			{SECTIONS.map((s, i) => (
				<Sequence key={`shot${i}`} from={f(s.at)} durationInFrames={f(s.dur)}>
					<Shot s={s} layout={layout} />
				</Sequence>
			))}
			{/* subtle vignette over all gameplay */}
			<AbsoluteFill style={{ background: "radial-gradient(ellipse at center, rgba(0,0,0,0) 55%, rgba(0,0,0,0.35) 100%)", pointerEvents: "none" }} />
			{SECTIONS.map((s, i) =>
				s.caption ? (
					<Sequence key={`cap${i}`} from={f(s.at)} durationInFrames={f(s.dur)}>
						<CaptionView {...s.caption} layout={layout} />
					</Sequence>
				) : null,
			)}
			{SECTIONS.map((s, i) =>
				s.depth ? (
					<Sequence key={`depth${i}`} from={f(s.at)} durationInFrames={f(s.dur)}>
						<DepthCounter from={s.depth.from} to={s.depth.to} frames={f(s.dur)} layout={layout} />
					</Sequence>
				) : null,
			)}
			<Sequence from={f(LOGO_AT)} durationInFrames={f(LOGO_DUR)}>
				<AbsoluteFill style={{ background: "radial-gradient(ellipse at center, rgba(27,20,48,0.55) 0%, rgba(27,20,48,0.75) 100%)" }} />
				<AbsoluteFill style={{ justifyContent: "center", alignItems: "center", paddingBottom: layout === "wide" ? 0 : 300 }}>
					<Logo layout={layout} />
				</AbsoluteFill>
			</Sequence>
			{SECTIONS.map((s, i) =>
				s.flash ? (
					<Sequence key={`flash${i}`} from={f(s.at)} durationInFrames={12}>
						<Flash />
					</Sequence>
				) : null,
			)}
			<Sequence from={f(END_AT)} durationInFrames={f(DURATION - END_AT)}>
				<EndCard layout={layout} />
			</Sequence>
		</AbsoluteFill>
	);
};
