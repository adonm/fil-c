#!/bin/bash
set -e
set -x
rm -rf pizlonated-zip
tar -xf pizlonated-zip.tar.gz
cd pizlonated-zip
make -f unix/Makefile generic CC=gcc
make -f unix/Makefile install PREFIX=/usr
cd ..
rm -rf pizlonated-zip
# Install zip wrapper for Fil-C concurrency workaround
mv /usr/bin/zip /usr/bin/zip.real
cat > /usr/bin/zip << 'WRAPPER'
#!/bin/bash
exec flock /tmp/zip_serial.lock /usr/bin/zip.real "$@"
WRAPPER
chmod +x /usr/bin/zip
