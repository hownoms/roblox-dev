import React from "react";
import { Composition } from "remotion";
import { Film } from "./Film";
import { DURATION, FPS } from "./timing";

export const Root: React.FC = () => (
	<>
		<Composition id="Trailer" component={Film} defaultProps={{ layout: "wide" as const }} durationInFrames={DURATION * FPS} fps={FPS} width={1920} height={1080} />
		<Composition id="Vertical" component={Film} defaultProps={{ layout: "tall" as const }} durationInFrames={DURATION * FPS} fps={FPS} width={1080} height={1920} />
	</>
);
