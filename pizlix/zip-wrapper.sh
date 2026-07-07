#!/bin/bash
# Wrapper for zip that serializes concurrent calls using flock
# This works around a Fil-C bug where concurrent zip processes fail
exec flock /tmp/zip_serial.lock /usr/bin/zip.real "$@"
