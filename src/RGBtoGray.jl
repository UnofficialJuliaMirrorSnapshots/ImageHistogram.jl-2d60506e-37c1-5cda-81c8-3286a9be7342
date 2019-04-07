# different  recipes / formulas to create a gray image from a RGB image
# see 'Seven grayscale conversion algorithms' at
# URL: http://www.tannerhelland.com/3643/grayscale-image-algorithm-vb6/
# and the German
# https://de.wikipedia.org/wiki/RGB-Farbraum
# and the English
# https://en.wikipedia.org/wiki/CIE_1931_color_space
# https://en.wikipedia.org/wiki/Grayscale <=> especially 'Converting color to grayscale'
# https://en.wikipedia.org/wiki/Gamma_correction

###########
###  !!!  WATCH  !!!
##
## !!! Different kinds of devices, tools, applications may use different formulas !!!
##

#########
# Methods in brief:
#
# General
# The RGB-version of an Gray image has the same value for red, green and blue
#    RGB.r = gray
#    RGB.g = gray
#    RGB.b = gray
#
# Gamma correction (sRGB is non-linear!)
# Gamma-Korrektur (from https://de.wikipedia.org/wiki/RGB-Farbraum)
# Y (0…1), L (0…1: 0 am Schwarzpunkt, 1 am Weißpunkt) 	Berechnung
# Umrechnung von Luminanz L in die nichtlineare Y 	Y = 1,055 · L ^ (1/2,4) - 0,055 , falls L > 0,0031306684425, sonst Y = 12,92 · L
# Umrechnung der nichtlinearen Y in die Luminanz 	L = ((Y + 0,055) / 1,055) ^(2,4) , falls Y > 0,040448236277, sonst L = Y / 12,92
# Lref 	80 cd/m² Gesamthelligkeit aller Primärvalenzen
#
# ==> According to CIE
#   make sRGB linear, then apply Gray formula, then make value non-linear again
#     at least with using test image "lena_color_256", the difference is not worth the effort.
#
#   BT.709 is '... used by PAL and NTSC, the rec601 luma (Y') component ...'
#   BT.601 is '... ITU-R BT.709 standard used for HDTV developed by the ATSC uses different color coefficients ...'
#   both applied to non-linear sRGB values directly
#
# Method 1
#   Gray = (Red + Green + Blue) / 3
#
# Method 2
# common in Photoshop, GIMP
#   Gray = (Red * 0.3 + Green * 0.59 + Blue * 0.11)
#
# ITU-R recommendation (BT.709, specifically) which is the historical precedent.  This formula, sometimes called Luma, looks like this:
#   Gray = (Red * 0.2126 + Green * 0.7152 + Blue * 0.0722)
#
# Some modern digital image and video formats use a different recommendation (BT.601), which calls for slightly different coefficients:
#   Gray = (Red * 0.299 + Green * 0.587 + Blue * 0.114)
#
# Most don't care / remeber the difference
#
# Method 3 – Desaturation
#   Gray = ( Max(Red, Green, Blue) + Min(Red, Green, Blue) ) / 2
# gives flattest (least contrast) and darkest overall image until now.
#
# Method 4 – Decomposition
#   Maximum decomposition:
#   Gray = Max(Red, Green, Blue)
#
#   Minimum decomposition:
#   Gray = Min(Red, Green, Blue)
#
# Method 5 – Single color channel
#   Gray = Red
#   Gray = Green
#   Gray = Blue
# the poorest, but simplest - often used in SSD camera models
#
# Method 6 – Custom # of gray shades
#
# Method 7 - Custom # of gray shades with dithering (in this example, horizontal error-diffusion dithering)
#

