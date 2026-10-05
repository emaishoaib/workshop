---
name: video-archive
description: Process a video (YouTube URL or local file) into a self-contained folder containing a dense, uniform capture of frames across the entire video plus one markdown file with the complete analysis (frames embedded inline at the point they're discussed). A YouTube video's folder goes under a category folder inside video-analysis/, confirmed with the user; a local file's folder goes right beside the file, named after it. Use when the user gives a video URL/path and asks to process, archive, or "watch" it, or invokes this skill by name.
---

# Video Archive

Turn a video into one durable, self-contained folder: a dense, uniform set
of frame images covering the *entire* video, plus a single markdown
analysis that embeds the relevant ones inline — so a future conversation
with just that folder can answer visual follow-up questions using actual
frames from the video, without re-touching the video itself.

Frame capture is uniform across the whole timeline, at a rate set by the
video's length, **independent of whatever sections/topics the video breaks into**. Never
narrow capture down to "one representative frame per topic" — that turns
every extraction into a guess about which single moment matters, and a bad
guess is silently unrecoverable. Capture broadly first; sections only
decide what gets *written about* in the analysis, never what gets
*captured*.

Relies on the `claude-video-vision` MCP tools (`video_analyze`,
`video_watch`) for understanding the video, and on `ffmpeg` for capturing
frames. If either isn't available, say so rather than guessing at a
substitute.

## Directory layout

Where the per-video folder goes depends on the source.

**YouTube:** under a category folder inside a shared `video-analysis/`
folder.

```
video-analysis/
  games/
    blood-of-dawnwalker/
      early-game/
        <slugified-title>--<video-id>/
          analysis.md
          frame_00-00-00-000.jpg
          frame_00-00-00-250.jpg
          frame_00-00-00-500.jpg
          ... (rate set by the video's length)
  tech/
    <slugified-title>--<video-id>/
      ...
```

Every video sits inside a category, and categories can nest as deep as
the subject needs. See "Categories" below for how one gets chosen. The
video's own folder is the slug of the title plus the 11-character video
ID from the URL (the part that's actually unique — titles collide, IDs
don't).

**Local file:** beside the video itself, in a folder named with the
video's exact filename minus its extension.

```
<video's directory>/
  My Recording.mov
  My Recording/
    analysis.md
    frame_00-00-00-000.jpg
    frame_00-00-00-250.jpg
    ... (rate set by the video's length)
```

Keep the name exactly as the file has it: same spaces, capitals and
unusual characters. Don't slugify it and don't add a hash. The folder
sits next to the file it came from, so the pairing is obvious on sight.
Categories don't apply to local files.

`video-analysis/` itself lives next to wherever this project already keeps
notes (look for an existing notes-like directory first); with no such
convention, default to `video-analysis/` at the project root. Inferred,
never asked.

Frame filenames are just `frame_HH-MM-SS-mmm.jpg`, where `mmm` is
milliseconds. There's no separate sequence number, since the timestamp
alone sorts correctly and is what you'd actually search by later. The
milliseconds are always present, even at 1 frame per second, so every
archive uses the same pattern.

## Categories

The category folders are what make `video-analysis/` browsable, so every
YouTube video goes into one. There is no index file.

The category is always the user's call, never inferred silently. Once you
know what the video is about, list the category folders already under
`video-analysis/` (every level, not just the top) and propose one of:

- **An existing category**, naming its full path, e.g.
  `games/blood-of-dawnwalker/gear/`.
- **A new category**, naming the full path it would have, either at the
  top level or nested under an existing one.

Say in a sentence why it fits. Then wait for the user to confirm or pick
something else before creating any folder. When a new category is
confirmed, create it as part of creating the video's folder.

Category names are short, lowercase and hyphenated, like the rest of the
tree.

## Process

1. **Check for a duplicate before doing any real work.** Do this before
   calling any processing tool.
   - YouTube: take the 11-character video ID from the URL. Search all of
     `video-analysis/`, at every depth, for a folder already ending in
     `--<that-id>`. Videos sit inside category folders, so a top-level
     search misses them.
   - Local file: check whether a folder with the file's name minus its
     extension already exists beside the file.
   - **Found:** stop. Tell the user this video was already archived, give
     them the existing path, and ask whether they want to reprocess
     (overwrite) or leave it as-is. Don't burn a `video_analyze`/`video_watch`
     call — those cost real processing time and, on cloud backends, real
     API usage — until they say reprocess. If they do, overwrite it in its
     existing category folder and skip step 3.
   - **Not found:** continue to step 2.

2. **Understand the video.** Call `video_analyze` for structure (scene
   changes, silence, rough transcript), then `video_watch` for a
   timestamped transcript. This pass is about understanding content and
   getting the duration/publish date — it doesn't need to extract many
   frames itself, dense capture happens separately in step 5.

3. **Agree on a category** (YouTube only). Propose an existing or new
   category per "Categories" above, and wait for the user's confirmation
   before going further.

4. **Identify sections.** From the transcript, break the video into
   whatever structure it actually has (steps, topics, chapters, key
   moments) with an approximate timestamp for each. Let the content decide
   the count and the labels — don't force a fixed shape. This is for
   organizing `analysis.md` later — it has no effect on which frames get
   captured.

5. **Capture frames for the entire video**, regardless of section
   boundaries, at the rate its length calls for. See "Frame extraction
   mechanics" below for exactly how. The short version: pick the rate,
   run ffmpeg once over the whole video, then rename each frame to its
   exact time.

6. **Work out the per-video folder path** using the rules in "Directory
   layout". For YouTube, put the slugified title plus the ID from step 1
   inside the category confirmed in step 3. For a local file, you already
   have the path from step 1.

7. **Create that folder**, and any new category folders above it, then
   move the captured frames into it.

8. **Write `analysis.md`** inside that folder: title, source URL/path,
   channel/source and publish date if known, then the complete analysis
   organized by the sections from step 4 — each with its timestamp, each
   embedding the frame(s) nearest that timestamp inline via a relative
   markdown image link (`![](./frame_00-04-12-250.jpg)`) right where that
   section is discussed. One self-contained file. Because capture was
   dense and uniform, there's always a real frame within a second of any
   moment worth illustrating — no more guessing which single moment to
   extract.

9. **Report back**: the full path created and how many frames were
   captured.

## Frame extraction mechanics

Frames are captured with ffmpeg directly, not through the plugin. The
plugin rounds timestamps down to whole seconds and keeps one frame per
second in its cache. Any higher rate gets silently thrown away there. Use
the plugin only for understanding the video (step 2).

**Pick the rate from the video's length:**

| Video length   | Frame rate   |
|----------------|--------------|
| Under 1 minute | 4 per second |
| 1 to 3 minutes | 2 per second |
| Over 3 minutes | 1 per second |

State the chosen rate and the expected frame count before capturing. If
the user asks for a different rate, use theirs.

**Capture straight into the per-video folder:**

```bash
ffmpeg -hide_banner -loglevel error -i "$VIDEO" -vf "fps=$FPS,scale='min(1920,iw)':-2" -q:v 2 "$OUT/raw_%05d.jpg"
```

- `fps=$FPS` samples evenly across the whole video, starting at 0
  seconds.
- `scale='min(1920,iw)':-2` gives 1080p output for standard 16:9 video
  and never upscales a smaller source. The `-2` keeps the aspect ratio
  and makes the height an even number.
- `-q:v 2` is near-lossless JPEG quality.

There's no frame cap and no need to split the video into segments.
ffmpeg handles any length in one pass.

**Rename each frame to its exact time.** Frame *n* (counting from 0) sits
at *n* ÷ FPS seconds. The names include milliseconds at every rate, so
every archive uses the same pattern:

```bash
cd "$OUT"
n=0
for f in raw_*.jpg; do
  ms=$(( n * 1000 / FPS ))
  name=$(printf 'frame_%02d-%02d-%02d-%03d.jpg' $((ms/3600000)) $((ms/60000%60)) $((ms/1000%60)) $((ms%1000)))
  mv "$f" "$name"
  n=$((n+1))
done
```

**Check the count.** The number of `frame_*.jpg` files should be close to
duration × FPS. If it's far off, say so rather than carrying on.

The plugin's config is never touched. There's no `enable_index` to switch
on and restore, and no cache folder to copy from.

## Notes

- The plugin's own download/frame cache expiring after some days isn't a
  problem — reprocessing a still-valid URL or local file is transparent,
  it just costs processing time again. A deleted local file or a
  taken-down YouTube video are the only genuinely unrecoverable cases —
  say so plainly if one of those is hit.
- Never invent a timestamp, frame, or caption you didn't actually get from
  a tool call. If a section has nothing visual worth pointing at, leave it
  without an image in `analysis.md` rather than faking one.
- The rate comes from the table in "Frame extraction mechanics". If a
  video is unusually long (multi-hour) and even 1 frame per second would
  mean thousands of files, say so before proceeding rather than silently
  capturing at a lower rate.
