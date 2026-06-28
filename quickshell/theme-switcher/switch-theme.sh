#!/bin/bash
# Global theme switcher — GTK, Qt/Kvantum, Rofi
# Usage: switch-theme.sh dark|light

MODE="${1:-dark}"

CONF="$HOME/.config"

if [ "$MODE" = "light" ]; then
  # GTK
  #gsettings set org.gnome.desktop.interface gtk-theme  "Materia-light-compact" 2>/dev/null
  #gsettings set org.gnome.desktop.interface icon-theme "Papirus-Light"         2>/dev/null

  # Qt (qt6ct)
  sed -i 's/^style=.*/style=kvantum/' "$CONF/qt6ct/qt6ct.conf"
  sed -i 's/^icon_theme=.*/icon_theme=Papirus-Light/' "$CONF/qt6ct/qt6ct.conf"

  # Kvantum
  sed -i 's/^theme=.*/theme=Catppuccin-Latte/' "$CONF/Kvantum/kvantum.kvconfig"

  # Rofi
  cp "$CONF/rofi/themes/colors-light.rasi" "$CONF/rofi/themes/colors.rasi"
else
  # GTK
  #gsettings set org.gnome.desktop.interface gtk-theme  "Materia-dark-compact" 2>/dev/null
  #gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"         2>/dev/null

  # Qt (qt6ct)
  sed -i 's/^style=.*/style=kvantum-dark/' "$CONF/qt6ct/qt6ct.conf"
  sed -i 's/^icon_theme=.*/icon_theme=Papirus-Dark/' "$CONF/qt6ct/qt6ct.conf"

  # Kvantum
  sed -i 's/^theme=.*/theme=MateriaDark/' "$CONF/Kvantum/kvantum.kvconfig"

  # Rofi
  cp "$CONF/rofi/themes/colors-dark.rasi" "$CONF/rofi/themes/colors.rasi"
fi
