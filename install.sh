#!/usr/bin/env bash

#	MetaCall Install Script by Parra Studios
#	Cross-platform set of scripts to install MetaCall infrastructure.
#
#	Copyright (C) 2016 - 2020 Vicente Eduardo Ferrer Garcia <vic798@gmail.com>
#
#	Licensed under the Apache License, Version 2.0 (the "License");
#	you may not use this file except in compliance with the License.
#	You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
#	Unless required by applicable law or agreed to in writing, software
#	distributed under the License is distributed on an "AS IS" BASIS,
#	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#	See the License for the specific language governing permissions and
#	limitations under the License.

# Check if program exists
program() {
	command -v $1 >/dev/null 2>&1
}

# Set up colors
if program tput; then
	ncolors=$(tput colors)
	if [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
		bold="$(tput bold       || echo)"
		normal="$(tput sgr0     || echo)"
		black="$(tput setaf 0   || echo)"
		red="$(tput setaf 1     || echo)"
		green="$(tput setaf 2   || echo)"
		yellow="$(tput setaf 3  || echo)"
		blue="$(tput setaf 4    || echo)"
		magenta="$(tput setaf 5 || echo)"
		cyan="$(tput setaf 6    || echo)"
		white="$(tput setaf 7   || echo)"
	fi
fi

# Title message
title() {
	printf "%b\n\n" "${normal:-}${bold:-}$@${normal:-}"
}

# Warning message
warning() {
	printf "%b\n" "${yellow:-}‼${normal:-} $@"
}

# Error message
err() {
	printf "%b\n" "${red:-}✘${normal:-} $@"
}

# Print message
print() {
	printf "%b\n" "${normal:-}▷ $@"
}

# Success message
success() {
	printf "%b\n" "${green:-}✔${normal:-} $@"
}

# Ask message
ask() {
	while true; do
		read -r -n 1 -p "${normal:-}▷ ${cyan:-}$@?${normal:-} [Y/n] " yn
		case $yn in
			[Yy]* ) break;;
			[Nn]* ) exit 1;;
			* ) warning "Please answer yes [Yy] or no [Nn].";;
		esac
	done
}

# Check if a list of programs exist or aborts
programs_required() {
	for prog in "$@"; do
		if ! program ${prog}; then
			err "The program '${prog}' is not found, it is required to run the installer. Aborting installation."
			exit 1
		fi
	done
}

# Check if at least one program exists in the list or aborts
programs_required_one() {
	for prog in "$@"; do
		if program ${prog}; then
			return
		fi
	done

	err "None of the following programs are installed: $@. One of them is required at least to download the tarball. Aborting installation."
	exit 1
}

# Check all dependencies
dependencies() {
	print "Checking system dependencies."

	# Check if required programs are installed
	programs_required tar grep tail awk rev cut uname echo rm id find head chmod

	if [ $(id -u) -ne 0 ]; then
		programs_required tee
	fi

	# Check if download programs are installed
	programs_required_one curl wget

	# Detect sudo or run with root
	if ! program sudo && [ $(id -u) -ne 0 ]; then
		err "You need either having sudo installed or running this script as root. Aborting installation."
		exit 1
	fi

	success "Dependencies satisfied."
}

# Get operative system name
operative_system() {
	local os=$(uname)

	# TODO: Implement other operative systems in metacall/distributable
	case ${os} in
		# Darwin)
		# 	echo "osx"
		# 	return
		# 	;;
		# FreeBSD)
		# 	echo "freebsd"
		# 	return
		# 	;;
		Linux)
			echo "linux"
			return
			;;
	esac

	err "Operative System detected (${os}) is not supported." \
		"  Please, refer to https://github.com/metacall/install/issues and create a new issue." \
		"  Aborting installation."
	exit 1
}

# Get architecture name
architecture() {
	local arch=$(uname -m)

	# TODO: Implement other architectures in metacall/distributable
	case ${arch} in
		x86_64)
			echo "amd64"
			return
			;;
		# armv7l)
		# 	echo "arm"
		# 	return
		# 	;;
		# aarch64)
		# 	echo "arm64"
		# 	return
		# 	;;
	esac

	err "Architecture detected (${arch}) is not supported." \
		"  Please, refer to https://github.com/metacall/install/issues and create a new issue." \
		"  Aborting installation."
	exit 1
}

