.ONESHELL:
SHELL := /bin/bash

PKGNAME=$(shell cargo metadata --no-deps --format-version 1 | jq -r '.packages[0].name')
VERSION=$(shell cargo metadata --no-deps --format-version 1 | jq -r '.packages[0].version')
DEB_ARCH=amd64  # use 'amd64' for compiled binaries
RPM_ARCH=x86_64  # use 'x86_64' for compiled binaries
PACKAGE_DIR=packaging
	
DEB_PACKAGE_DIR=${PACKAGE_DIR}/debian/${PKGNAME}_${VERSION}
RPM_PACKAGE_DIR=${PACKAGE_DIR}/rpm/${PKGNAME}_${VERSION}

all: build deb-pkg-build rpm-pkg-build
	@echo "All tasks completed successfully."

build:
	@echo "Building ${PKGNAME} version ${VERSION} for architecture ${DEB_ARCH}..."
	@cargo build --release --target x86_64-unknown-linux-gnu --locked
	@echo "Build completed successfully."

deb-pkg-setup:
	@echo "Setting up package structure for ${PKGNAME} version ${VERSION}..."
	@mkdir -p ${DEB_PACKAGE_DIR}/DEBIAN
	@touch ${DEB_PACKAGE_DIR}/DEBIAN/control
	@touch ${DEB_PACKAGE_DIR}/DEBIAN/postinst

	@mkdir -p ${DEB_PACKAGE_DIR}/usr/local/bin
	@mkdir -p ${DEB_PACKAGE_DIR}/usr/local/share/${PKGNAME}
	@mkdir -p ${DEB_PACKAGE_DIR}/etc/${PKGNAME}
	@mkdir -p ${DEB_PACKAGE_DIR}/lib/systemd/system
	@echo "Package structure for ${PKGNAME} version ${VERSION} set up successfully."

deb-pkg-build: deb-pkg-setup build
	@echo "Building Debian package for ${PKGNAME} version ${VERSION}..."
	@cp target/x86_64-unknown-linux-gnu/release/${PKGNAME} ${DEB_PACKAGE_DIR}/usr/local/bin/
	
	# Create the control file for the Debian package
	@cat <<-EOF > ${DEB_PACKAGE_DIR}/DEBIAN/control
	
	Package: ${PKGNAME}
	Version: ${VERSION}
	Architecture: ${DEB_ARCH}
	Maintainer: The Rustail Team 
	Section: admin
	Priority: optional
	Description: ${PKGNAME} a simple HTTP echo server built with Rust and Axum.
	EOF

	# Create the postinst script for the Debian package
	@cat <<-EOF > ${DEB_PACKAGE_DIR}/DEBIAN/postinst
	#!/bin/bash
	# give execute permissions to the binary
	chmod +x /usr/local/bin/${PKGNAME} 
	EOF
	chmod -R 755 ${DEB_PACKAGE_DIR}
	dpkg-deb --build ${DEB_PACKAGE_DIR}




rpm-pkg-setup: build
	@echo "Setting up package structure for ${PKGNAME} version ${VERSION}..."
	@mkdir -p ${RPM_PACKAGE_DIR}/{SOURCES,SPECS,BUILD,SRPMS,BUILDROOT} ${RPM_PACKAGE_DIR}/RPMS/${RPM_ARCH}
	@echo "Package structure for ${PKGNAME} version ${VERSION} set up successfully."
	@cp target/x86_64-unknown-linux-gnu/release/${PKGNAME} ${RPM_PACKAGE_DIR}/SOURCES/

	printf "creating spec file for ${PKGNAME} version ${VERSION}...\n"

	cat <<-EOF > ${RPM_PACKAGE_DIR}/SPECS/${PKGNAME}.spec
	Name:           ${PKGNAME}
	Version:        ${VERSION}
	Release:        1
	Summary:        ${PKGNAME}
	License:        MIT

	%description
	${PKGNAME} a simple HTTP echo server built with Rust and Axum.

	%prep

	%build

	%install
	mkdir -p %{buildroot}/usr/bin
	install -m 755 %{_sourcedir}/${PKGNAME} %{buildroot}/usr/bin/${PKGNAME}

	%files
	/usr/bin/${PKGNAME}
	EOF

rpm-pkg-build: rpm-pkg-setup build
	@echo "Building RPM package for ${PKGNAME} version ${VERSION}..."
	rpmbuild --define "_topdir $(PWD)/${RPM_PACKAGE_DIR}" -bb ${RPM_PACKAGE_DIR}/SPECS/${PKGNAME}.spec
	@echo "RPM package for ${PKGNAME} version ${VERSION} built successfully."
	@echo "RPM package is located at ${RPM_PACKAGE_DIR}/RPMS/${RPM_ARCH}/${PKGNAME}-${VERSION}-1.${RPM_ARCH}.rpm"
