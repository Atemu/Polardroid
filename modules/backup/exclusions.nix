[
  "data/ru.meefik.linuxdeploy/"
  "data/*/app_tmpdir/mozilla-temp-*"
  "**/cache/"
  "data/com.google.android.apps.docs/"
  "data/com.spotify.music/files/spotifycache/"
  "data/com.termux.nix/files/"
  "data/com.termux/files/"
  "**/org.fdroid.fdroid/files/*.apk" # /data/data/... as well as /data/media/0/Android/...
  "media/0/Android/data/com.aurora.store/files/Downloads/"
  "data/air.de.fahren_lernen.app/de.fahren-lernen.app/Local Store/"
  "media/0/Android/data/app.organicmaps*/files/*/*.mwm" # Replacable map tiles
  "media/0/Android/media/btools.routingapp/" # Downloadable segments; replacable
  "data/com.google.android.apps.docs.editors.*" # All online anyways
  "data/com.simplemobiletools.gallery.pro/files/storage/"
  "data/com.github.olga_yakovleva.rhvoice.android/app_data/" # Downloadable voices
  "data/org.woheller69.whobird/app_filesdir/" # Downloadable models
  "data/de.traderepublic.app/files/img/" # Downloaded images
  "data/com.google.android.gms/app_cache_dg/" # µG DroidGuard caches
  "data/com.collabora.libreoffice/" # Contains an extracted version of LibreOffice
  "data/im.vector.app" # Useless to backup, keys are in keystore
  "data/io.element.android.x" # Useless to backup, keys are in keystore
  "data/chat.schildi.android" # Useless to backup, keys are in keystore
  "data/com.discord" # Online-only app; restores are funky
  "data/de.materna.bbk.mobile.app/databases/geo_database" # Cached DB
  "data/de.materna.bbk.mobile.app/files/com.google.android.gms" # Cached DB
  "data/org.torproject.torbrowser/" # Intended to be stateless
  "data/org.fdroid.fdroid/databases" # Cached version of the online DB
  "data/com.google.android.inputmethod.latin/files/superpacks" # Downloadables
  "data/cz.seznam.mapy/files/mapcontrol-1" # Downloadables
  "data/org.briarproject.briar.android/app_tor" # TOR state/cache
  "data/de.noranotruf/lib-0" # Downloaded(?) .so files
  "data/com.google.android.inputmethod.latin/files/mozc_downloaded.data/"
  "data/com.google.android.inputmethod.latin/app_downloadable_packages/"
  "media/0/0/"
  "media/0/easy xkcd/"
  "media/0/Android/data/com.spotify.music/files/spotifycache/"
  "media/0/Android/data/com.generalmagic.magicearth/files/Download/MAGICEARTH/Data/Temporary/" # Replacable map tiles
  "media/0/Android/data/net.osmand.plus/files/*.obf" # Replacable map tiles
  "media/0/Android/data/net.osmand.plus/files/*/*.obf" # Replacable map tiles
  "media/0/Android/data/net.osmand.plus/files/tiles/" # Replacable map tiles
  "media/0/Android/data/net.osmand.plus/files/fonts/" # Replacable fonts
  "media/0/Android/data/org.fitchfamily.android.gsmlocation" # Just a local snapshot of an online DB
  "media/0/Android/data/tv.standard.nebula" # Downloaded video cache
  "media/0/Android/data/de.reimardoeffinger.quickdic/" # Downloadable dictionaries
  "media/0/Android/data/de.tap.easy_xkcd/" # Downloadable XKCDs
  "media/0/Android/data/io.github.subhamtyagi.ocr/" # Downloadable models
  "media/0/Android/data/com.k2fsa.sherpa.onnx.tts.engine/" # Extracted models
  "media/0/Android/data/com.google.android.apps.translate/" # Caches
  "media/0/Android/data/org.videolan.vlc/files/medialib/" # Thumbnails and logs
  "media/0/Android/data/com.elishaazaria.sayboard" # Downloaded models
  "media/0/Android/data/org.woheller69.ttsengine" # Downloaded models
  "media/0/Android/data/org.woheller69.whisper" # Downloaded models
  "media/0/Backups/" # Handled in other ways
  "media/0/Signal/Backups/" # Handled in other ways
  "data/org.thoughtcrime.securesms/"
  "media/0/DCIM/" # Backed up through Immich
  "media/0/Pictures/Screenshots/" # Backed up through Immich
  "media/0/Movies/"
  "media/0/Kiwix/"
  "user_de/0/com.android.packageinstaller" # Temporary files for the installer
  "dalvik-cache/"
  "system/package_cache/"
  "system_ce/0/shortcut_service/bitmaps/" # Cached bitmaps for app shortcuts
  "local/tmp" # Temporary files; you should not be putting data here that you care about keeping
]
