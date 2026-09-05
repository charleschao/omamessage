#!/usr/bin/env python3
# Native file picker. Starts in ~/Downloads. Prints the chosen path on stdout.
import os
import sys

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gtk

start = os.path.expanduser("~/Downloads")
if not os.path.isdir(start):
    start = os.path.expanduser("~")

dialog = Gtk.FileChooserNative.new(
    "Choose file", None, Gtk.FileChooserAction.OPEN, "Select", "Cancel"
)
dialog.set_current_folder(start)
if dialog.run() != Gtk.ResponseType.ACCEPT:
    sys.exit(1)
name = dialog.get_filename()
if not name:
    sys.exit(1)
sys.stdout.write(name)
sys.stdout.flush()
