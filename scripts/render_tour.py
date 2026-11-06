"""Render the guided tour as an MP4 (scripts/render_tour.py [out.mp4]).

Runs the app under Godot's movie-writer mode (every frame rendered at a fixed 30 fps with the narration and the
ambience mixed in, independent of real time) with the app's --movie entry point, which starts the tour at chapter 1
and quits at its end; then encodes the MJPEG AVI to H.264/AAC with the ffmpeg bundled in imageio-ffmpeg.
Output defaults to build/tour.mp4 (git-ignored). Needs a window (not --headless); takes a while.
"""
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.join(ROOT, "tools", "godot", "Godot_v4.7.2-stable_win64_console.exe")
FPS = 30


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "tour.mp4")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    avi = out[:-4] + "_raw.avi"
    t0 = time.time()
    cmd = [GODOT, "--path", os.path.join(ROOT, "godot"), "--write-movie", avi, "--fixed-fps", str(FPS), "--", "--movie"]
    print("rendering:", " ".join(cmd), flush=True)
    r = subprocess.run(cmd, capture_output=True, text=True)
    print("godot exit %d after %.0f s; avi %.0f MB" % (r.returncode, time.time() - t0, os.path.getsize(avi) / 1e6 if os.path.exists(avi) else 0), flush=True)
    if not os.path.exists(avi):
        print(r.stdout[-2000:], r.stderr[-2000:])
        sys.exit(1)
    import imageio_ffmpeg
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    t1 = time.time()
    enc = [ff, "-y", "-i", avi, "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p",
           "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", out]
    r2 = subprocess.run(enc, capture_output=True, text=True)
    print("ffmpeg exit %d after %.0f s" % (r2.returncode, time.time() - t1), flush=True)
    if r2.returncode != 0:
        print(r2.stderr[-3000:])
        sys.exit(1)
    os.remove(avi)
    print("wrote %s (%.0f MB)" % (out, os.path.getsize(out) / 1e6))


if __name__ == "__main__":
    main()
