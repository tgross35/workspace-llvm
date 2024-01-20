source_dir := justfile_directory() / "llvm-project"
build_dir := justfile_directory() / "llvm-build"
install_dir := justfile_directory() / "local-install"
bin_dir := build_dir / "bin"

projects := "clang"

# Print recipes and exit
default:
	just --list

# Configure Cmake
configure build-type="Debug":
	#!/bin/sh
	link_arg=""
	if which mold 2> /dev/null; then
		link_arg="-DLLVM_USE_LINKER=mold"
	elif which lld 2> /dev/null; then
		link_arg="-DLLVM_USE_LINKER=lld"
	fi
	
	cmake "-S{{source_dir}}/llvm" "-B{{build_dir}}" \
		-G Ninja \
		-DCMAKE_C_COMPILER_LAUNCHER=sccache \
		-DCMAKE_CXX_COMPILER_LAUNCHER=sccache \
		-DCMAKE_EXPORT_COMPILE_COMMANDS=true \
		-DCMAKE_BUILD_TYPE={{build-type}} \
		"-DCMAKE_INSTALL_PREFIX={{install_dir}}" \
		"-DLLVM_ENABLE_PROJECTS={{projects}}" \
		"$link_arg"

# Build the project
build:
	cmake --build "{{build_dir}}"

# Run the LLVM test suite. Does not rebuild/reconfigure
test-llvm:
	ninja -C "{{build_dir}}" check-llvm
	# cmake "{{build_dir}}" check-llvm

# Run the complete test suite. Does not rebuild/reconfigure
test:
	ninja -C "{{build_dir}}" check-all
	# cmake "{{build_dir}}" check-all

# Install to the provided prefix. Does not rebuild/reconfigure
install:
	cmake "{{build_dir}}" install

# Run Lit on the specified files
lit +testfiles:
	"{{bin_dir}}/llvm-lit" {{testfiles}}

# Print the location of built binaries
bindir:
	echo "{{bin_dir}}"

# Launch a binary with the given name
bin binname *binargs:
	"{{bin_dir}}/{{binname}}" {{binargs}}

# Run the code formatter
fmt *args:
	"{{source_dir}}/llvm/utils/git/code-format-helper.py" {{args}}

# Symlink configuration so C language servers work correctly
configure-clangd: configure
	#!/usr/bin/env sh
	dst="{{ build_dir }}/compile_commands.json"
	if ! [ -f "$dst" ]; then
		ln -is "$dst" "{{ source_dir }}"
	fi
