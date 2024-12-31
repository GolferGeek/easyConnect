#!/bin/bash; [ ! -f "EasyConnect/Assets.xcassets/AppIcon.appiconset/Icon.png" ] && magick -size 1024x1024 xc:white -fill black -gravity center -pointsize 100 -annotate 0 "EC" EasyConnect/Assets.xcassets/AppIcon.appiconset/Icon.png; magick EasyConnect/Assets.xcassets/AppIcon.appiconset/Icon.png -resize 40x40 EasyConnect/Assets.xcassets/AppIcon.appiconset/icon_20pt@2x.png; magick EasyConnect/Assets.xcassets/AppIcon.appiconset/Icon.png -resize 60x60 EasyConnect/Assets.xcassets/AppIcon.appiconset/icon_20pt@3x.png; magick EasyConnect/Assets.xcassets/AppIcon.appiconset/Icon.png -resize 58x58 EasyConnect/Assets.xcassets/AppIcon.appiconset/icon_29pt@2x.png; magick EasyConnect/Assets.xcassets/AppIcon.appiconset/Icon.png -resize 87x87 EasyConnect/Assets.xcassets/AppIcon.appiconset/icon_29pt@3x.png; magick EasyConnect/Assets.xcassets/AppIcon.appiconset/Icon.png -resize 80x80 EasyConnect/Assets.xcassets/AppIcon.appiconset/icon_40pt@2x.png; magick EasyConnect/Assets.xcassets/AppIcon.appiconset/Icon.png -resize 120x120 EasyConnect/Assets.xcassets/AppIcon.appiconset/icon_40pt@3x.png; magick EasyConnect/Assets.xcassets/AppIcon.appiconset/Icon.png -resize 120x120 EasyConnect/Assets.xcassets/AppIcon.appiconset/icon_60pt@2x.png; magick EasyConnect/Assets.xcassets/AppIcon.appiconset/Icon.png -resize 180x180 EasyConnect/Assets.xcassets/AppIcon.appiconset/icon_60pt@3x.png; magick EasyConnect/Assets.xcassets/AppIcon.appiconset/Icon.png -resize 20x20 EasyConnect/Assets.xcassets/AppIcon.appiconset/icon_20pt.png; magick EasyConnect/Assets.xcassets/AppIcon.appiconset/Icon.png -resize 29x29 EasyConnect/Assets.xcassets/AppIcon.appiconset/icon_29pt.png; magick EasyConnect/Assets.xcassets/AppIcon.appiconset/Icon.png -resize 40x40 EasyConnect/Assets.xcassets/AppIcon.appiconset/icon_40pt.png; magick EasyConnect/Assets.xcassets/AppIcon.appiconset/Icon.png -resize 76x76 EasyConnect/Assets.xcassets/AppIcon.appiconset/icon_76pt.png; magick EasyConnect/Assets.xcassets/AppIcon.appiconset/Icon.png -resize 152x152 EasyConnect/Assets.xcassets/AppIcon.appiconset/icon_76pt@2x.png; magick EasyConnect/Assets.xcassets/AppIcon.appiconset/Icon.png -resize 167x167 EasyConnect/Assets.xcassets/AppIcon.appiconset/icon_83.5@2x.png
