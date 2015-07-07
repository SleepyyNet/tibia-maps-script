#!/usr/bin/env bash

# Enable writing paths relative to the `test` folder.
cd "$(dirname "${BASH_SOURCE}")";

npm link > /dev/null;

# Mimic `md5sum` on OS X.
if ! hash md5sum 2> /dev/null; then
	function md5sum() {
		md5 -r "${1}";
	}
fi;

# Check if the generated map files based on the generated PNG and JSON data
# match the original map files, and call out any differences.
tibia-maps --from-maps=maps --output-dir=data;
tibia-maps --from-data=data --output-dir=maps-new;
for file in maps/*.map; do
	f=$(basename "${file}");
	[ -f "maps-new/${f}" ] || echo "Missing file: ${f}";
	expected=($(md5sum "maps/${f}"));
	actual=($(md5sum "maps-new/${f}"));
	if [ "${expected}" != "${actual}" ]; then
		echo "MD5 mismatch: ${f}";
		# Show the first few bytes that differ.
		cmp -l {maps,maps-new}/"${f}" | \
			gawk '{printf "%08X %02X %02X\n", $1, strtonum(0$2), strtonum(0$3)}' | \
			head -n 5;
		exit 1;
	fi;
done;

# Check if `--no-markers` skips importing the marker data.
tibia-maps --from-maps=maps --output-dir=data-without-markers --no-markers;
files_with_markers="$(find data-without-markers -name '*-markers.json' \
	-type f -size +3c)";
if [ "$(tr -d '\n' <<< ${files_with_markers})" != "" ]; then
	echo 'Error: `--no-markers` extracted marker data anyway!';
	echo "${files_with_markers}";
	exit 1;
fi;

# Check if `--no-markers` produces map files without any markers in them.
tibia-maps --from-data=data --output-dir=maps-new-without-markers --no-markers;
files_with_markers="$(find maps-new-without-markers -type f -size +131076c)";
if [ "$(tr -d '\n' <<< ${files_with_markers})" != "" ]; then
	echo 'Error: `--no-markers` produced file(s) larger than 0x20004 bytes!';
	echo "${files_with_markers}";
	exit 1;
fi;