# Download tarball
download() {
	local url="https://github.com/metacall/distributable/releases/latest"
	local tmp="/tmp/metacall-tarball.tar.gz"
	local os="$1"
	local arch="$2"

	print "Start to download the tarball."

	if program curl; then
		local tag_url=$(curl -Ls -o /dev/null -w %{url_effective} ${url})
	elif program wget; then
		local tag_url=$(wget -O /dev/null ${url} 2>&1 | grep Location: | tail -n 1 | awk '{print $2}')
	fi

	local version=$(printf "${tag_url}" | rev | cut -d '/' -f1 | rev)
	local final_url=$(printf "https://github.com/metacall/distributable/releases/download/${version}/metacall-tarball-${os}-${arch}.tar.gz")
	local fail=false

	if program curl; then
		curl --retry 10 -f --create-dirs -LS ${final_url} --output ${tmp} || fail=true
	elif program wget; then
		wget --tries 10 -O ${tmp} ${final_url} || fail=true
	fi

	if "${fail}" == true; then
		rm -rf ${tmp}
		err "The tarball metacall-tarball-${os}-${arch}.tar.gz could not be downloaded." \
			"  Please, refer to https://github.com/metacall/install/issues and create a new issue." \
			"  Aborting installation."
		exit 1
	fi

	success "Tarball downloaded."
}

# Extract the tarball (requires root or sudo)
uncompress() {
	local tmp="/tmp/metacall-tarball.tar.gz"

	print "Uncompress the tarball (needs sudo or root permissions)."

	if [ $(id -u) -eq 0 ]; then
		tar xzf ${tmp} -C /
		chmod -R 755 /gnu/store
	else
		sudo tar xzf ${tmp} -C /
		sudo chmod -R 755 /gnu/store
	fi

	success "Tarball uncompressed successfully."

	# Clean the tarball
	print "Cleaning the tarball."

	rm -rf ${tmp}

	success "Tarball cleaned successfully."
}

# Install the CLI
cli() {
	local cli="/gnu/store/`ls /gnu/store/ | grep metacall | head -n 1`"

	print "Installing the Command Line Interface shortcut (needs sudo or root permissions)."

	# Write shell script pointing to MetaCall CLI
	if [ $(id -u) -eq 0 ]; then
		echo "#!/usr/bin/env sh" &> /usr/local/bin/metacall

		# MetaCall Environment
		echo "export LOADER_LIBRARY_PATH=\"${cli}/lib\"" >> /usr/local/bin/metacall
		echo "export SERIAL_LIBRARY_PATH=\"${cli}/lib\"" >> /usr/local/bin/metacall
		echo "export DETOUR_LIBRARY_PATH=\"${cli}/lib\"" >> /usr/local/bin/metacall
		echo "export PORT_LIBRARY_PATH=\"${cli}/lib\"" >> /usr/local/bin/metacall
		echo "export CONFIGURATION_PATH=\"${cli}/configurations/global.json\"" >> /usr/local/bin/metacall
		echo "export LOADER_SCRIPT_PATH=\"\${LOADER_SCRIPT_PATH:-\`pwd\`}\"" >> /usr/local/bin/metacall

		echo "CMD=\`ls -a /gnu/bin | grep \"\$1\" | head -n 1\`" >> /usr/local/bin/metacall

		echo "if [ \"\${CMD}\" = \"\$1\" ]; then" >> /usr/local/bin/metacall
		echo "	if [ -z \"\${PATH-}\" ]; then export PATH=\"/gnu/bin\"; else PATH=\"/gnu/bin:\${PATH}\"; fi" >> /usr/local/bin/metacall
		echo "	\$@" >> /usr/local/bin/metacall
		echo "	exit \$?" >> /usr/local/bin/metacall
		echo "fi" >> /usr/local/bin/metacall

		# CLI
		echo "${cli}/metacallcli \$@" >> /usr/local/bin/metacall
		chmod 755 /usr/local/bin/metacall
	else
		echo "#!/usr/bin/env sh" | sudo tee /usr/local/bin/metacall > /dev/null

		# MetaCall Environment
		echo "export LOADER_LIBRARY_PATH=\"${cli}/lib\"" | sudo tee -a /usr/local/bin/metacall > /dev/null
		echo "export SERIAL_LIBRARY_PATH=\"${cli}/lib\"" | sudo tee -a /usr/local/bin/metacall > /dev/null
		echo "export DETOUR_LIBRARY_PATH=\"${cli}/lib\"" | sudo tee -a /usr/local/bin/metacall > /dev/null
		echo "export PORT_LIBRARY_PATH=\"${cli}/lib\"" | sudo tee -a /usr/local/bin/metacall > /dev/null
		echo "export CONFIGURATION_PATH=\"${cli}/configurations/global.json\"" | sudo tee -a /usr/local/bin/metacall > /dev/null
		echo "export LOADER_SCRIPT_PATH=\"\${LOADER_SCRIPT_PATH:-\`pwd\`}\"" | sudo tee -a /usr/local/bin/metacall > /dev/null

		echo "CMD=\`ls -a /gnu/bin | grep \"\$1\" | head -n 1\`" | sudo tee -a /usr/local/bin/metacall > /dev/null

		echo "if [ \"\${CMD}\" = \"\$1\" ]; then" | sudo tee -a /usr/local/bin/metacall > /dev/null
		echo "	if [ -z \"\${PATH-}\" ]; then export PATH=\"/gnu/bin\"; else PATH=\"/gnu/bin:\${PATH}\"; fi" | sudo tee -a /usr/local/bin/metacall > /dev/null
		echo "	\$@" | sudo tee -a /usr/local/bin/metacall > /dev/null
		echo "	exit \$?" | sudo tee -a /usr/local/bin/metacall > /dev/null
		echo "fi" | sudo tee -a /usr/local/bin/metacall > /dev/null

		# CLI
		echo "${cli}/metacallcli \$@" | sudo tee -a /usr/local/bin/metacall > /dev/null
		sudo chmod 755 /usr/local/bin/metacall
	fi

	success "CLI shortcut installed successfully."
}

