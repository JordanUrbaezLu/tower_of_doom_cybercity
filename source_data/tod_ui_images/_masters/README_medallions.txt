1024x1024 generator masters (docs/100, 2026-09-04). The SHIPPED files in _images/ are these downscaled to 512 with:
  ffmpeg -i in.png -vf format=gbrap,premultiply=inplace=1,scale=512:512:flags=lanczos,unpremultiply=inplace=1,format=rgba -pix_fmt rgba out.png
(premultiplied Lanczos: no dark fringe on the disc edge). Re-run from here if the ship size ever changes.
