DEB_CPPFLAGS_MAINT_APPEND = -DTEST_MK=test-host
TEST_CPPFLAGS            += -DTEST_MK=test-host

DEB_CPPFLAGS_FOR_BUILD_MAINT_APPEND = -DTEST_MK=test-build
TEST_CPPFLAGS_FOR_BUILD            += -DTEST_MK=test-build

DPKG_EXPORT_BUILDFLAGS := 1

include $(srcdir)/mk/buildflags.mk

vars := \
  ASFLAGS \
  CFLAGS \
  CPPFLAGS \
  CXXFLAGS \
  DFLAGS \
  FCFLAGS \
  FFLAGS \
  LDFLAGS \
  OBJCFLAGS \
  OBJCXXFLAGS \
  # EOL
loop_targets := $(vars) $(vars:=_FOR_BUILD)

test: $(loop_targets)

$(loop_targets):
	: # Test the Make variable.
	test '$($@)' = '$(TEST_$@)'
	: # Test the exported variable.
	test "$${$@}" = '$(TEST_$@)'