binary_install() {
	# Show title
	title "MetaCall Self-Contained Binary Installer"

	# Check dependencies
	dependencies

	# Detect operative system and architecture
	print "Detecting Operative System and Architecture."

	# Run to check if the operative system is supported
	operative_system > /dev/null 2>&1
	architecture > /dev/null 2>&1

	# Get the operative system and architecture into a variable
	local os="$(operative_system)"
	local arch="$(architecture)"

	success "Operative System (${os}) and Architecture (${arch}) detected."

	# Download tarball
	download ${os} ${arch}

	# Extract
	uncompress

	# Install CLI
	cli
}

docker_install() {
	# Show title
	title "MetaCall Docker Installer"

	# Check if Docker command is installed
	print "Checking Docker Dependency."

	programs_required docker echo chmod

	if [ $(id -u) -ne 0 ]; then
		programs_required tee
	fi

	# Pull MetaCall CLI Docker Image
	print "Pulling MetaCall CLI Image."

	docker pull metacall/cli:latest

	result=$?

	if [ $result -ne 0 ]; then
		err "Docker image could not be pulled. Aborting installation."
	fi

	# Install Docker based CLI
	print "Installing the Command Line Interface shortcut (needs sudo or root permissions)."

	local command="docker run --rm --network host -e \"LOADER_SCRIPT_PATH=/metacall/source\" -v \`pwd\`:/metacall/source -it metacall/cli \$@"

	# Write shell script wrapping the Docker run of MetaCall CLI image
	if [ $(id -u) -eq 0 ]; then
		echo "#!/usr/bin/env sh" &> /usr/local/bin/metacall
		echo "${command}" >> /usr/local/bin/metacall
		chmod 755 /usr/local/bin/metacall
	else
		echo "#!/usr/bin/env sh" | sudo tee /usr/local/bin/metacall > /dev/null
		echo "${command}" | sudo tee -a /usr/local/bin/metacall > /dev/null
		sudo chmod 755 /usr/local/bin/metacall
	fi
}

check_path_env() {
	# Check if the PATH contains the install path
	echo "${PATH}" | grep -i ":/usr/local/bin:"
	echo "${PATH}" | grep -i "^/usr/local/bin:"
	echo "${PATH}" | grep -i ":/usr/local/bin$"
	echo "${PATH}" | grep -i "^/usr/local/bin$"
}

main() {
	# Required program for recursive calls
	programs_required wait

	# Run binary install
	binary_install &
	proc=$!
	wait ${proc}
	result=$?

	if [ $result -ne 0 ]; then
		# Required program for ask question to the user
		programs_required read

		ask "Binary installation has failed, do you want to fallback to Docker installation"

		# On error, fallback to docker install
		docker_install &
		proc=$!
		wait ${proc}
	fi

	local path="$(check_path_env)"

	# Check if /usr/local/bin is in PATH
	if [ "${path}" == "" ]; then
		# Add /usr/local/bin to PATH
		if [ $(id -u) -eq 0 ]; then
			echo "export PATH=\${PATH}:/usr/local/bin" >> /etc/profile
		else
			echo "export PATH=\${PATH}:/usr/local/bin" | sudo tee -a /etc/profile > /dev/null
		fi

		warning "MetaCall install path is not present in PATH so we added it for you." \
			"  The command 'metacall' will be available in your subsequent terminal instances." \
			"  Run 'source /etc/profile' to make 'metacall' command available to your current terminal instance."
	fi

	# Show information
	success "MetaCall has been installed." \
		"  Run 'metacall' command for start the CLI and type help for more information about CLI commands."
}

# Run main
main
