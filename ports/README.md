# Fil-C Port System
#
# Each port is a TOML file in ports/ describing how to build a library.
# The port system handles dependency resolution, build ordering, and
# pkg-config integration.
#
# Port definition fields:
#   [port]          name, version, description, homepage
#   [source]        dir (path within repo), or url+type for auto-download
#   [dependencies]  list of port names this depends on
#   [build]         script: inline shell commands
#   [pkgconfig]     cflags, libs for auto-generated .pc file
#
# After a port is built, it installs to ports/prefix/<name>/
# and a pkg-config .pc file is generated at ports/prefix/<name>/lib/pkgconfig/
#
# Usage:
#   filc port list              List all ports
#   filc port install duckdb    Build duckdb and its dependencies
#   filc port info zlib         Show port details
#   filc port tree duckdb       Show dependency tree
#   filc port search regex      Search port names/descriptions
