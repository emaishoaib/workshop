---
name: video-analyze
description: Analyze a video (YouTube URL or local file) and answer about it in the conversation, without keeping anything on disk. Frames are captured into a temporary folder that is deleted afterwards, and there is no analysis.md or archive folder. Use when the user gives a video URL/path and wants it looked at, watched or analyzed (for example to spot a bug in a screen recording), or invokes this skill by name. Use video-archive instead when they want a lasting folder of frames and a written analysis.
---

# Video Analyze

Look at a video closely enough to answer about it, and keep nothing. The
answer lives in the reply. The frames exist only while you need to look at
them, in a temporary folder outside the user's files, and are deleted when
the analysis is done.

This is the throwaway sibling of `video-archive`. It captures frames the
same way and at the same rates, but never creates an archive folder, never
writes `analysis.md`, and never leaves frames beside the video or anywhere
else.

Relies on `ffmpeg` for frames. For videos with speech, it can also use the
`claude-video-vision` MCP tools (`video_analyze`, `video_watch`) for a
transcript. If a tool it needs isn't available, say so rather than guessing
at a substitute.

## Where frames go

Use a fresh, empty temporary folder that belongs to this conversation: the
session's scratchpad directory when one exists, otherwise one made with
`mktemp -d`. Never write next to the video, into the user's project, or
into a `video-analysis/` folder.

Delete the folder when the analysis is finished. Say in the reply that
nothing was kept.

A YouTube video has to be downloaded before ffmpeg can read it. Download it
into the same temporary folder, so it is deleted along with the frames.

## Frame rate

Pick the rate from the video's length, as `video-archive` does:

| Video length   | Frame rate   |
|----------------|--------------|
| Under 1 minute | 4 per second |
| 1 to 3 minutes | 2 per second |
| Over 3 minutes | 1 per second |

The user can override it. Use any rate they name. When they say something
like "as many frames as you need", choose the rate yourself, and go as high
as the question calls for. Animations, flickers and other short glitches
usually need 30 frames per second or more around the moment they happen.

## Process

1. **Find the file.** Check the path exists before anything else. macOS
   screen recordings put a narrow no-break space before "AM" or "PM" in
   their names, so a pasted path often fails. Match it with a wildcard
   instead, for example `ls ~/Desktop/Screen\ Recording\ 2026-10-28\ at\ 4.10.15*.mov`.

2. **Read the basics.** Get the duration, size and native frame rate:

   ```bash
   ffprobe -v error -show_entries format=duration:stream=width,height,r_frame_rate -of compact "$VIDEO"
   ```

3. **Understand the content** when the video has speech. Call
   `video_analyze` for its structure and `video_watch` for a timestamped
   transcript. Skip this for silent videos such as screen recordings.

4. **Scan the whole video at once** with a contact sheet: one image tiling
   evenly spaced frames, at the rate from "Frame rate".

   ```bash
   ffmpeg -v error -y -i "$VIDEO" -vf "fps=$FPS,scale=216:-1,tile=8x5" -frames:v 1 "$TMP/sheet.png"
   ```

   Size the tile grid so it holds every frame, or make several sheets for
   a longer video. Look at the sheets to find the moments that matter.

5. **Zoom in on those moments.** Pull a denser run of frames around each
   one, either as another contact sheet or as single frames:

   ```bash
   ffmpeg -v error -y -ss $START -t $LENGTH -i "$VIDEO" -vf "fps=30,scale=216:-1,tile=7x3" -frames:v 1 "$TMP/closeup.png"
   ffmpeg -v error -y -ss $AT -i "$VIDEO" -frames:v 1 "$TMP/frame.png"
   ```

   Repeat at a higher rate or a larger size until the question can be
   answered from what you actually saw.

6. **Answer in the reply.** Describe what happens, citing the timestamps
   and frames it is based on. For a bug, say what you expected, what the
   frames show instead, and when.

7. **Clean up.** Delete the temporary folder, including any downloaded
   video.

## Notes

- Never invent a timestamp, frame or detail you didn't actually see in a
  frame or get from a tool call.
- Each frame in a contact sheet sits at its position ÷ FPS seconds from
  the start of whatever range the sheet covers. Use that to turn a tile
  back into a timestamp.
- If the user later wants to keep the frames or a written analysis, that
  is `video-archive`'s job. Suggest it rather than writing files here.
