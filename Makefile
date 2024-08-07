ROOT_DIR := $(shell pwd)
PREFIX ?= $(ROOT_DIR)/output

all: build-gcc build-gdb build-binutils

ifndef AARCH64_ARCH
  AARCH64_ARCH := armv8.2-a+sve
endif

ifndef RISCV_ARCH
  RISCV_ARCH := rv64gcv
endif

build-gdb: clean
	mkdir -p build/$@
	cd build/$@ && ../../binutils/configure \
		--prefix=$(PREFIX) \
		--enable-gdbserver \
		--disable-gas \
		--disable-binutils \
		--disable-ld \
		--disable-gold \
		--disable-gprof
	$(MAKE) -C build/$@
	$(MAKE) -C build/$@ install

build-binutils: build-gdb clean
	mkdir -p build/$@
	cd build/$@ && ../../binutils/configure \
		--prefix=$(PREFIX) \
		--disable-werror \
		--with-expat=yes  \
		--disable-gdb \
		--disable-sim \
		--disable-libdecnumber \
		--disable-readline
	$(MAKE) -C build/$@
	$(MAKE) -C build/$@ install

build-gcc: build-binutils clean
	mkdir -p build/$@
	cd build/$@ && ../../gcc/configure \
		--prefix=$(PREFIX) \
		--disable-bootstrap \
		--enable-languages=c,c++,fortran \
		--disable-multilib
	$(MAKE) -C build/$@
	$(MAKE) -C build/$@ install

clean:
	rm -rf build/build-binutils build/build-gdb build/build-gcc
	rm -rf output

update-gcc:
	cd gcc \
          && $(reset_to_master)

update-golden-gcc:
	cd golden-gcc \
          && $(reset_to_master)

update-to-trunk: update-golden-gcc update-gcc

update-golden-gcc-to-commit:
	cd golden-gcc \
          && $(call checkout_to_commit, $(commit-id))

update-gcc-to-commit:
	cd gcc \
          && $(call checkout_to_commit, $(commit-id))

update-to-commit: update-gcc-to-commit update-golden-gcc-to-commit

build-test-gcc-x86:
	$(MAKE) -f native.mk DATE=gcc-x86 build-test

build-test-golden-gcc-x86: build-test-gcc-x86
	$(MAKE) -f native.mk DATE=golden-gcc-x86 GCC_SRC_DIR=$(ROOT_DIR)/golden-gcc build-test

test: build-test-golden-gcc-x86 build-test-gcc-x86
	python3 ./check.py \
          --golden_dir build/build-native-golden-gcc-x86/build-test-gcc/gcc/testsuite \
          --test_dir   build/build-native-gcc-x86/build-test-gcc/gcc/testsuite

test-cached: build-test-gcc-x86
	python3 ./check.py \
          --golden_dir build/build-native-golden-gcc-x86/build-test-gcc/gcc/testsuite \
          --test_dir   build/build-native-gcc-x86/build-test-gcc/gcc/testsuite

build-test-gcc-aarch64:
	$(MAKE) -f cross-elf.mk \
          DATE=gcc-aarch64 \
          TARGET=aarch64-unknown-elf \
          ARCH=$(AARCH64_ARCH) \
          BOARD=aarch64-sim \
          QEMU_TARGET_LIST=aarch64-linux-user \
          GCC_SRC_DIR=$(ROOT_DIR)/gcc \
          build-test

build-test-golden-gcc-aarch64: build-test-gcc-aarch64
	$(MAKE) -f cross-elf.mk \
          DATE=golden-gcc-aarch64 \
          TARGET=aarch64-unknown-elf \
          ARCH=$(AARCH64_ARCH) \
          BOARD=aarch64-sim \
          QEMU_TARGET_LIST=aarch64-linux-user \
          GCC_SRC_DIR=$(ROOT_DIR)/golden-gcc \
          build-test

test-aarch64: build-test-golden-gcc-aarch64 build-test-gcc-aarch64
	python3 ./check.py \
          --golden_dir build/build-aarch64-unknown-elf-golden-gcc-aarch64/build-gcc-stage2/gcc/testsuite \
          --test_dir   build/build-aarch64-unknown-elf-gcc-aarch64/build-gcc-stage2/gcc/testsuite

test-aarch64-cached: build-test-gcc-aarch64
	python3 ./check.py \
          --golden_dir build/build-aarch64-unknown-elf-golden-gcc-aarch64/build-gcc-stage2/gcc/testsuite \
          --test_dir   build/build-aarch64-unknown-elf-gcc-aarch64/build-gcc-stage2/gcc/testsuite

build-test-gcc-riscv64:
	$(MAKE) -f cross-elf.mk \
          DATE=gcc-riscv64 \
          TARGET=riscv64-unknown-elf \
          ARCH=$(RISCV_ARCH) \
          BOARD=riscv-sim \
          QEMU_TARGET_LIST=riscv64-linux-user \
          GCC_SRC_DIR=$(ROOT_DIR)/gcc \
          build-test

build-test-golden-gcc-riscv64: build-test-gcc-riscv64
	$(MAKE) -f cross-elf.mk \
          DATE=golden-gcc-riscv64 \
          TARGET=riscv64-unknown-elf \
          ARCH=$(RISCV_ARCH) \
          BOARD=riscv-sim \
          QEMU_TARGET_LIST=riscv64-linux-user \
          GCC_SRC_DIR=$(ROOT_DIR)/golden-gcc \
          build-test

test-riscv64: build-test-golden-gcc-riscv64 build-test-gcc-riscv64
	python3 ./check.py \
          --golden_dir build/build-riscv64-unknown-elf-golden-gcc-riscv64/build-gcc-stage2/gcc/testsuite \
          --test_dir   build/build-riscv64-unknown-elf-gcc-riscv64/build-gcc-stage2/gcc/testsuite

test-riscv64-cached: build-test-gcc-riscv64
	python3 ./check.py \
          --golden_dir build/build-riscv64-unknown-elf-golden-gcc-riscv64/build-gcc-stage2/gcc/testsuite \
          --test_dir   build/build-riscv64-unknown-elf-gcc-riscv64/build-gcc-stage2/gcc/testsuite

define reset_to_master
	git clean -f \
          && git remote update \
          && git reset --hard origin/master
endef

define checkout_to_commit
	git clean -f \
          && git remote update \
          && git checkout $(1)
endef
