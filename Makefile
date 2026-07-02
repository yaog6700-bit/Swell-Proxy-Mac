# Copyright (c) 2026 Max Lv <max.c.lv@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

GO_BRIDGE_DIR = Go/mihomo-bridge
FFI_OBJC = $(GO_BRIDGE_DIR)/objc
FRAMEWORK_DIR = Framework
FRAMEWORK_NAME = MihomoCore
BUILD_DIR = /tmp/mihomo-ffi-build

# sing-box bridge
SB_BRIDGE_DIR = Go/singbox-bridge
SB_FFI_OBJC = $(SB_BRIDGE_DIR)/objc
SB_FRAMEWORK_NAME = SingBoxCore
SB_BUILD_DIR = /tmp/singbox-ffi-build

GO_LDFLAGS = -s -w

# macOS SDK path
MACOS_SDK = $(shell xcrun --sdk macosx --show-sdk-path)

.PHONY: all framework framework-macos singbox-framework clean e2e-test e2e-setup stress-test

all: framework

# Default target: build macOS universal (arm64 + x86_64)
framework: singbox-framework

framework-macos: singbox-framework


singbox-framework:
	@mkdir -p $(SB_BUILD_DIR)
	# Build Go c-archive for arm64
	cd $(SB_BRIDGE_DIR) && CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 \
		CC="xcrun --sdk macosx clang -target arm64-apple-macos14.0 -arch arm64" \
		go build -buildvcs=false -tags "with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_clash_api" -buildmode=c-archive -ldflags "$(GO_LDFLAGS)" \
		-o $(SB_BUILD_DIR)/libsingbox_bridge-arm64.a .
	# Build Go c-archive for x86_64
	cd $(SB_BRIDGE_DIR) && CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 \
		CC="xcrun --sdk macosx clang -target x86_64-apple-macos14.0 -arch x86_64" \
		go build -buildvcs=false -tags "with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_clash_api" -buildmode=c-archive -ldflags "$(GO_LDFLAGS)" \
		-o $(SB_BUILD_DIR)/libsingbox_bridge-x86.a .
	# Compile ObjC wrapper for each arch
	xcrun clang -c $(SB_FFI_OBJC)/SingBoxCore.m -o $(SB_BUILD_DIR)/objc-macos-arm64.o \
		-target arm64-apple-macos14.0 -fobjc-arc -isysroot $(MACOS_SDK) -I$(SB_FFI_OBJC)
	xcrun clang -c $(SB_FFI_OBJC)/SingBoxCore.m -o $(SB_BUILD_DIR)/objc-macos-x86.o \
		-target x86_64-apple-macos14.0 -fobjc-arc -isysroot $(MACOS_SDK) -I$(SB_FFI_OBJC)
	# Combine Go .a + ObjC .o into single .a per arch
	xcrun libtool -static -o $(SB_BUILD_DIR)/macos-arm64.a \
		$(SB_BUILD_DIR)/libsingbox_bridge-arm64.a $(SB_BUILD_DIR)/objc-macos-arm64.o
	xcrun libtool -static -o $(SB_BUILD_DIR)/macos-x86.a \
		$(SB_BUILD_DIR)/libsingbox_bridge-x86.a $(SB_BUILD_DIR)/objc-macos-x86.o
	# Fat library
	@mkdir -p $(SB_BUILD_DIR)/macos
	lipo -create $(SB_BUILD_DIR)/macos-arm64.a $(SB_BUILD_DIR)/macos-x86.a \
		-output $(SB_BUILD_DIR)/macos/lib$(SB_FRAMEWORK_NAME).a
	# Prepare headers
	@rm -rf $(SB_BUILD_DIR)/headers
	@mkdir -p $(SB_BUILD_DIR)/headers
	@cp $(SB_FFI_OBJC)/SingBoxCore.h $(SB_BUILD_DIR)/headers/
	@cp $(SB_FFI_OBJC)/module.modulemap $(SB_BUILD_DIR)/headers/
	# Create xcframework
	rm -rf $(FRAMEWORK_DIR)/$(SB_FRAMEWORK_NAME).xcframework
	xcodebuild -create-xcframework \
		-library $(SB_BUILD_DIR)/macos/lib$(SB_FRAMEWORK_NAME).a -headers $(SB_BUILD_DIR)/headers \
		-output $(FRAMEWORK_DIR)/$(SB_FRAMEWORK_NAME).xcframework
	@echo "Built $(FRAMEWORK_DIR)/$(SB_FRAMEWORK_NAME).xcframework (macOS arm64+x86_64)"

clean:
	rm -rf $(FRAMEWORK_DIR)/$(FRAMEWORK_NAME).xcframework
	rm -rf $(BUILD_DIR)

e2e-setup:
	./tests/e2e/vm-setup.sh

e2e-test:
	./tests/e2e/run-e2e.sh

stress-test:
	./tests/e2e/run-stress-test.sh

stability-test:
	./tests/e2e/run-stability-test.sh
