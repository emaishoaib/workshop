---
name: video-archive
description: Process a video (YouTube URL or local file) into a self-contained folder under video-analysis/ containing a dense, uniform capture of frames across the entire video plus one markdown file with the complete analysis (frames embedded inline at the point they're discussed), and keep a running index.md of every video archived so far. Use when the user gives a video URL/path and asks to process, archive, or "watch" it, or invokes this skill by name.
---

# Video Archive

Turn a video into one durable, self-contained folder: a dense, uniform set
of frame images covering the *entire* video, plus a single markdown
analysis that embeds the relevant ones inline — so a future conversation
with just that folder can answer visual follow-up questions using actual
frames from the video, without re-touching the video itself.

Frame capture is uniform across the whole timeline at a fixed rate,
**independent of whatever sections/topics the video breaks into**. Never
narrow capture down to "one representative frame per topic" — that turns
every extraction into a guess about which single moment matters, and a bad
guess is silently unrecoverable. Capture broadly first; sections only
decide what gets *written about* in the analysis, never what gets
*captured*.

Relies on the `claude-video-vision` MCP tools (`video_analyze`, `video_watch`,
`video_detail`, `video_configure`). If these aren't available, say so rather
than guessing at a substitute.

## Directory layout

```
video-analysis/
  index.md
  <slugified-title>--<video-id-or-hash>/
    analysis.md
    frame_00-00-01.jpg
    frame_00-00-02.jpg
    frame_00-00-03.jpg
    ... (one per second of video, by default)
```

Flat — no category/grouping layer under `video-analysis/`. Every processed
video gets exactly one subdirectory, named `<slugified-title>--<video-id-or-hash>`:

- YouTube: slug of the title plus the 11-character video ID from the URL
  (the part that's actually unique — titles collide, IDs don't).
- Local file: slug of the filename plus the first 8 characters of a sha1
  of the file (filenames get reused and files get moved).

`video-analysis/` itself lives next to wherever this project already keeps
notes (look for an existing notes-like directory first); with no such
convention, default to `video-analysis/` at the project root. Inferred,
never asked.

Frame filenames are just `frame_HH-MM-SS.<ext>` — no separate sequence
number, since the timestamp alone sorts correctly and is what you'd
actually search by later.

## index.md

`video-analysis/index.md` is the browsable overview of everything archived
— since there's no category structure to browse by, this is what makes the
flat layout navigable. Every time a new video folder is created, add a row;
every time an existing one is reprocessed, update its row in place rather
than duplicating it.

One row per video, minimal — nothing that's already in that video's own
`analysis.md` (skip the full URL, skip anything requiring `analysis.md` to
answer). Per row:

- **Video** — a link to the folder's `analysis.md`, labeled with the title.
- **Date** — the video's own publish/upload date if the source provides one
  (YouTube does); otherwise the date it was archived. Say which one it is
  if it's not obvious from context.
- **Summary** — one to three lines on what the video is actually about,
  written for someone scanning the index to decide whether to open it.

Create `index.md` with a header row the first time it doesn't exist yet.
Don't invent columns beyond this without a reason — the point is a fast
scan, not a second copy of the analysis.

## Process

1. **Check for a duplicate before doing any real work.** Work out the
   video's unique identifier immediately — the 11-character YouTube video
   ID from the URL, or a sha1 of the local file — before calling any
   processing tool. Search `video-analysis/*` for a folder already ending
   in `--<that-id-or-hash>`.
   - **Found:** stop. Tell the user this video was already archived, give
     them the existing path, and ask whether they want to reprocess
     (overwrite) or leave it as-is. Don't burn a `video_analyze`/`video_watch`
     call — those cost real processing time and, on cloud backends, real
     API usage — until they say reprocess. If they do, you'll update that
     video's `index.md` row in place rather than adding a new one.
   - **Not found:** continue to step 2.

2. **Understand the video.** Call `video_analyze` for structure (scene
   changes, silence, rough transcript), then `video_watch` for a
   timestamped transcript. This pass is about understanding content and
   getting the duration/publish date — it doesn't need to extract many
   frames itself, dense capture happens separately in step 4.

3. **Identify sections.** From the transcript, break the video into
   whatever structure it actually has (steps, topics, chapters, key
   moments) with an approximate timestamp for each. Let the content decide
   the count and the labels — don't force a fixed shape. This is for
   organizing `analysis.md` later — it has no effect on which frames get
   captured.

4. **Capture frames for the entire video at 1 frame per second**,
   regardless of section boundaries. See "Frame extraction mechanics"
   below for exactly how — the short version: turn on session caching,
   extract in one or more segments covering the full duration, then pull
   the cached files off disk with a plain filesystem copy rather than
   routing them through the conversation.

5. **Work out the per-video folder name** using the title/ID or
   filename/hash rule above (you already have the ID/hash from step 1 —
   just add the slugified title/filename to it).

6. **Create `video-analysis/<folder-name>/`** and move the captured
   frames into it.

7. **Write `analysis.md`** inside that folder: title, source URL/path,
   channel/source and publish date if known, then the complete analysis
   organized by the sections from step 3 — each with its timestamp, each
   embedding the frame(s) nearest that timestamp inline via a relative
   markdown image link (`![](./frame_00-04-12.jpg)`) right where that
   section is discussed. One self-contained file. Because capture was
   dense and uniform, there's always a real frame within a second of any
   moment worth illustrating — no more guessing which single moment to
   extract.

8. **Add or update this video's row in `video-analysis/index.md`** per the
   format above.

9. **Report back**: the full path created, how many frames were captured,
   and confirmation the index was updated.

## Frame extraction mechanics

This is the part that's easy to get wrong, so follow it exactly:

- `video_detail`'s extraction (`segments` param) is capped at **1000
  frames per segment** — a hardcoded limit inside the tool, unrelated to
  the plugin's `max_frames` config setting (that setting only affects
  `video_watch`'s own internal auto-fps behavior, not `video_detail`).
  At 1fps, a segment can cover just under 16m40s. For anything longer,
  split the full duration into multiple segments of ≤1000s each, all
  passed in the *same* `video_detail` call's `segments` array — no need
  for multiple separate tool calls.
- Extracted frames only persist on disk if session caching is on. Check
  the current config first by calling `video_configure` with no
  arguments — it returns the full current config without changing
  anything. Note the current `enable_index` value so you can restore it
  later. If it's `false`, call `video_configure` with `enable_index: true`
  before extracting.
- Frame resolution: set `resolution: 1920` on each segment for 1080p
  output. The tool's `resolution` field is the frame **width** in pixels
  (it maintains aspect ratio from there), not a direct "1080" designation
  — for standard 16:9 video, a width of 1920 is what actually yields 1080
  vertical pixels. Don't pass `1080` itself as the resolution value; that
  would give a *smaller* frame (1080 wide, ~608 tall), the opposite of
  what's wanted. The tool's max is 2048, so 1920 fits with room to spare.
  Leaving `resolution` unset defaults to 512, far below what's wanted here.
- Call `video_detail` with your full-duration segment(s) at `fps: 1`, and
  set `view_sample: 1` (not `view` with a real timestamp, not leaving
  `view`/`view_sample` unset) — this forces the tool to actually write
  every extracted frame to its session cache, while sending back only one
  image in the response instead of flooding this conversation with
  hundreds of frames as tokens.
- The tool's text response includes the session manifest, which names the
  video's hash. The cached frames live at:
  `~/.claude-video-vision/sessions/<hash>/frames/<format>/<resolution>/<HH-MM-SS>.<ext>`
  Use `Bash` to copy every file from that directory into your working
  location, renaming to `frame_<timestamp>.<ext>` (drop nothing — this is
  the actual archive).
- Once copied, restore `enable_index` to whatever value it had before you
  started, via `video_configure` — don't leave a global plugin setting
  changed as a side effect of running this skill.

## Notes

- The plugin's own download/frame cache expiring after some days isn't a
  problem — reprocessing a still-valid URL or local file is transparent,
  it just costs processing time again. A deleted local file or a
  taken-down YouTube video are the only genuinely unrecoverable cases —
  say so plainly if one of those is hit.
- Never invent a timestamp, frame, or caption you didn't actually get from
  a tool call. If a section has nothing visual worth pointing at, leave it
  without an image in `analysis.md` rather than faking one.
- 1 frame/second is the default density — if a video is unusually long
  (multi-hour) and that would mean thousands of files, say so before
  proceeding rather than silently capturing at a different rate.
