# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :darth,
  ecto_repos: [Darth.Repo],
  asset_static_base_path: ["priv", "static", "media"],
  uploads_base_path: ["priv", "static", "uploads"],
  mv_asset_preview_download_path: ["priv", "static", "preview_download"]

config :darth, Darth.Repo,
  migration_primary_key: [name: :id, type: :uuid],
  migration_foreign_key: [column: :id, type: :uuid]

# Configures the endpoint
config :darth, DarthWeb.Endpoint,
  url: [host: "localhost", port: "45020"],
  render_errors: [view: DarthWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Darth.PubSub,
  live_view: [signing_salt: "iMX9wAB3"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :darth, Darth.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, false

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.15.6",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# configure Tailwind
config :tailwind,
  version: "3.1.8",
  default: [
    args: ~w(
    --config=tailwind.config.js
    --input=css/app.css
    --output=../priv/static/assets/app.css
  ),
    cd: Path.expand("../assets", __DIR__)
  ]

# App configurations
config :darth,
  default_mv_node: "https://dashboard.mediaverse.atc.gr",
  # This is the extension that needs to be appended at the end of mv_node to make mv_node act as an API Endpoint.
  mv_api_endpoint: "dam",
  upload_file_size: 80_000_000,
  upload_subtitle_file_size: 80_000,
  default_project_scene_duration: "12",
  mv_asset_index_url: "/assets/paginated",
  mv_project_index_url: "/project/userList/all/paginated",
  editor_url: "/editor/edit"

config :darth,
  reset_password_validity_in_days: 1,
  confirm_validity_in_days: 7,
  change_email_validity_in_days: 7,
  session_validity_in_days: 60,
  max_age_in_seconds: 60 * 60 * 24 * 60,
  remember_me_cookie: "_darth_web_user_remember_me",
  user_password_min_len: 10,
  mv_user_password_min_len: 6,
  user_password_max_len: 100

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason
config :phoenix_swagger, json_library: Jason

config :ua_inspector,
  database_path: Path.join("/tmp", "darth_ua_inspector")

config :mime, :types, %{
  "text/plain" => ["srt"],
  "application/x-subrip" => ["srt"],
  "application/octet-stream" => ["srt"],
  "video/3gpp" => ["3gp, 3gpp"],
  "video/3gpp2" => ["3g2, 3gpp2"],
  "video/iso.segment" => ["m4s"],
  "video/mj2" => ["mj2, mjp2"],
  "video/mp4" => ["mp4, mpg4, m4v"],
  "video/mpeg" => ["mpeg, mpg, mpe, m1v, m2v"],
  "video/ogg" => ["ogv"],
  "video/quicktime" => ["mov, qt"],
  "video/vnd.dece.hd" => ["uvh, uvvh"],
  "video/vnd.dece.mobile" => ["uvm, uvvm"],
  "video/vnd.dece.mp4" => ["uvu, uvvu"],
  "video/vnd.dece.sd" => ["uvs, uvvs"],
  "video/vnd.dece.pd" => ["uvp, uvvp"],
  "video/vnd.dece.video" => ["uvv, uvvv"],
  "video/vnd.dvb.file" => ["dvb"],
  "video/vnd.fvt" => ["fvt"],
  "video/vnd.mpegurl" => ["mxu, m4u"],
  "video/vnd.ms-playready.media.pyv" => ["pyv"],
  "video/vnd.nokia.interleaved-multimedia" => ["nim"],
  "video/vnd.radgamettools.bink" => ["bik, bk2"],
  "video/vnd.radgamettools.smacker" => ["smk"],
  "video/vnd.sealed.mpeg1" => ["smpg, s11"],
  "video/vnd.sealed.mpeg4" => ["s14"],
  "video/vnd.sealed.swf" => ["sswf, ssw"],
  "video/vnd.sealedmedia.softseal.mov" => ["smov, smo, s1q"],
  "video/vnd.youtube.yt" => ["yt"],
  "video/vnd.vivo" => ["viv"],
  "video/webm" => ["webm"],
  "video/x-annodex" => ["axv"],
  "video/x-flv" => ["flv"],
  "video/x-javafx" => ["fxm"],
  "video/x-matroska" => ["mkv"],
  "video/x-matroska-3d" => ["mk3d"],
  "video/x-ms-asf" => ["asx"],
  "video/x-ms-wm" => ["wm"],
  "video/x-ms-wmv" => ["wmv"],
  "video/x-ms-wmx" => ["wmx"],
  "video/x-ms-wvx" => ["wvx"],
  "video/x-msvideo" => ["avi"],
  "video/x-sgi-movie" => ["movie"],
  "audio/32kadpcm" => ["726"],
  "audio/aac" => ["adts, aac, ass"],
  "audio/ac3" => ["ac3"],
  "audio/AMR" => ["amr"],
  "audio/AMR-WB" => ["awb"],
  "audio/asc" => ["acn"],
  "audio/ATRAC-ADVANCED-LOSSLESS" => ["aal"],
  "audio/ATRAC-X" => ["atx"],
  "audio/ATRAC3" => ["at3, aa3, omg"],
  "audio/basic" => ["au, snd"],
  "audio/dls" => ["dls"],
  "audio/EVRC" => ["evc"],
  "audio/EVRCB" => ["evb"],
  "audio/EVRCNW" => ["enw"],
  "audio/EVRCWB" => ["evw"],
  "audio/iLBC" => ["lbc"],
  "audio/L16" => ["l16"],
  "audio/mhas" => ["mhas"],
  "audio/mobile-xmf" => ["mxmf"],
  "audio/mp4" => ["m4a"],
  "audio/mpeg" => ["mp3, mpga, mp1, mp2"],
  "audio/ogg" => ["oga, ogg, opus, spx"],
  "audio/prs.sid" => ["sid, psid"],
  "audio/QCELP" => ["qcp"],
  "audio/SMV" => ["smv"],
  "audio/sofa" => ["sofa"],
  "audio/usac" => ["loas, xhe"],
  "audio/vnd.audiokoz" => ["koz"],
  "audio/vnd.dece.audio" => ["uva, uvva"],
  "audio/vnd.digital-winds" => ["eol"],
  "audio/vnd.dolby.mlp" => ["mlp"],
  "audio/vnd.dts" => ["dts"],
  "audio/vnd.dts.hd" => ["dtshd"],
  "audio/vnd.everad.plj" => ["plj"],
  "audio/vnd.lucent.voice" => ["lvp"],
  "audio/vnd.ms-playready.media.pya" => ["pya"],
  "audio/vnd.nortel.vbk" => ["vbk"],
  "audio/vnd.nuera.ecelp4800" => ["ecelp4800"],
  "audio/vnd.nuera.ecelp7470" => ["ecelp7470"],
  "audio/vnd.nuera.ecelp9600" => ["ecelp9600"],
  "audio/vnd.presonus.multitrack" => ["multitrack"],
  "audio/vnd.rip" => ["rip"],
  "audio/vnd.sealedmedia.softseal.mpeg" => ["smp3, smp, s1m"],
  "audio/midi" => ["mid, midi, kar"],
  "audio/x-aiff" => ["aif, aiff, aifc"],
  "audio/x-annodex" => ["axa"],
  "audio/x-flac" => ["flac"],
  "audio/x-matroska" => ["mka"],
  "audio/x-mod" => ["mod, ult, uni, m15, mtm, 669"],
  "audio/x-ms-wax" => ["wax"],
  "audio/x-ms-wma" => ["wma"],
  "audio/x-pn-realaudio" => ["ram, rm"],
  "audio/x-realaudio" => ["ra"],
  "audio/x-s3m" => ["s3m"],
  "audio/x-stm" => ["stm"],
  "audio/x-wav" => ["wav"],
  "image/aces" => ["exr"],
  "image/avci" => ["avci"],
  "image/avcs" => ["avcs"],
  "image/avif" => ["avif, hif"],
  "image/bmp" => ["bmp, dib"],
  "image/cgm" => ["cgm"],
  "image/dicom-rle" => ["drle"],
  "image/emf" => ["emf"],
  "image/fits" => ["fits, fit, fts"],
  "image/heic" => ["heic"],
  "image/heic-sequence" => ["heics"],
  "image/heif" => ["heif"],
  "image/heif-sequence" => ["heifs"],
  "image/hej2k" => ["hej2"],
  "image/hsj2" => ["hsj2"],
  "image/gif" => ["gif"],
  "image/ief" => ["ief"],
  "image/jls" => ["jls"],
  "image/jp2" => ["jp2, jpg2"],
  "image/jph" => ["jph"],
  "image/jphc" => ["jhc"],
  "image/jpeg" => ["jpg, jpeg, jpe, jfif"],
  "image/jpm" => ["jpm, jpgm"],
  "image/jpx" => ["jpx, jpf"],
  "image/jxl" => ["jxl"],
  "image/jxr" => ["jxr"],
  "image/jxrA" => ["jxra"],
  "image/jxrS" => ["jxrs"],
  "image/jxs" => ["jxs"],
  "image/jxsc" => ["jxsc"],
  "image/jxsi" => ["jxsi"],
  "image/jxss" => ["jxss"],
  "image/ktx" => ["ktx"],
  "image/ktx2" => ["ktx2"],
  "image/png" => ["png"],
  "image/prs.btif" => ["btif, btf"],
  "image/prs.pti" => ["pti"],
  "image/svg+xml" => ["svg, svgz"],
  "image/t38" => ["t38"],
  "image/tiff" => ["tiff, tif"],
  "image/tiff-fx" => ["tfx"],
  "image/vnd.adobe.photoshop" => ["psd"],
  "image/vnd.airzip.accelerator.azv" => ["azv"],
  "image/vnd.dece.graphic" => ["uvi, uvvi, uvg, uvvg"],
  "image/vnd.djvu" => ["djvu, djv"],
  "image/vnd.dwg" => ["dwg"],
  "image/vnd.dxf" => ["dxf"],
  "image/vnd.fastbidsheet" => ["fbs"],
  "image/vnd.fpx" => ["fpx"],
  "image/vnd.fst" => ["fst"],
  "image/vnd.fujixerox.edmics-mmr" => ["mmr"],
  "image/vnd.fujixerox.edmics-rlc" => ["rlc"],
  "image/vnd.globalgraphics.pgb" => ["pgb"],
  "image/vnd.microsoft.icon" => ["ico"],
  "image/vnd.mozilla.apng" => ["apng"],
  "image/vnd.ms-modi" => ["mdi"],
  "image/vnd.pco.b16" => ["b16"],
  "image/vnd.radiance" => ["hdr, rgbe, xyze"],
  "image/vnd.sealed.png" => ["spng, spn, s1n"],
  "image/vnd.sealedmedia.softseal.gif" => ["sgif, sgi, s1g"],
  "image/vnd.sealedmedia.softseal.jpg" => ["sjpg, sjp, s1j"],
  "image/vnd.tencent.tap" => ["tap"],
  "image/vnd.valve.source.texture" => ["vtf"],
  "image/vnd.wap.wbmp" => ["wbmp"],
  "image/vnd.xiff" => ["xif"],
  "image/vnd.zbrush.pcx" => ["pcx"],
  "image/wmf" => ["wmf"],
  "image/webp" => ["webp"],
  "image/x-cmu-raster" => ["ras"],
  "image/x-portable-anymap" => ["pnm"],
  "image/x-portable-bitmap" => ["pbm"],
  "image/x-portable-graymap" => ["pgm"],
  "image/x-portable-pixmap" => ["ppm"],
  "image/x-rgb" => ["rgb"],
  "image/x-targa" => ["tga"],
  "image/x-xbitmap" => ["xbm"],
  "image/x-xpixmap" => ["xpm"],
  "image/x-xwindowdump" => ["xwd"]
}

config :darth, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [
      router: DarthWeb.Router,
      endpoint: DarthWeb.Endpoint
    ]
  }

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
